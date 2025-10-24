#!/bin/bash

# Quick test to verify embedMessageOnCreate trigger is working
# Tests by sending a message from the iOS app and checking if it gets embedded

echo "========================================="
echo "Testing embedMessageOnCreate Trigger"
echo "========================================="
echo ""
echo "Instructions:"
echo "1. Open the MessageAI app on the simulator"
echo "2. Send a test message in any conversation"
echo "3. Wait 5 seconds"
echo "4. This script will check if the message has an embedding"
echo ""
read -p "Press Enter after you've sent a message..."

echo ""
echo "Checking most recent messages for embeddings..."
echo ""

# Use Firebase CLI to query recent messages
firebase firestore:get messages \
  --project messageai-dev-1f2ec \
  --order-by timestamp desc \
  --limit 5 \
  --format json | \
  jq -r '.[] |
    if .embedding then
      "✅ \(.id) - HAS EMBEDDING (\(.embedding | length) dimensions)"
    else
      "❌ \(.id) - NO EMBEDDING - Text: \(.text[:50])..."
    end'

echo ""
echo "========================================="
echo "Note: The trigger runs asynchronously"
echo "New messages get embeddings within 1-5 seconds"
echo "========================================="
