#!/usr/bin/env node

/**
 * Check User Profile Images
 * 
 * This script checks if users have profileImageURL fields in Firestore
 * and verifies the URLs are accessible in Firebase Storage.
 */

const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin
const serviceAccountPath = path.join(__dirname, '..', 'firebase-admin-key-dev.json');

try {
  const serviceAccount = require(serviceAccountPath);
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
  console.log(`✅ Connected to Firebase project: ${serviceAccount.project_id}\n`);
} catch (error) {
  console.error('❌ Firebase Admin SDK credentials not found!');
  console.error(`   Looking for: ${serviceAccountPath}`);
  console.error('   Please download your service account key from Firebase Console:');
  console.error('   1. Go to Project Settings → Service Accounts');
  console.error('   2. Click "Generate New Private Key"');
  console.error('   3. Save as: firebase-admin-key-dev.json');
  console.error('   4. Move to project root directory\n');
  process.exit(1);
}

const db = admin.firestore();
const storage = admin.storage();

async function checkUserImages() {
  console.log('🔍 Checking user profile images...\n');
  
  try {
    // Get all users
    const usersSnapshot = await db.collection('users').get();
    
    if (usersSnapshot.empty) {
      console.log('❌ No users found in Firestore');
      return;
    }
    
    console.log(`✅ Found ${usersSnapshot.size} users\n`);
    
    for (const doc of usersSnapshot.docs) {
      const user = doc.data();
      const userId = doc.id;
      
      console.log(`─────────────────────────────────────────`);
      console.log(`👤 User: ${user.displayName || user.email}`);
      console.log(`   ID: ${userId}`);
      console.log(`   Email: ${user.email}`);
      
      // Check if profileImageURL field exists
      if (user.profileImageURL) {
        console.log(`   ✅ profileImageURL: ${user.profileImageURL.substring(0, 80)}...`);
        
        // Check if file exists in Storage
        const storagePath = `users/${userId}/profile.jpg`;
        try {
          const bucket = storage.bucket();
          const file = bucket.file(storagePath);
          const [exists] = await file.exists();
          
          if (exists) {
            const [metadata] = await file.getMetadata();
            console.log(`   ✅ File exists in Storage: ${storagePath}`);
            console.log(`      Size: ${(metadata.size / 1024).toFixed(2)} KB`);
            console.log(`      Updated: ${metadata.updated}`);
          } else {
            console.log(`   ❌ File NOT found in Storage: ${storagePath}`);
          }
        } catch (storageError) {
          console.log(`   ❌ Storage check failed: ${storageError.message}`);
        }
      } else {
        console.log(`   ⚠️  No profileImageURL field in Firestore`);
        
        // Check if file exists in Storage anyway
        const storagePath = `users/${userId}/profile.jpg`;
        try {
          const bucket = storage.bucket();
          const file = bucket.file(storagePath);
          const [exists] = await file.exists();
          
          if (exists) {
            console.log(`   ⚠️  File EXISTS in Storage but URL not in Firestore!`);
            console.log(`      Path: ${storagePath}`);
            
            // Get the download URL
            const [url] = await file.getSignedUrl({
              action: 'read',
              expires: '03-01-2500'
            });
            console.log(`   💡 Storage URL: ${url.substring(0, 80)}...`);
            console.log(`   💡 Run this to fix:`);
            console.log(`      await db.collection('users').doc('${userId}').update({`);
            console.log(`        profileImageURL: '<public-url-from-firebase-console>'`);
            console.log(`      })`);
          } else {
            console.log(`   ℹ️  No file in Storage either`);
          }
        } catch (storageError) {
          console.log(`   ℹ️  No file in Storage`);
        }
      }
      
      console.log('');
    }
    
    console.log(`─────────────────────────────────────────`);
    console.log('\n✅ Check complete!\n');
    
  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    process.exit(0);
  }
}

checkUserImages();

