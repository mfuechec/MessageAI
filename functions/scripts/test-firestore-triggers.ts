#!/usr/bin/env ts-node

/**
 * Test Script: Verify Firestore Triggers
 *
 * Creates a test message and verifies embedMessageOnCreate trigger runs
 *
 * Usage:
 *   cd functions
 *   npx ts-node scripts/test-firestore-triggers.ts
 */

import * as admin from "firebase-admin";

// Initialize Firebase Admin
const serviceAccount = require("../serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: "messageai-dev-1f2ec"
});

const db = admin.firestore();

async function testEmbedMessageOnCreate() {
  console.log("\n========================================");
  console.log("Testing embedMessageOnCreate Trigger");
  console.log("========================================\n");

  // Step 1: Create a test message
  console.log("Step 1: Creating test message...");

  const testMessageRef = db.collection("messages").doc();
  const testMessage = {
    conversationId: "test-conversation-123",
    senderId: "test-user-456",
    senderName: "Test User",
    text: "This is a test message to verify the embedMessageOnCreate trigger is working correctly.",
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    status: "sent",
    isEdited: false,
    isDeleted: false,
    readBy: []
  };

  await testMessageRef.set(testMessage);
  console.log(`✅ Created test message: ${testMessageRef.id}`);

  // Step 2: Wait for trigger to run (should take 1-5 seconds)
  console.log("\nStep 2: Waiting for embedMessageOnCreate trigger to run...");
  console.log("(This should take 1-5 seconds)");

  for (let i = 0; i < 15; i++) {
    await sleep(2000); // Wait 2 seconds

    const messageDoc = await testMessageRef.get();
    const messageData = messageDoc.data();

    if (messageData?.embedding) {
      console.log(`\n✅ SUCCESS! Embedding generated after ${(i + 1) * 2} seconds`);
      console.log(`   - Embedding dimensions: ${messageData.embedding.length}`);
      console.log(`   - Embedded at: ${messageData.embeddedAt?.toDate().toISOString()}`);
      console.log(`   - First 5 values: [${messageData.embedding.slice(0, 5).map((v: number) => v.toFixed(4)).join(", ")}...]`);

      // Clean up
      console.log("\nStep 3: Cleaning up test message...");
      await testMessageRef.delete();
      console.log("✅ Test message deleted");

      return true;
    }

    process.stdout.write(".");
  }

  console.log("\n\n❌ FAILED: Trigger did not run within 30 seconds");
  console.log("   The message was created but no embedding was added.");
  console.log("\nPossible issues:");
  console.log("   1. Trigger not deployed properly");
  console.log("   2. OpenAI API key not configured");
  console.log("   3. Trigger encountering errors (check Cloud Functions logs)");

  // Clean up
  await testMessageRef.delete();

  return false;
}

async function checkExistingMessages() {
  console.log("\n========================================");
  console.log("Checking Recent Messages for Embeddings");
  console.log("========================================\n");

  const recentMessages = await db.collection("messages")
    .orderBy("timestamp", "desc")
    .limit(10)
    .get();

  if (recentMessages.empty) {
    console.log("No messages found in database");
    return;
  }

  console.log(`Found ${recentMessages.size} recent messages:\n`);

  let embeddedCount = 0;
  let notEmbeddedCount = 0;

  recentMessages.forEach((doc) => {
    const data = doc.data();
    const hasEmbedding = !!data.embedding;

    if (hasEmbedding) {
      embeddedCount++;
    } else {
      notEmbeddedCount++;
    }

    const status = hasEmbedding ? "✅ HAS EMBEDDING" : "❌ NO EMBEDDING";
    const timestamp = data.timestamp?.toDate().toISOString() || "No timestamp";
    const text = data.text?.substring(0, 50) || "No text";

    console.log(`${status} | ${timestamp} | ${text}...`);
  });

  console.log(`\nSummary:`);
  console.log(`  - Messages with embeddings: ${embeddedCount}`);
  console.log(`  - Messages without embeddings: ${notEmbeddedCount}`);
  console.log(`  - Success rate: ${(embeddedCount / recentMessages.size * 100).toFixed(1)}%`);

  if (notEmbeddedCount > 0 && embeddedCount === 0) {
    console.log("\n⚠️  WARNING: No recent messages have embeddings!");
    console.log("   This suggests the trigger is not running.");
  } else if (notEmbeddedCount > 0) {
    console.log("\n⚠️  Some messages are missing embeddings.");
    console.log("   These may be old messages created before the trigger was deployed.");
  }
}

function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function main() {
  try {
    // First check existing messages
    await checkExistingMessages();

    // Then test trigger with new message
    const success = await testEmbedMessageOnCreate();

    console.log("\n========================================");
    console.log(success ? "✅ ALL TESTS PASSED" : "❌ TESTS FAILED");
    console.log("========================================\n");

    process.exit(success ? 0 : 1);
  } catch (error) {
    console.error("\n❌ Error running tests:", error);
    process.exit(1);
  }
}

main();
