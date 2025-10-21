#!/usr/bin/env node

/**
 * List all files in Firebase Storage
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

const storage = admin.storage();

async function listAllFiles() {
  console.log('📂 Listing all files in Firebase Storage...\n');
  
  try {
    const bucket = storage.bucket();
    const [files] = await bucket.getFiles();
    
    if (files.length === 0) {
      console.log('⚠️  No files found in Storage!');
      console.log('\nThis means either:');
      console.log('1. Profile images are not being uploaded');
      console.log('2. Uploads are failing silently');
      console.log('3. Wrong Storage bucket is being used\n');
      return;
    }
    
    console.log(`✅ Found ${files.length} files:\n`);
    
    for (const file of files) {
      const [metadata] = await file.getMetadata();
      console.log(`📄 ${file.name}`);
      console.log(`   Size: ${(metadata.size / 1024).toFixed(2)} KB`);
      console.log(`   Updated: ${metadata.updated}`);
      console.log(`   Public URL: https://storage.googleapis.com/${bucket.name}/${file.name}`);
      console.log('');
    }
    
  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    process.exit(0);
  }
}

listAllFiles();

