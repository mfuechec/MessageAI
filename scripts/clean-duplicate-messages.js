#!/usr/bin/env node

/**
 * Clean Duplicate Messages Script
 *
 * Finds and removes duplicate messages (same text + sender in same conversation)
 * Keeps the earliest message, removes later duplicates with different IDs
 *
 * Usage:
 *   node scripts/clean-duplicate-messages.js [--prod]
 */

const admin = require('firebase-admin');
const path = require('path');

// Parse command line args
const isProd = process.argv.includes('--prod');
const environment = isProd ? 'prod' : 'dev';

console.log(`\n🧹 Cleaning duplicate messages in ${environment.toUpperCase()} database...\n`);

// Load appropriate service account key
const serviceAccountPath = path.join(__dirname, '..', `firebase-admin-key-${environment}.json`);

try {
  const serviceAccount = require(serviceAccountPath);

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });

  console.log(`✅ Connected to Firebase project: ${serviceAccount.project_id}\n`);
} catch (error) {
  console.error(`❌ Failed to load service account key: ${serviceAccountPath}`);
  console.error(`   Please download the key from Firebase Console:`);
  console.error(`   1. Go to Project Settings → Service Accounts`);
  console.error(`   2. Click "Generate New Private Key"`);
  console.error(`   3. Save as: firebase-admin-key-${environment}.json`);
  console.error(`   4. Move to project root directory\n`);
  process.exit(1);
}

const db = admin.firestore();

async function cleanDuplicateMessages() {
  try {
    console.log('📝 Step 1: Fetching all conversations...\n');

    const conversationsSnapshot = await db.collection('conversations').get();
    console.log(`✅ Found ${conversationsSnapshot.size} conversation(s)\n`);

    let totalDuplicates = 0;
    let totalDeleted = 0;

    for (const convDoc of conversationsSnapshot.docs) {
      const conversationId = convDoc.id;
      console.log(`🔍 Checking conversation: ${conversationId.substring(0, 8)}...`);

      // Get all messages in this conversation
      const messagesSnapshot = await db.collection('messages')
        .where('conversationId', '==', conversationId)
        .orderBy('timestamp', 'asc')
        .get();

      if (messagesSnapshot.empty) {
        console.log(`   No messages found\n`);
        continue;
      }

      console.log(`   Found ${messagesSnapshot.size} message(s)`);

      // Group messages by text + senderId to find duplicates
      const messageGroups = new Map();

      messagesSnapshot.docs.forEach(doc => {
        const data = doc.data();
        const key = `${data.senderId}:${data.text}`;

        if (!messageGroups.has(key)) {
          messageGroups.set(key, []);
        }

        messageGroups.get(key).push({
          id: doc.id,
          timestamp: data.timestamp,
          text: data.text,
          senderId: data.senderId
        });
      });

      // Find groups with duplicates
      let conversationDuplicates = 0;
      const batch = db.batch();

      for (const [key, messages] of messageGroups.entries()) {
        if (messages.length > 1) {
          // Sort by timestamp (earliest first)
          messages.sort((a, b) => a.timestamp.toMillis() - b.timestamp.toMillis());

          // Keep the first (earliest) message, delete the rest
          const toKeep = messages[0];
          const toDelete = messages.slice(1);

          console.log(`   ⚠️ Found ${messages.length} duplicate messages with text: "${messages[0].text.substring(0, 30)}..."`);
          console.log(`      Keeping: ${toKeep.id.substring(0, 8)}... (${toKeep.timestamp.toDate().toISOString()})`);

          for (const duplicate of toDelete) {
            console.log(`      Deleting: ${duplicate.id.substring(0, 8)}... (${duplicate.timestamp.toDate().toISOString()})`);
            batch.delete(db.collection('messages').doc(duplicate.id));
            conversationDuplicates++;
          }
        }
      }

      if (conversationDuplicates > 0) {
        await batch.commit();
        totalDuplicates += conversationDuplicates;
        totalDeleted += conversationDuplicates;
        console.log(`   🗑️ Deleted ${conversationDuplicates} duplicate message(s)\n`);
      } else {
        console.log(`   ✅ No duplicates found\n`);
      }
    }

    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('✅ Duplicate message cleanup complete!\n');
    console.log(`📊 Summary:`);
    console.log(`   • Total conversations checked: ${conversationsSnapshot.size}`);
    console.log(`   • Duplicate messages found: ${totalDuplicates}`);
    console.log(`   • Messages deleted: ${totalDeleted}\n`);

  } catch (error) {
    console.error('\n❌ Error cleaning duplicate messages:', error);
    console.error(error.stack);
    process.exit(1);
  }
}

// Run the script
cleanDuplicateMessages()
  .then(() => {
    console.log('✨ Done!\n');
    process.exit(0);
  })
  .catch(error => {
    console.error('❌ Fatal error:', error);
    process.exit(1);
  });
