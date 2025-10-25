import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import {generateEmbedding} from "./services/openai-service";

/**
 * Backfill embeddings for existing messages
 *
 * This function processes existing messages that don't have embeddings yet.
 * Run via: firebase functions:call backfillMessageEmbeddings
 *
 * IMPORTANT: This can take a while and use OpenAI credits.
 * Processes in batches to avoid rate limits.
 */
export const backfillMessageEmbeddings = functions
  .runWith({
    timeoutSeconds: 540, // 9 minutes max
    memory: "2GB",
  })
  .https.onCall(async (data, context) => {
    // Authentication required
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Must be authenticated to run backfill"
      );
    }

    const batchSize = data.batchSize || 50; // Process 50 at a time
    const skipExisting = data.skipExisting !== false; // Default: skip messages that already have embeddings

    console.log(`[backfillMessageEmbeddings] Starting backfill...`);
    console.log(`  Batch size: ${batchSize}`);
    console.log(`  Skip existing: ${skipExisting}`);

    const db = admin.firestore();
    let processed = 0;
    let skipped = 0;
    let errors = 0;

    try {
      // Fetch messages that need embeddings
      let query = db.collection("messages")
        .where("isDeleted", "==", false)
        .orderBy("timestamp", "desc")
        .limit(batchSize);

      const messagesSnapshot = await query.get();

      if (messagesSnapshot.empty) {
        console.log(`[backfillMessageEmbeddings] No messages found`);
        return {
          success: true,
          processed: 0,
          skipped: 0,
          errors: 0,
          message: "No messages to process",
        };
      }

      console.log(`[backfillMessageEmbeddings] Found ${messagesSnapshot.size} messages`);

      // Process messages
      for (const messageDoc of messagesSnapshot.docs) {
        const messageId = messageDoc.id;
        const messageData = messageDoc.data();
        const messageText = messageData.text || "";

        // Skip empty messages
        if (messageText.trim().length === 0) {
          console.log(`[backfillMessageEmbeddings] Skipping empty message ${messageId}`);
          skipped++;
          continue;
        }

        // Skip if already has embedding in message_embeddings collection
        if (skipExisting) {
          const existingEmbedding = await db.collection("message_embeddings")
            .doc(messageId)
            .get();

          if (existingEmbedding.exists) {
            console.log(`[backfillMessageEmbeddings] Skipping ${messageId}: already has embedding`);
            skipped++;
            continue;
          }
        }

        try {
          console.log(`[backfillMessageEmbeddings] Processing message ${messageId}`);

          // Generate embedding
          const embedding = await generateEmbedding(messageText);

          // Store in batch
          const batch = db.batch();

          // Update message document
          batch.update(messageDoc.ref, {
            embedding: embedding,
            embeddedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          // Store in message_embeddings collection
          const embeddingRef = db.collection("message_embeddings").doc(messageId);
          batch.set(embeddingRef, {
            messageId: messageId,
            conversationId: messageData.conversationId,
            senderId: messageData.senderId,
            messageText: messageText,
            embedding: embedding,
            timestamp: messageData.timestamp,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            model: "text-embedding-ada-002",
          });

          await batch.commit();

          processed++;
          console.log(`[backfillMessageEmbeddings] ✅ [${processed}/${messagesSnapshot.size}] Embedded message ${messageId}`);
        } catch (error: any) {
          errors++;
          console.error(`[backfillMessageEmbeddings] ❌ Error processing ${messageId}:`, error.message);

          // Log error to collection for debugging
          await db.collection("embedding_errors").add({
            messageId,
            error: error.message,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
          });
        }

        // Rate limit protection: wait 1 second between messages to avoid OpenAI rate limits
        await new Promise((resolve) => setTimeout(resolve, 1000));
      }

      const message = `Backfill complete: ${processed} processed, ${skipped} skipped, ${errors} errors`;
      console.log(`[backfillMessageEmbeddings] ${message}`);

      return {
        success: true,
        processed,
        skipped,
        errors,
        message,
        hasMore: messagesSnapshot.size === batchSize,
      };
    } catch (error: any) {
      console.error("[backfillMessageEmbeddings] Fatal error:", error);
      throw new functions.https.HttpsError(
        "internal",
        `Backfill failed: ${error.message}`
      );
    }
  });
