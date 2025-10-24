import * as admin from "firebase-admin";
import {generateEmbedding, cosineSimilarity} from "../services/openai-service";
import {SemanticSearchResult} from "../types/NotificationPreferences";

/**
 * Semantic Search for RAG System
 *
 * Story 6.2: RAG System for Full User Context
 */

/**
 * Find relevant messages using semantic search
 *
 * Converts query to embedding, performs cosine similarity search
 * against user's message embeddings.
 *
 * @param userId - User ID
 * @param query - Search query text
 * @param topK - Number of top results to return (default: 10)
 * @returns Array of SemanticSearchResult sorted by similarity
 */
export async function findRelevantMessages(
  userId: string,
  query: string,
  topK: number = 10
): Promise<SemanticSearchResult[]> {
  console.log(`[findRelevantMessages] Searching for user ${userId}`);
  console.log(`[findRelevantMessages] Query: "${query}"`);

  const db = admin.firestore();

  // Step 1: Generate embedding for query
  let queryEmbedding: number[];
  try {
    queryEmbedding = await generateEmbedding(query);
    console.log(`[findRelevantMessages] Query embedding generated (${queryEmbedding.length} dimensions)`);
  } catch (error) {
    console.error("[findRelevantMessages] Error generating query embedding:", error);
    throw error;
  }

  // Step 2: Fetch user's conversations to filter embeddings
  const conversationsSnapshot = await db.collection("conversations")
    .where("participantIds", "array-contains", userId)
    .get();

  const conversationIds = conversationsSnapshot.docs.map(doc => doc.id);

  if (conversationIds.length === 0) {
    console.log(`[findRelevantMessages] No conversations found for user ${userId}`);
    return [];
  }

  console.log(`[findRelevantMessages] User participates in ${conversationIds.length} conversations`);

  // Step 3: Fetch embeddings from user's conversations
  // Note: We need to batch this because Firestore 'in' queries are limited to 10 values
  const allEmbeddings: Array<{
    messageId: string;
    conversationId: string;
    embedding: number[];
    messageText: string;
    timestamp: FirebaseFirestore.Timestamp;
  }> = [];

  const batchSize = 10;
  for (let i = 0; i < conversationIds.length; i += batchSize) {
    const batch = conversationIds.slice(i, i + batchSize);

    const embeddingsSnapshot = await db.collection("message_embeddings")
      .where("conversationId", "in", batch)
      .orderBy("timestamp", "desc")
      .limit(200) // Limit per batch to avoid huge queries
      .get();

    for (const doc of embeddingsSnapshot.docs) {
      const data = doc.data();
      allEmbeddings.push({
        messageId: doc.id,
        conversationId: data.conversationId,
        embedding: data.embedding,
        messageText: data.messageText || "",
        timestamp: data.timestamp,
      });
    }
  }

  console.log(`[findRelevantMessages] Found ${allEmbeddings.length} embeddings to search`);

  if (allEmbeddings.length === 0) {
    console.log(`[findRelevantMessages] No embeddings found`);
    return [];
  }

  // Step 4: Calculate cosine similarity for all embeddings
  const results: Array<{
    messageId: string;
    conversationId: string;
    messageText: string;
    similarity: number;
    timestamp: FirebaseFirestore.Timestamp;
  }> = [];

  for (const embedding of allEmbeddings) {
    const similarity = cosineSimilarity(queryEmbedding, embedding.embedding);
    results.push({
      messageId: embedding.messageId,
      conversationId: embedding.conversationId,
      messageText: embedding.messageText,
      similarity,
      timestamp: embedding.timestamp,
    });
  }

  // Step 5: Sort by similarity descending and take top K
  results.sort((a, b) => b.similarity - a.similarity);
  const topResults = results.slice(0, topK);

  console.log(`[findRelevantMessages] Returning top ${topResults.length} results`);

  if (topResults.length > 0) {
    console.log(`[findRelevantMessages] Top result similarity: ${topResults[0].similarity.toFixed(3)}`);
  }

  // Convert to SemanticSearchResult
  return topResults.map(result => ({
    messageId: result.messageId,
    text: result.messageText,
    similarity: result.similarity,
    conversationId: result.conversationId,
    timestamp: result.timestamp.toDate(),
  }));
}

/**
 * Find similar messages in a specific conversation
 *
 * Useful for finding past mentions, similar urgent requests, etc.
 *
 * @param conversationId - Conversation ID to search within
 * @param query - Search query text
 * @param topK - Number of top results to return (default: 5)
 * @returns Array of SemanticSearchResult sorted by similarity
 */
export async function findSimilarMessagesInConversation(
  conversationId: string,
  query: string,
  topK: number = 5
): Promise<SemanticSearchResult[]> {
  console.log(`[findSimilarMessagesInConversation] Searching conversation ${conversationId}`);

  const db = admin.firestore();

  // Step 1: Generate embedding for query
  const queryEmbedding = await generateEmbedding(query);

  // Step 2: Fetch embeddings for this conversation
  const embeddingsSnapshot = await db.collection("message_embeddings")
    .where("conversationId", "==", conversationId)
    .orderBy("timestamp", "desc")
    .limit(100)
    .get();

  if (embeddingsSnapshot.empty) {
    console.log(`[findSimilarMessagesInConversation] No embeddings found`);
    return [];
  }

  // Step 3: Calculate cosine similarity
  const results: Array<{
    messageId: string;
    messageText: string;
    similarity: number;
    timestamp: FirebaseFirestore.Timestamp;
  }> = [];

  for (const doc of embeddingsSnapshot.docs) {
    const data = doc.data();
    const similarity = cosineSimilarity(queryEmbedding, data.embedding);

    results.push({
      messageId: doc.id,
      messageText: data.messageText || "",
      similarity,
      timestamp: data.timestamp,
    });
  }

  // Step 4: Sort and take top K
  results.sort((a, b) => b.similarity - a.similarity);
  const topResults = results.slice(0, topK);

  return topResults.map(result => ({
    messageId: result.messageId,
    text: result.messageText,
    similarity: result.similarity,
    conversationId,
    timestamp: result.timestamp.toDate(),
  }));
}
