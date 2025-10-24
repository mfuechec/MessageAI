import * as admin from "firebase-admin";
import {generateEmbeddingsBatch} from "../services/openai-service";
import {IndexingResult, MessageEmbedding} from "../types/NotificationPreferences";

/**
 * Index conversation messages for RAG system
 *
 * Story 6.2: RAG System for Full User Context
 *
 * Lazy embedding strategy: Only embed messages when called.
 * Reuse embeddings if they exist and are < 7 days old.
 *
 * @param conversationId - Conversation ID
 * @param messageIds - Array of message IDs to embed
 * @returns IndexingResult with counts and timing
 */
export async function indexConversationForRAG(
  conversationId: string,
  messageIds: string[]
): Promise<IndexingResult> {
  const startTime = Date.now();

  console.log(`[indexConversationForRAG] Starting for conversation ${conversationId}`);
  console.log(`[indexConversationForRAG] Message IDs: ${messageIds.length}`);

  if (messageIds.length === 0) {
    return {
      embeddedCount: 0,
      reusedCount: 0,
      totalTime: Date.now() - startTime,
    };
  }

  const db = admin.firestore();

  // Step 1: Check for existing embeddings
  const sevenDaysAgo = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() - 7 * 24 * 60 * 60 * 1000)
  );

  // Query existing embeddings (can't combine 'in' on documentId with inequality on timestamp)
  const existingEmbeddings = await db.collection("message_embeddings")
    .where(admin.firestore.FieldPath.documentId(), "in", messageIds.slice(0, 10))
    .get();

  // Filter to recent embeddings in code
  const existingMessageIds = new Set(
    existingEmbeddings.docs
      .filter(doc => {
        const data = doc.data();
        return data.timestamp && data.timestamp > sevenDaysAgo;
      })
      .map(doc => doc.id)
  );

  console.log(`[indexConversationForRAG] Existing embeddings: ${existingMessageIds.size}`);

  // Step 2: Filter to messages that need embedding
  const messageIdsToEmbed = messageIds.filter(
    id => !existingMessageIds.has(id)
  );

  console.log(`[indexConversationForRAG] Messages to embed: ${messageIdsToEmbed.length}`);

  if (messageIdsToEmbed.length === 0) {
    return {
      embeddedCount: 0,
      reusedCount: existingMessageIds.size,
      totalTime: Date.now() - startTime,
    };
  }

  // Step 3: Fetch message data
  const messages = await Promise.all(
    messageIdsToEmbed.map(async (messageId) => {
      const messageDoc = await db.collection("messages").doc(messageId).get();
      return {
        id: messageId,
        data: messageDoc.data(),
      };
    })
  );

  const validMessages = messages.filter(msg => msg.data !== undefined);

  if (validMessages.length === 0) {
    return {
      embeddedCount: 0,
      reusedCount: existingMessageIds.size,
      totalTime: Date.now() - startTime,
    };
  }

  // Step 4: Extract message texts
  const messageTexts = validMessages.map(msg => msg.data!.text || "");

  console.log(`[indexConversationForRAG] Generating embeddings for ${messageTexts.length} messages`);

  // Step 5: Generate embeddings in batch
  let embeddings: number[][];
  try {
    embeddings = await generateEmbeddingsBatch(messageTexts);
  } catch (error) {
    console.error("[indexConversationForRAG] Error generating embeddings:", error);
    throw error;
  }

  // Step 6: Store embeddings in Firestore
  const batch = db.batch();

  validMessages.forEach((msg, index) => {
    const embeddingData: MessageEmbedding = {
      messageId: msg.id,
      conversationId: conversationId,
      embedding: embeddings[index],
      timestamp: msg.data!.timestamp || admin.firestore.FieldValue.serverTimestamp() as FirebaseFirestore.Timestamp,
      participantIds: [], // Will be filled from conversation
      messageText: msg.data!.text || "",
    };

    const embeddingRef = db.collection("message_embeddings").doc(msg.id);
    batch.set(embeddingRef, embeddingData);
  });

  // Fetch conversation for participant IDs
  const conversationDoc = await db.collection("conversations").doc(conversationId).get();
  const participantIds = conversationDoc.data()?.participantIds || [];

  // Update participant IDs in batch
  validMessages.forEach((msg) => {
    const embeddingRef = db.collection("message_embeddings").doc(msg.id);
    batch.update(embeddingRef, {participantIds});
  });

  await batch.commit();

  const totalTime = Date.now() - startTime;

  console.log(`[indexConversationForRAG] Completed in ${totalTime}ms`);
  console.log(`[indexConversationForRAG] Embedded: ${validMessages.length}, Reused: ${existingMessageIds.size}`);

  return {
    embeddedCount: validMessages.length,
    reusedCount: existingMessageIds.size,
    totalTime,
  };
}

/**
 * Get or create embeddings for conversation messages
 *
 * Convenience wrapper that fetches recent messages and indexes them
 *
 * @param conversationId - Conversation ID
 * @param limit - Max number of recent messages to index (default: 30)
 * @returns IndexingResult
 */
export async function indexRecentMessages(
  conversationId: string,
  limit: number = 30
): Promise<IndexingResult> {
  const db = admin.firestore();

  // Fetch recent messages
  const messagesSnapshot = await db.collection("messages")
    .where("conversationId", "==", conversationId)
    .orderBy("timestamp", "desc")
    .limit(limit)
    .get();

  const messageIds = messagesSnapshot.docs.map(doc => doc.id);

  return indexConversationForRAG(conversationId, messageIds);
}
