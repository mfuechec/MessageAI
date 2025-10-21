#!/bin/bash
# Test specific story implementation (FAST: 5-10 seconds)
# Usage: ./scripts/test-story.sh <story-test-name>
#
# Examples:
#   ./scripts/test-story.sh NewConversationViewModelTests
#   ./scripts/test-story.sh ConversationsListViewModelTests

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ -z "$1" ]; then
    echo -e "${RED}❌ Error: Test name required${NC}"
    echo ""
    echo "Usage: $0 <test-name>"
    echo ""
    echo "Examples:"
    echo "  $0 NewConversationViewModelTests"
    echo "  $0 ConversationsListViewModelTests"
    echo "  $0 MessageTests"
    echo ""
    echo "💡 Tip: Test names are case-sensitive and should match the XCTest class name"
    exit 1
fi

TEST_NAME="$1"
SIMULATOR_NAME="iPhone 17 Pro"

echo -e "${BLUE}📝 Running Story Tests: $TEST_NAME${NC}"
echo ""

# Get simulator ID
SIMULATOR_ID=$(xcrun simctl list devices | grep "$SIMULATOR_NAME" | grep -v "Max" | head -1 | sed -E 's/.*\(([A-F0-9-]+)\).*/\1/')

if [ -z "$SIMULATOR_ID" ]; then
    echo -e "${RED}❌ Could not find simulator: $SIMULATOR_NAME${NC}"
    exit 1
fi

# Boot simulator if needed
SIMULATOR_STATE=$(xcrun simctl list devices | grep "$SIMULATOR_ID" | grep -o "([^)]*)" | tail -1 | tr -d '()')
if [ "$SIMULATOR_STATE" != "Booted" ]; then
    echo -e "${YELLOW}⚡ Booting simulator...${NC}"
    xcrun simctl boot "$SIMULATOR_ID" 2>/dev/null || true
    sleep 2
fi

# Run specific test suite
xcodebuild test \
    -scheme MessageAI \
    -destination "id=$SIMULATOR_ID" \
    -only-testing:MessageAITests/$TEST_NAME \
    -parallel-testing-enabled NO \
    2>&1 | grep -E "(Test Suite|Test Case.*passed|Test Case.*failed|Executed [0-9]+ test)" | tail -50

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ Story tests passed!${NC}"
    echo -e "${YELLOW}💡 Next: Run epic tests with ./scripts/test-epic.sh <epic-name>${NC}"
    exit 0
else
    echo ""
    echo -e "${RED}❌ Story tests failed${NC}"
    exit 1
fi

