#!/bin/bash
# CI-compatible test runner
# Can run with or without Firebase Emulator

set -e

echo "🧪 Running MessageAI Test Suite"
echo ""

# Check if Firebase Emulator is available
EMULATOR_AVAILABLE=false
if curl -s http://localhost:8080 > /dev/null 2>&1; then
    EMULATOR_AVAILABLE=true
    echo "✅ Firebase Emulator detected - will run all tests"
else
    echo "⚠️  Firebase Emulator not running - skipping integration tests"
    echo "   To run integration tests, start emulator:"
    echo "   ./scripts/start-emulator.sh"
fi
echo ""

# Run unit tests (always)
echo "📦 Running Unit Tests..."
xcodebuild test \
    -scheme MessageAI \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    -skip-testing:MessageAITests/Integration \
    -skip-testing:MessageAITests/Performance \
    -parallel-testing-enabled NO \
    -enableCodeCoverage YES \
    | xcbeautify

UNIT_EXIT_CODE=$?

if [ $UNIT_EXIT_CODE -ne 0 ]; then
    echo "❌ Unit tests failed"
    exit $UNIT_EXIT_CODE
fi

echo "✅ Unit tests passed"

# Run integration tests if emulator available
if [ "$EMULATOR_AVAILABLE" = true ]; then
    echo ""
    echo "🔗 Running Integration Tests..."
    xcodebuild test \
        -scheme MessageAI \
        -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
        -only-testing:MessageAITests/Integration \
        -parallel-testing-enabled NO \
        | xcbeautify
    
    INTEGRATION_EXIT_CODE=$?
    
    if [ $INTEGRATION_EXIT_CODE -ne 0 ]; then
        echo "❌ Integration tests failed"
        exit $INTEGRATION_EXIT_CODE
    fi
    
    echo "✅ Integration tests passed"
fi

echo ""
echo "🎉 All tests passed!"

