#!/usr/bin/env node

/**
 * Cleanup Duplicate Conversations Script
 * 
 * Finds and removes duplicate conversations with identical participantIds.
 * Keeps the oldest conversation (earliest createdAt) and deletes newer duplicates.
 * 
 * Usage:
 *   node scripts/cleanup-duplicates.js [--prod] [--dry-run]
 * 
 * --dry-run: Show what would be deleted without actually deleting
 */

const admin = require('firebase-admin');
const path = require('path');

// Parse command line args
const isProd = process.argv.includes('--prod');
const isDryRun = process.argv.includes('--dry-run');
const environment = isProd ? 'prod' : 'dev';

console.log(`\n🧹 Cleaning up duplicate conversations in ${environment.toUpperCase()} database...`);
if (isDryRun) {
  console.log(`📋 DRY RUN MODE - No data will be deleted\n`);
} else {
  console.log(`⚠️  LIVE MODE - Duplicates will be permanently deleted\n`);
}

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
  process.exit(1);
}

const db = admin.firestore();

async function findDuplicateConversations() {
  console.log('🔍 Scanning for duplicate conversations...\n');
  
  // Get all conversations
  const snapshot = await db.collection('conversations').get();
  
  if (snapshot.empty) {
    console.log('No conversations found.');
    return { duplicates: [], kept: [] };
  }
  
  console.log(`Found ${snapshot.size} total conversations\n`);
  
  // Group conversations by participant signature
  const conversationGroups = new Map();
  
  snapshot.docs.forEach(doc => {
    const data = doc.data();
    const participantIds = data.participantIds || [];
    
    // Create signature: sorted participant IDs joined
    const signature = [...participantIds].sort().join('|');
    
    if (!conversationGroups.has(signature)) {
      conversationGroups.set(signature, []);
    }
    
    conversationGroups.get(signature).push({
      id: doc.id,
      data: data,
      createdAt: data.createdAt?.toDate() || new Date(0)
    });
  });
  
  // Find groups with duplicates
  const duplicates = [];
  const kept = [];
  let duplicateCount = 0;
  
  conversationGroups.forEach((group, signature) => {
    if (group.length > 1) {
      // Sort by createdAt (oldest first)
      group.sort((a, b) => a.createdAt - b.createdAt);
      
      const keepConversation = group[0];
      const deleteConversations = group.slice(1);
      
      duplicateCount += deleteConversations.length;
      
      console.log(`📦 Found ${group.length} conversations with participants: ${signature.split('|').join(', ')}`);
      console.log(`   ✓ KEEP: ${keepConversation.id} (created ${keepConversation.createdAt.toISOString()})`);
      
      deleteConversations.forEach(conv => {
        console.log(`   ✗ DELETE: ${conv.id} (created ${conv.createdAt.toISOString()})`);
        duplicates.push(conv.id);
      });
      
      kept.push(keepConversation.id);
      console.log('');
    }
  });
  
  if (duplicateCount === 0) {
    console.log('✅ No duplicate conversations found! Database is clean.\n');
  } else {
    console.log(`\n📊 Summary:`);
    console.log(`   Total conversation groups: ${conversationGroups.size}`);
    console.log(`   Groups with duplicates: ${Array.from(conversationGroups.values()).filter(g => g.length > 1).length}`);
    console.log(`   Conversations to keep: ${kept.length}`);
    console.log(`   Duplicate conversations to delete: ${duplicateCount}\n`);
  }
  
  return { duplicates, kept };
}

async function deleteDuplicates(duplicateIds) {
  if (duplicateIds.length === 0) {
    return;
  }
  
  console.log(`🗑️  Deleting ${duplicateIds.length} duplicate conversations...\n`);
  
  const batch = db.batch();
  let batchCount = 0;
  let totalDeleted = 0;
  
  for (const conversationId of duplicateIds) {
    // Delete conversation document
    const conversationRef = db.collection('conversations').doc(conversationId);
    batch.delete(conversationRef);
    batchCount++;
    
    // Also delete associated messages (clean up orphaned data)
    const messagesSnapshot = await db.collection('messages')
      .where('conversationId', '==', conversationId)
      .get();
    
    messagesSnapshot.docs.forEach(doc => {
      batch.delete(doc.ref);
      batchCount++;
    });
    
    console.log(`   ✗ Deleted: ${conversationId} (and ${messagesSnapshot.size} messages)`);
    
    // Firestore batch limit is 500 operations
    if (batchCount >= 400) {
      await batch.commit();
      totalDeleted += batchCount;
      batchCount = 0;
      console.log(`   💾 Batch committed (${totalDeleted} operations so far)...`);
    }
  }
  
  // Commit remaining operations
  if (batchCount > 0) {
    await batch.commit();
    totalDeleted += batchCount;
  }
  
  console.log(`\n✅ Successfully deleted ${duplicateIds.length} duplicate conversations and their messages!`);
  console.log(`   Total Firestore operations: ${totalDeleted}\n`);
}

async function main() {
  try {
    const { duplicates, kept } = await findDuplicateConversations();
    
    if (duplicates.length === 0) {
      process.exit(0);
    }
    
    if (isDryRun) {
      console.log(`📋 DRY RUN COMPLETE - No data was deleted`);
      console.log(`   Run without --dry-run to actually delete duplicates\n`);
    } else {
      await deleteDuplicates(duplicates);
    }
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error during cleanup:', error);
    process.exit(1);
  }
}

main();

