#!/bin/bash
# Test entire epic's features (MEDIUM: 20-30 seconds)
# Usage: ./scripts/test-epic.sh <epic-number>
#
# Examples:
#   ./scripts/test-epic.sh 1    # Epic 1: Foundation & Core Messaging
#   ./scripts/test-epic.sh 2    # Epic 2: Complete MVP with Reliability

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

EPIC_NUM="${1:-2}"  # Default to Epic 2 (current)
SIMULATOR_NAME="iPhone 17 Pro"

echo -e "${BLUE}🎯 Running Epic $EPIC_NUM Tests${NC}"
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

# Define test suites for each epic
case $EPIC_NUM in
    1)
        echo -e "${BLUE}Epic 1: Foundation & Core Messaging${NC}"
        TESTS=(
            "Domain"
            "Presentation/ViewModels/Auth"
            "Presentation/ViewModels/Conversations"
            "Presentation/ViewModels/Messages"
        )
        ;;
    2)
        echo -e "${BLUE}Epic 2: Complete MVP with Reliability${NC}"
        TESTS=(
            "Presentation/ViewModels/NewConversationViewModelTests"
            "Presentation/ViewModels/ConversationsListViewModelTests"
            "Data/Repositories/FirebaseConversationRepositoryTests"
            "Data/Repositories/FirebaseUserRepositoryTests"
        )
        ;;
    *)
        echo -e "${RED}❌ Unknown epic number: $EPIC_NUM${NC}"
        echo "Available epics: 1, 2"
        exit 1
        ;;
esac

# Build test args for multiple test suites
TEST_ARGS=""
for test in "${TESTS[@]}"; do
    TEST_ARGS="$TEST_ARGS -only-testing:MessageAITests/$test"
done

# Run epic tests
xcodebuild test \
    -scheme MessageAI \
    -destination "id=$SIMULATOR_ID" \
    $TEST_ARGS \
    -skip-testing:MessageAITests/Integration \
    -parallel-testing-enabled NO \
    2>&1 | grep -E "(Test Suite|Test Case.*passed|Test Case.*failed|Executed [0-9]+ test)" | tail -100

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ Epic $EPIC_NUM tests passed!${NC}"
    echo -e "${YELLOW}💡 Next: Run full suite with ./scripts/quick-test.sh${NC}"
    exit 0
else
    echo ""
    echo -e "${RED}❌ Epic $EPIC_NUM tests failed${NC}"
    exit 1
fi

