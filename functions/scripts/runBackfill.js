/**
 * Script to run backfill for message embeddings
 *
 * Usage: node scripts/runBackfill.js
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('../service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// Import the necessary functions
const { generateEmbedding } = require('../lib/services/openai-service');

async function backfillEmbeddings(batchSize = 50) {
  console.log('🚀 Starting backfill for message embeddings...');
  console.log(`📦 Batch size: ${batchSize}`);

  let processed = 0;
  let skipped = 0;
  let errors = 0;

  try {
    // Fetch messages that need embeddings
    const messagesSnapshot = await db.collection('messages')
      .where('isDeleted', '==', false)
      .orderBy('timestamp', 'desc')
      .limit(batchSize)
      .get();

    if (messagesSnapshot.empty) {
      console.log('✅ No messages found to process');
      return;
    }

    console.log(`📊 Found ${messagesSnapshot.size} messages to process`);

    // Process messages
    for (const messageDoc of messagesSnapshot.docs) {
      const messageId = messageDoc.id;
      const messageData = messageDoc.data();
      const messageText = messageData.text || '';

      // Skip empty messages
      if (messageText.trim().length === 0) {
        console.log(`⏭️  Skipping empty message ${messageId}`);
        skipped++;
        continue;
      }

      // Check if already has embedding
      const existingEmbedding = await db.collection('message_embeddings')
        .doc(messageId)
        .get();

      if (existingEmbedding.exists) {
        console.log(`⏭️  Skipping ${messageId}: already has embedding`);
        skipped++;
        continue;
      }

      try {
        console.log(`🔄 Processing message ${messageId}...`);

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
        const embeddingRef = db.collection('message_embeddings').doc(messageId);
        batch.set(embeddingRef, {
          messageId: messageId,
          conversationId: messageData.conversationId,
          senderId: messageData.senderId,
          messageText: messageText,
          embedding: embedding,
          timestamp: messageData.timestamp,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          model: 'text-embedding-ada-002',
        });

        await batch.commit();

        processed++;
        console.log(`✅ [${processed}/${messagesSnapshot.size}] Embedded message ${messageId}`);
      } catch (error) {
        errors++;
        console.error(`❌ Error processing ${messageId}:`, error.message);
      }

      // Rate limit protection: wait 1 second between messages
      await new Promise((resolve) => setTimeout(resolve, 1000));
    }

    console.log('\n📊 Backfill Summary:');
    console.log(`   ✅ Processed: ${processed}`);
    console.log(`   ⏭️  Skipped: ${skipped}`);
    console.log(`   ❌ Errors: ${errors}`);
    console.log(`   📈 Total: ${messagesSnapshot.size}`);

    if (messagesSnapshot.size === batchSize) {
      console.log('\n⚠️  More messages may exist. Run again to process next batch.');
    } else {
      console.log('\n🎉 All messages processed!');
    }

  } catch (error) {
    console.error('💥 Fatal error:', error);
  } finally {
    await admin.app().delete();
  }
}

// Run backfill
backfillEmbeddings(50).then(() => {
  console.log('✅ Backfill complete');
  process.exit(0);
}).catch((error) => {
  console.error('💥 Backfill failed:', error);
  process.exit(1);
});
