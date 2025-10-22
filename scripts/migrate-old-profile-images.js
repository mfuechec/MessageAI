#!/usr/bin/env node

/**
 * Migrate Profile Images from Old Path to New Path
 * 
 * Copies images from users/{userId}/profile.jpg to profile-images/{userId}/profile.jpg
 * and updates Firestore profileImageURL fields
 */

const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin
const serviceAccountPath = path.join(__dirname, '..', 'firebase-admin-key-dev.json');

try {
  const serviceAccount = require(serviceAccountPath);
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    storageBucket: `${serviceAccount.project_id}.firebasestorage.app`
  });
  console.log(`✅ Connected to Firebase project: ${serviceAccount.project_id}`);
  console.log(`📦 Storage bucket: ${serviceAccount.project_id}.firebasestorage.app\n`);
} catch (error) {
  console.error('❌ Firebase Admin SDK credentials not found!');
  process.exit(1);
}

const db = admin.firestore();
const storage = admin.storage();

async function migrateProfileImages() {
  console.log('🔄 Migrating profile images from old path to new path...\n');
  
  try {
    // Get all users with profileImageURL set
    const usersSnapshot = await db.collection('users').get();
    
    if (usersSnapshot.empty) {
      console.log('❌ No users found in Firestore');
      return;
    }
    
    let migrated = 0;
    let skipped = 0;
    let errors = 0;
    
    for (const doc of usersSnapshot.docs) {
      const user = doc.data();
      const userId = doc.id;
      
      // Skip if no profileImageURL
      if (!user.profileImageURL) {
        continue;
      }
      
      // Check if URL contains the old path
      if (!user.profileImageURL.includes('/users/')) {
        console.log(`⏭️  Skipped ${user.displayName || user.email}: Already using new path`);
        skipped++;
        continue;
      }
      
      console.log(`\n📝 Processing ${user.displayName || user.email} (${userId})`);
      console.log(`   Old URL: ${user.profileImageURL.substring(0, 80)}...`);
      
      try {
        const bucket = storage.bucket();
        const oldPath = `users/${userId}/profile.jpg`;
        const newPath = `profile-images/${userId}/profile.jpg`;
        
        const oldFile = bucket.file(oldPath);
        const newFile = bucket.file(newPath);
        
        // Check if old file exists
        const [oldExists] = await oldFile.exists();
        
        if (!oldExists) {
          console.log(`   ⚠️  Old file doesn't exist in storage, but URL is set`);
          console.log(`   💡 Clearing broken URL from Firestore...`);
          
          // Clear the broken URL
          await db.collection('users').doc(userId).update({
            profileImageURL: admin.firestore.FieldValue.delete()
          });
          
          errors++;
          continue;
        }
        
        // Copy file to new location
        console.log(`   📤 Copying from ${oldPath}`);
        console.log(`   📥 Copying to ${newPath}`);
        
        await oldFile.copy(newFile);
        
        // Make new file public
        await newFile.makePublic();
        
        // Get new public URL
        const newPublicUrl = `https://storage.googleapis.com/${bucket.name}/${newPath}`;
        
        // Update Firestore
        await db.collection('users').doc(userId).update({
          profileImageURL: newPublicUrl
        });
        
        console.log(`   ✅ Migrated successfully`);
        console.log(`   🔗 New URL: ${newPublicUrl}`);
        
        // Delete old file (optional - comment out if you want to keep backups)
        // await oldFile.delete();
        // console.log(`   🗑️  Deleted old file`);
        
        migrated++;
        
      } catch (error) {
        console.log(`   ❌ Migration failed: ${error.message}`);
        errors++;
      }
    }
    
    console.log(`\n────────────────────────────────────────`);
    console.log(`✅ Migrated: ${migrated} users`);
    console.log(`⏭️  Skipped: ${skipped} users (already using new path)`);
    console.log(`❌ Errors: ${errors} users`);
    console.log(`────────────────────────────────────────\n`);
    
  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    process.exit(0);
  }
}

migrateProfileImages();

