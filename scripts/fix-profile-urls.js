#!/usr/bin/env node

/**
 * Fix Profile Image URLs
 * 
 * Finds uploaded profile images in Storage and updates Firestore with the correct URLs
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

async function fixProfileURLs() {
  console.log('🔧 Fixing profile image URLs...\n');
  
  try {
    // Get all users
    const usersSnapshot = await db.collection('users').get();
    
    if (usersSnapshot.empty) {
      console.log('❌ No users found in Firestore');
      return;
    }
    
    console.log(`✅ Found ${usersSnapshot.size} users\n`);
    
    let fixed = 0;
    let notFound = 0;
    let alreadySet = 0;
    
    for (const doc of usersSnapshot.docs) {
      const user = doc.data();
      const userId = doc.id;
      
      // Skip if URL already set
      if (user.profileImageURL) {
        alreadySet++;
        continue;
      }
      
      // Check if file exists in Storage
      const storagePath = `profile-images/${userId}/profile.jpg`;
      try {
        const bucket = storage.bucket();
        const file = bucket.file(storagePath);
        const [exists] = await file.exists();
        
        if (exists) {
          // Make file public and get download URL
          await file.makePublic();
          
          const publicUrl = `https://storage.googleapis.com/${bucket.name}/${storagePath}`;
          
          // Update Firestore
          await db.collection('users').doc(userId).update({
            profileImageURL: publicUrl
          });
          
          console.log(`✅ Fixed ${user.displayName || user.email}: ${publicUrl}`);
          fixed++;
        } else {
          notFound++;
        }
      } catch (error) {
        notFound++;
      }
    }
    
    console.log(`\n────────────────────────────────────────`);
    console.log(`✅ Fixed: ${fixed} users`);
    console.log(`ℹ️  Already set: ${alreadySet} users`);
    console.log(`ℹ️  No image found: ${notFound} users`);
    console.log(`────────────────────────────────────────\n`);
    
  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    process.exit(0);
  }
}

fixProfileURLs();

