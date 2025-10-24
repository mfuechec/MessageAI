#!/usr/bin/env node

/**
 * Add Priority Test Data Script
 *
 * Updates an existing conversation to have priority messages for testing badges.
 *
 * Usage:
 *   node scripts/add-priority-test-data.js [--prod]
 */

const admin = require('firebase-admin');
const path = require('path');

// Parse command line args
const isProd = process.argv.includes('--prod');
const environment = isProd ? 'prod' : 'dev';

console.log(`\n🎯 Adding priority test data to ${environment.toUpperCase()} database...\n`);

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

async function addPriorityTestData() {
  try {
    console.log('📝 Step 1: Finding existing conversations...\n');

    // Get first conversation
    const snapshot = await db.collection('conversations')
      .orderBy('lastMessageTimestamp', 'desc')
      .limit(1)
      .get();

    if (snapshot.empty) {
      console.error('❌ No conversations found. Please run seed-test-data.js first.\n');
      process.exit(1);
    }

    const conversationDoc = snapshot.docs[0];
    const conversationId = conversationDoc.id;
    const conversationData = conversationDoc.data();

    console.log(`✅ Found conversation: ${conversationId}`);
    console.log(`   Participants: ${conversationData.participantIds.length} users\n`);

    console.log('📝 Step 2: Updating conversation with priority flags...\n');

    // Update conversation with priority data
    await db.collection('conversations').doc(conversationId).update({
      hasUnreadPriority: true,
      priorityCount: 3,
      lastMessage: '🚨 URGENT: Need your approval on the contract by EOD',
      lastMessageTimestamp: admin.firestore.FieldValue.serverTimestamp()
    });

    console.log(`✅ Updated conversation with:`);
    console.log(`   • hasUnreadPriority: true`);
    console.log(`   • priorityCount: 3`);
    console.log(`   • lastMessage: "🚨 URGENT: Need your approval on the contract by EOD"\n`);

    console.log('📝 Step 3: Creating a priority message...\n');

    // Create a priority message
    const messageId = `msg-priority-${Date.now()}`;
    const senderId = conversationData.participantIds[1] || conversationData.participantIds[0];

    const priorityMessageDoc = {
      id: messageId,
      conversationId: conversationId,
      senderId: senderId,
      senderName: 'Test User',
      text: '🚨 URGENT: Need your approval on the contract by EOD',
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      status: 'sent',
      statusUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      isEdited: false,
      isDeleted: false,
      editHistory: [],
      editCount: 0,
      attachments: [],
      readBy: [senderId],
      readCount: 1,
      isPriority: true,
      priorityReason: 'Deadline mentioned (EOD), urgent language detected',
      localId: null,
      schemaVersion: 1
    };

    await db.collection('messages').doc(messageId).set(priorityMessageDoc);

    console.log(`✅ Created priority message`);
    console.log(`   • isPriority: true`);
    console.log(`   • priorityReason: "Deadline mentioned (EOD), urgent language detected"\n`);

    console.log('✅ Priority test data added successfully!\n');
    console.log('🎯 Next Steps:');
    console.log('   1. Launch the iOS app');
    console.log('   2. You should see orange priority badge [!3] on the conversation');
    console.log('   3. The unread count badge should be RED instead of blue');
    console.log('   4. Open the conversation to see the priority message\n');

  } catch (error) {
    console.error('\n❌ Error adding priority test data:', error);
    console.error(error.stack);
    process.exit(1);
  }
}

// Run the script
addPriorityTestData()
  .then(() => {
    console.log('✨ Done!\n');
    process.exit(0);
  })
  .catch(error => {
    console.error('❌ Fatal error:', error);
    process.exit(1);
  });
