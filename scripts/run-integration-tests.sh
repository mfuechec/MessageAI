#!/bin/bash
# Run integration tests against Firebase Emulator

set -e

# Check if emulator is running
if ! curl -s http://localhost:8080 > /dev/null; then
    echo "❌ Firebase Emulator not running!"
    echo "Start it first: ./scripts/start-emulator.sh"
    exit 1
fi

echo "✅ Firebase Emulator detected"
echo "🧪 Running integration tests..."

xcodebuild test \
    -scheme MessageAI \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    -only-testing:MessageAITests/Integration \
    -parallel-testing-enabled NO \
    | xcbeautify || true

