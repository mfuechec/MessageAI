/**
 * Simple backfill script using firebase-tools authentication
 *
 * Run with: node scripts/simpleBackfill.js
 */

const admin = require('firebase-admin');
const functions = require('firebase-functions');

// Initialize with project ID (uses firebase-tools auth automatically)
admin.initializeApp({
  projectId: 'messageai-dev-1f2ec'
});

// Load OpenAI API key from environment variable
// Set with: export OPENAI_API_KEY=your-key-here
const OPENAI_API_KEY = process.env.OPENAI_API_KEY;

if (!OPENAI_API_KEY) {
  console.error('❌ Error: OPENAI_API_KEY environment variable not set');
  console.error('📝 Set it with: export OPENAI_API_KEY=your-key-here');
  process.exit(1);
}

const db = admin.firestore();

async function generateEmbedding(text) {
  const response = await fetch('https://api.openai.com/v1/embeddings', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${OPENAI_API_KEY}`
    },
    body: JSON.stringify({
      model: 'text-embedding-ada-002',
      input: text
    })
  });

  if (!response.ok) {
    throw new Error(`OpenAI API error: ${response.statusText}`);
  }

  const data = await response.json();
  return data.data[0].embedding;
}

async function backfillEmbeddings(batchSize = 50) {
  console.log('🚀 Starting backfill for message embeddings...');
  console.log(`📦 Batch size: ${batchSize}\n`);

  let processed = 0;
  let skipped = 0;
  let errors = 0;

  try {
    // Fetch messages
    const messagesSnapshot = await db.collection('messages')
      .where('isDeleted', '==', false)
      .orderBy('timestamp', 'desc')
      .limit(batchSize)
      .get();

    if (messagesSnapshot.empty) {
      console.log('✅ No messages found to process');
      return;
    }

    console.log(`📊 Found ${messagesSnapshot.size} messages to process\n`);

    // Process messages one by one
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

      // Force re-generation to get enriched embeddings with participant context
      // (Comment out this check to regenerate all embeddings)
      // const existingEmbedding = await db.collection('message_embeddings')
      //   .doc(messageId)
      //   .get();
      //
      // if (existingEmbedding.exists) {
      //   console.log(`⏭️  Skipping ${messageId}: already has embedding`);
      //   skipped++;
      //   continue;
      // }

      try {
        console.log(`🔄 Processing message ${messageId}...`);
        console.log(`   Text: "${messageText.substring(0, 50)}${messageText.length > 50 ? '...' : ''}"`);

        // Fetch sender and participant information for enriched embeddings
        // Step 1: Fetch sender info
        const senderDoc = await db.collection('users').doc(messageData.senderId).get();
        const senderName = senderDoc.data()?.displayName || 'Unknown';

        // Step 2: Fetch conversation participants
        const conversationDoc = await db.collection('conversations')
          .doc(messageData.conversationId)
          .get();

        const participantIds = conversationDoc.data()?.participantIds || [];

        // Fetch participant names in parallel for performance
        const participantPromises = participantIds
          .filter((id) => id !== messageData.senderId) // Exclude sender
          .map((id) => db.collection('users').doc(id).get());

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

        console.log(`   📝 Enriched: "${enrichedText.substring(0, 70)}${enrichedText.length > 70 ? '...' : ''}"`);

        // Generate embedding from enriched text
        const embedding = await generateEmbedding(enrichedText);
        console.log(`   ✅ Generated embedding (${embedding.length} dimensions)`);

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
          enrichedText: enrichedText,           // Store enriched text
          embedding: embedding,
          timestamp: messageData.timestamp,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          model: 'text-embedding-ada-002',
        });

        await batch.commit();
        console.log(`   💾 Saved to Firestore`);

        processed++;
        console.log(`✅ [${processed}/${messagesSnapshot.size}] Completed\n`);
      } catch (error) {
        errors++;
        console.error(`❌ Error processing ${messageId}:`, error.message);
        console.log('');
      }

      // Rate limit protection: wait 1 second between messages
      await new Promise((resolve) => setTimeout(resolve, 1000));
    }

    console.log('═'.repeat(50));
    console.log('📊 BACKFILL SUMMARY');
    console.log('═'.repeat(50));
    console.log(`✅ Processed: ${processed}`);
    console.log(`⏭️  Skipped:   ${skipped}`);
    console.log(`❌ Errors:    ${errors}`);
    console.log(`📈 Total:     ${messagesSnapshot.size}`);
    console.log('═'.repeat(50));

    if (messagesSnapshot.size === batchSize) {
      console.log('\n⚠️  More messages may exist. Run again to process next batch.');
    } else {
      console.log('\n🎉 All messages processed!');
    }

  } catch (error) {
    console.error('💥 Fatal error:', error);
    throw error;
  }
}

// Run backfill
console.log('╔' + '═'.repeat(50) + '╗');
console.log('║' + ' '.repeat(10) + 'MESSAGE EMBEDDINGS BACKFILL' + ' '.repeat(13) + '║');
console.log('╚' + '═'.repeat(50) + '╝');
console.log('');

backfillEmbeddings(50)
  .then(() => {
    console.log('\n✅ Backfill complete');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n💥 Backfill failed:', error);
    process.exit(1);
  });
