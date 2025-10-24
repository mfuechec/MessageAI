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

      const embedding = await generateEmbedding(messageText);

      await snap.ref.update({
        embedding: embedding,
        embeddedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`[embedMessageOnCreate] ✅ Embedded message ${snap.id}`);
    } catch (error) {
      console.error(`[embedMessageOnCreate] ❌ Error embedding message ${snap.id}:`, error);
      // Don't throw - message is already saved, embedding is optional
    }

    return null;
  });
