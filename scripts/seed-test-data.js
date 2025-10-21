#!/usr/bin/env node

/**
 * Seed Test Data Script
 * 
 * Creates test users, conversations, and messages in Firebase for manual testing.
 * This script uses Firebase Admin SDK to directly populate Firestore and Auth.
 * 
 * Usage:
 *   node scripts/seed-test-data.js [--prod]
 * 
 * By default, seeds DEV database. Use --prod flag for production (use carefully!).
 */

const admin = require('firebase-admin');
const path = require('path');

// Parse command line args
const isProd = process.argv.includes('--prod');
const environment = isProd ? 'prod' : 'dev';

console.log(`\n🌱 Seeding ${environment.toUpperCase()} database...\n`);

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
const auth = admin.auth();

// Test data configuration
const TEST_USERS = [
  {
    email: 'test1@messageai.dev',
    password: 'password123',
    displayName: 'Alice TestUser',
    photoURL: null
  },
  {
    email: 'test2@messageai.dev',
    password: 'password123',
    displayName: 'Bob TestUser',
    photoURL: null
  },
  {
    email: 'test3@messageai.dev',
    password: 'password123',
    displayName: 'Charlie TestUser',
    photoURL: null
  }
];

// Helper: Create or get existing user
async function createOrGetUser(userData) {
  try {
    // Try to get existing user by email
    const existingUser = await auth.getUserByEmail(userData.email);
    console.log(`  ✓ User already exists: ${userData.email} (${existingUser.uid})`);
    
    // Update user profile if needed
    const updateData = {
      displayName: userData.displayName
    };
    if (userData.photoURL) {
      updateData.photoURL = userData.photoURL;
    }
    await auth.updateUser(existingUser.uid, updateData);
    
    return existingUser.uid;
  } catch (error) {
    if (error.code === 'auth/user-not-found') {
      // Create new user
      const createData = {
        email: userData.email,
        password: userData.password,
        displayName: userData.displayName,
        emailVerified: true
      };
      if (userData.photoURL) {
        createData.photoURL = userData.photoURL;
      }
      const userRecord = await auth.createUser(createData);
      console.log(`  ✓ Created user: ${userData.email} (${userRecord.uid})`);
      return userRecord.uid;
    }
    throw error;
  }
}

// Helper: Create user document in Firestore
async function createUserDocument(uid, userData) {
  const userDoc = {
    id: uid,
    email: userData.email,
    displayName: userData.displayName,
    profileImageURL: userData.photoURL || null,
    isOnline: false,
    lastSeen: admin.firestore.FieldValue.serverTimestamp(),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    fcmToken: null,
    timezone: null,
    locale: null,
    preferredLanguage: null,
    schemaVersion: 1
  };
  
  await db.collection('users').doc(uid).set(userDoc, { merge: true });
  console.log(`  ✓ Created/updated user document: ${userData.email}`);
}

// Helper: Create conversation
async function createConversation(participantIds, participantData) {
  const conversationId = `test-conv-${Date.now()}`;
  const now = new Date();
  
  // Build unreadCounts map
  const unreadCounts = {};
  participantIds.forEach(id => {
    unreadCounts[id] = 0;
  });
  
  const conversationDoc = {
    id: conversationId,
    participantIds: participantIds,
    lastMessage: 'Hello! This is a test conversation.',
    lastMessageTimestamp: admin.firestore.Timestamp.fromDate(now),
    lastMessageSenderId: participantIds[0],
    lastMessageId: null,
    unreadCounts: unreadCounts,
    typingUsers: [],
    createdAt: admin.firestore.Timestamp.fromDate(new Date(now.getTime() - 3600000)), // 1 hour ago
    isGroup: participantIds.length > 2,
    groupName: null,
    lastAISummaryAt: null,
    hasUnreadPriority: false,
    priorityCount: 0,
    activeSchedulingDetected: false,
    schedulingDetectedAt: null,
    isMuted: false,
    mutedUntil: null,
    isArchived: false,
    archivedAt: null,
    schemaVersion: 1
  };
  
  await db.collection('conversations').doc(conversationId).set(conversationDoc);
  
  const participantNames = participantData.map(p => p.displayName).join(' & ');
  console.log(`  ✓ Created conversation: ${conversationId}`);
  console.log(`    Participants: ${participantNames}`);
  
  return conversationId;
}

// Helper: Create messages
async function createMessages(conversationId, participantIds, participantData, count = 5) {
  console.log(`  ✓ Creating ${count} test messages...`);
  
  const messages = [
    "Hey! How's it going?",
    "Pretty good! Just working on this new project.",
    "Nice! What are you building?",
    "A messaging app with AI features. It's pretty cool!",
    "That sounds awesome! Let me know when I can try it."
  ];
  
  const now = Date.now();
  
  for (let i = 0; i < Math.min(count, messages.length); i++) {
    const messageId = `msg-${Date.now()}-${i}`;
    const senderId = participantIds[i % participantIds.length];
    const senderName = participantData.find(p => p.uid === senderId).displayName;
    
    const messageDoc = {
      id: messageId,
      conversationId: conversationId,
      senderId: senderId,
      senderName: senderName,
      text: messages[i],
      timestamp: admin.firestore.Timestamp.fromDate(new Date(now - (count - i) * 60000)), // 1 minute apart
      status: 'sent',
      isEdited: false,
      editHistory: [],
      attachments: [],
      localId: null,
      schemaVersion: 1
    };
    
    await db.collection('messages').doc(messageId).set(messageDoc);
    console.log(`    • ${senderName}: "${messages[i]}"`);
  }
}

// Main seeding function
async function seedDatabase() {
  try {
    console.log('📝 Step 1: Creating Firebase Auth users...\n');
    
    // Create users in Auth and get their UIDs
    const userIds = [];
    for (const userData of TEST_USERS) {
      const uid = await createOrGetUser(userData);
      userIds.push(uid);
    }
    
    console.log('\n📝 Step 2: Creating user documents in Firestore...\n');
    
    // Create user documents
    const userDataWithIds = [];
    for (let i = 0; i < TEST_USERS.length; i++) {
      await createUserDocument(userIds[i], TEST_USERS[i]);
      userDataWithIds.push({
        uid: userIds[i],
        ...TEST_USERS[i]
      });
    }
    
    console.log('\n📝 Step 3: Creating test conversations...\n');
    
    // Create 1-on-1 conversation between first two users
    const conv1Id = await createConversation(
      [userIds[0], userIds[1]],
      userDataWithIds.slice(0, 2)
    );
    
    // Create messages in first conversation
    await createMessages(conv1Id, [userIds[0], userIds[1]], userDataWithIds, 5);
    
    // Create another 1-on-1 conversation
    const conv2Id = await createConversation(
      [userIds[0], userIds[2]],
      [userDataWithIds[0], userDataWithIds[2]]
    );
    
    // Create messages in second conversation
    await createMessages(conv2Id, [userIds[0], userIds[2]], userDataWithIds, 3);
    
    // Create group conversation
    const conv3Id = await createConversation(
      userIds,
      userDataWithIds
    );
    
    await createMessages(conv3Id, userIds, userDataWithIds, 4);
    
    console.log('\n✅ Database seeding complete!\n');
    console.log('📱 Test Users (use these to sign in):');
    console.log('─────────────────────────────────────────');
    TEST_USERS.forEach((user, i) => {
      console.log(`   ${i + 1}. ${user.email} / ${user.password}`);
      console.log(`      UID: ${userIds[i]}`);
    });
    console.log('\n🎯 Next Steps:');
    console.log('   1. Launch the iOS app in Xcode');
    console.log('   2. Sign in with any of the test accounts above');
    console.log('   3. You should see 2-3 conversations in the list');
    console.log('   4. Tap a conversation to view messages');
    console.log('   5. Open another simulator and sign in as different user');
    console.log('   6. Send messages to test real-time sync\n');
    
  } catch (error) {
    console.error('\n❌ Error seeding database:', error);
    console.error(error.stack);
    process.exit(1);
  }
}

// Run the script
seedDatabase()
  .then(() => {
    console.log('✨ Done!\n');
    process.exit(0);
  })
  .catch(error => {
    console.error('❌ Fatal error:', error);
    process.exit(1);
  });

