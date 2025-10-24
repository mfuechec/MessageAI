/**
 * Script to check if notification feedback is being properly recorded
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin
admin.initializeApp({
  projectId: 'messageai-dev-1f2ec'
});

const db = admin.firestore();

async function checkFeedback() {
  console.log('========================================');
  console.log('CHECKING NOTIFICATION FEEDBACK');
  console.log('========================================\n');

  const userId = 'v64FPlQvfWTblskskM9z6nkaj3b2'; // tester2@gmail.com

  // 1. Check notification_feedback collection
  console.log('1. Checking notification_feedback collection...\n');
  const feedbackSnapshot = await db.collection('notification_feedback')
    .where('userId', '==', userId)
    .orderBy('timestamp', 'desc')
    .limit(10)
    .get();

  console.log(`Found ${feedbackSnapshot.size} feedback documents:\n`);

  feedbackSnapshot.forEach((doc) => {
    const data = doc.data();
    console.log(`📝 Feedback ID: ${doc.id}`);
    console.log(`   Conversation: ${data.conversationId}`);
    console.log(`   Message: ${data.messageId}`);
    console.log(`   Feedback: ${data.feedback}`);
    console.log(`   Timestamp: ${data.timestamp?.toDate().toISOString()}`);
    console.log('');
  });

  // 2. Check notification_decisions collection
  console.log('\n2. Checking notification_decisions collection...\n');
  const decisionsSnapshot = await db.collection('notification_decisions')
    .where('userId', '==', userId)
    .orderBy('timestamp', 'desc')
    .limit(10)
    .get();

  console.log(`Found ${decisionsSnapshot.size} decision documents:\n`);

  let feedbackCount = 0;
  decisionsSnapshot.forEach((doc) => {
    const data = doc.data();
    if (data.userFeedback) {
      feedbackCount++;
      console.log(`✅ Decision ID: ${doc.id}`);
      console.log(`   Conversation: ${data.conversationId}`);
      console.log(`   Message: ${data.messageId}`);
      console.log(`   Decision: ${data.decision ? 'NOTIFY' : 'SUPPRESS'}`);
      console.log(`   User Feedback: ${data.userFeedback}`);
      console.log(`   Timestamp: ${data.timestamp?.toDate().toISOString()}`);
      console.log('');
    }
  });

  console.log(`\n📊 Summary: ${feedbackCount}/${decisionsSnapshot.size} decisions have user feedback\n`);

  // 3. Check for mismatches (feedback in feedback collection but not in decisions)
  console.log('\n3. Checking for data consistency...\n');

  const feedbackMessageIds = new Set();
  feedbackSnapshot.forEach((doc) => {
    feedbackMessageIds.add(doc.data().messageId);
  });

  const decisionsWithFeedback = new Set();
  decisionsSnapshot.forEach((doc) => {
    const data = doc.data();
    if (data.userFeedback) {
      decisionsWithFeedback.add(data.messageId);
    }
  });

  const missingInDecisions = Array.from(feedbackMessageIds).filter(
    id => !decisionsWithFeedback.has(id)
  );

  if (missingInDecisions.length > 0) {
    console.log(`⚠️  WARNING: ${missingInDecisions.length} feedback entries not reflected in decisions:`);
    missingInDecisions.forEach(id => console.log(`   - Message ID: ${id}`));
  } else {
    console.log('✅ All feedback is properly synced between collections');
  }

  console.log('\n========================================');
  process.exit(0);
}

checkFeedback().catch((error) => {
  console.error('Error checking feedback:', error);
  process.exit(1);
});
