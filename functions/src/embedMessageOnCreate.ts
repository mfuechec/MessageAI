import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import {generateEmbedding} from "./services/openai-service";

/**
 * Cloud Function: Embed Message On Create
 *
 * Epic 6 - Performance Optimization #4
 *
 * Firestore Trigger: Generates semantic embedding when new message created
 * Runs asynchronously - doesn't block message sending
 *
 * Benefits:
 * - Pre-computed embeddings = 0ms indexing time during notification analysis
 * - RAG queries become instant (no on-demand embedding generation)
 * - User experience: messages send instantly, embeddings computed in background
 */
export const embedMessageOnCreate = functions
  .runWith({
    timeoutSeconds: 30,
    memory: "256MB",
  })
  .firestore.document("messages/{messageId}")
  .onCreate(async (snap, context) => {
    const messageData = snap.data();
    const messageText = messageData.text || "";

    // Skip empty messages
    if (messageText.trim().length === 0) {
      console.log(`[embedMessageOnCreate] Skipping empty message ${snap.id}`);
      return null;
    }

    // Skip if already has embedding
    if (messageData.embedding) {
      console.log(`[embedMessageOnCreate] Message ${snap.id} already has embedding`);
      return null;
    }

    try {
      console.log(`[embedMessageOnCreate] Generating embedding for message ${snap.id}`);

      // Fetch sender and participant information for enriched embeddings
      const db = admin.firestore();

      // Step 1: Fetch sender info
      const senderDoc = await db.collection("users").doc(messageData.senderId).get();
      const senderName = senderDoc.data()?.displayName || "Unknown";

      // Step 2: Fetch conversation participants
      const conversationDoc = await db.collection("conversations")
        .doc(messageData.conversationId)
        .get();

      const participantIds = conversationDoc.data()?.participantIds || [];

      // Fetch participant names in parallel for performance
      const participantPromises = participantIds
        .filter((id: string) => id !== messageData.senderId) // Exclude sender
        .map((id: string) => db.collection("users").doc(id).get());

      const participantDocs = await Promise.all(participantPromises);
      const participantNames = participantDocs
        .map(doc => doc.data()?.displayName)
        .filter(Boolean);

      // Step 3: Create enriched text with context
      const enrichedText = `
From: ${senderName}
Participants: ${participantNames.join(', ')}
Message: ${messageText}
`.trim();

      console.log(`[embedMessageOnCreate] Enriched text: ${enrichedText.substring(0, 100)}...`);

      // Step 4: Generate embedding from enriched text
      const embedding = await generateEmbedding(enrichedText);

      // Store in both locations:
      // 1. In message document for backward compatibility
      // 2. In message_embeddings collection for fast semantic search
      const batch = db.batch();

      // Update message with embedding
      batch.update(snap.ref, {
        embedding: embedding,
        embeddedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Store in message_embeddings collection for fast queries
      const embeddingRef = db.collection("message_embeddings").doc(snap.id);
      batch.set(embeddingRef, {
        messageId: snap.id,
        conversationId: messageData.conversationId,
        senderId: messageData.senderId,
        messageText: messageText,          // Original message text
        enrichedText: enrichedText,         // Enriched text with participant context
        embedding: embedding,
        timestamp: messageData.timestamp,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        model: "text-embedding-ada-002",
      });

      await batch.commit();

      console.log(`[embedMessageOnCreate] ✅ Embedded message ${snap.id} (stored in both locations)`);
    } catch (error) {
      console.error(`[embedMessageOnCreate] ❌ Error embedding message ${snap.id}:`, error);
      // Don't throw - message is already saved, embedding is optional
    }

    return null;
  });
