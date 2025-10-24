/**
 * Test script to manually trigger profile update and view results
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin
admin.initializeApp({
  projectId: 'messageai-dev-1f2ec'
});

const db = admin.firestore();

async function testProfileUpdate() {
  const userId = 'v64FPlQvfWTblskskM9z6nkaj3b2'; // tester2@gmail.com

  console.log('========================================');
  console.log('TESTING AI LEARNING PROFILE UPDATE');
  console.log('========================================\n');

  console.log(`User ID: ${userId}\n`);

  // Manually call the updateSingleUserProfile logic
  console.log('1. Fetching feedback from last 30 days...\n');

  const thirtyDaysAgo = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() - 30 * 24 * 60 * 60 * 1000)
  );

  const feedbackSnapshot = await db.collection('notification_feedback')
    .where('userId', '==', userId)
    .where('timestamp', '>', thirtyDaysAgo)
    .orderBy('timestamp', 'desc')
    .get();

  console.log(`Found ${feedbackSnapshot.size} feedback entries\n`);

  if (feedbackSnapshot.empty) {
    console.log('⚠️  No feedback found. Cannot generate profile.');
    process.exit(0);
  }

  // Analyze feedback
  let helpfulCount = 0;
  let notHelpfulCount = 0;

  feedbackSnapshot.forEach((doc) => {
    const data = doc.data();
    if (data.feedback === 'helpful') {
      helpfulCount++;
    } else if (data.feedback === 'not_helpful') {
      notHelpfulCount++;
    }
  });

  console.log('2. Feedback Summary:');
  console.log(`   - Helpful: ${helpfulCount}`);
  console.log(`   - Not Helpful: ${notHelpfulCount}`);
  console.log(`   - Total: ${helpfulCount + notHelpfulCount}\n`);

  // Check current profile
  console.log('3. Checking current AI profile...\n');

  const profileDoc = await db.collection('users')
    .doc(userId)
    .collection('ai_notification_profile')
    .doc('profile')
    .get();

  if (profileDoc.exists) {
    const profile = profileDoc.data();
    console.log('✅ Current Profile:');
    console.log(JSON.stringify(profile, null, 2));
  } else {
    console.log('⚠️  No profile found yet. First update will create it.');
  }

  console.log('\n========================================');
  console.log('TEST COMPLETE');
  console.log('========================================');

  process.exit(0);
}

testProfileUpdate().catch((error) => {
  console.error('Error:', error);
  process.exit(1);
});
