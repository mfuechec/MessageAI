#!/bin/bash
# Test entire epic's features (MEDIUM: 20-30 seconds)
# Usage: ./scripts/test-epic.sh <epic-number> [--verbose|-v]
#
# Examples:
#   ./scripts/test-epic.sh 1    # Epic 1: Foundation & Core Messaging
#   ./scripts/test-epic.sh 2    # Epic 2: Complete MVP with Reliability
#   ./scripts/test-epic.sh 2 -v # With full output

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Parse arguments
EPIC_NUM="${1:-2}"
VERBOSE=false
SHOW_ERRORS=true

shift || true  # Shift past epic number
while [[ $# -gt 0 ]]; do
    case $1 in
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --quiet|-q)
            SHOW_ERRORS=false
            shift
            ;;
        *)
            shift
            ;;
    esac
done

SIMULATOR_NAME="iPhone 17 Pro"

# Setup logging
LOG_DIR=".cursor/.agent-tools/test-logs"
mkdir -p "$LOG_DIR"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOG_FILE="$LOG_DIR/epic-${EPIC_NUM}-${TIMESTAMP}.log"

echo -e "${BLUE}🎯 Running Epic $EPIC_NUM Tests${NC}"
if [ "$VERBOSE" = false ]; then
    echo -e "${BLUE}💾 Log file: $LOG_FILE${NC}"
fi
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
        # Epic 1 Stories: Auth, Profile, Conversations List, Chat, Offline, Tests
        TESTS=(
            "UserTests"
            "MessageTests"
            "ConversationTests"
            "AuthViewModelTests"
            "ProfileSetupViewModelTests"
            "ConversationsListViewModelTests"
            "ChatViewModelTests"
        )
        ;;
    2)
        echo -e "${BLUE}Epic 2: Complete MVP with Reliability${NC}"
        # Epic 2 Stories: 2.0 (Start New Conversation), 2.1 (Group Chat)
        TESTS=(
            "NewConversationViewModelTests"
            "ChatViewModelTests"
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

# Run epic tests with appropriate output
if [ "$VERBOSE" = true ]; then
    # Show everything
    xcodebuild test \
        -scheme MessageAI \
        -destination "id=$SIMULATOR_ID" \
        $TEST_ARGS \
        -skip-testing:MessageAITests/Integration \
        -parallel-testing-enabled NO 2>&1 | tee "$LOG_FILE"
    TEST_RESULT=${PIPESTATUS[0]}
else
    # Filtered output + save to log
    xcodebuild test \
        -scheme MessageAI \
        -destination "id=$SIMULATOR_ID" \
        $TEST_ARGS \
        -skip-testing:MessageAITests/Integration \
        -parallel-testing-enabled NO 2>&1 | tee "$LOG_FILE" | \
        grep -E "(Test Suite|Test Case.*passed|Test Case.*failed|Executed [0-9]+ test)" | tail -100
    TEST_RESULT=${PIPESTATUS[0]}
fi

echo ""

# Handle results
if [ $TEST_RESULT -eq 0 ]; then
    echo -e "${GREEN}✅ Epic $EPIC_NUM tests passed!${NC}"
    echo -e "${YELLOW}💡 Next: Run full suite with ./scripts/quick-test.sh${NC}"
    exit 0
else
    echo -e "${RED}❌ Epic $EPIC_NUM tests failed${NC}"
    
    if [ "$SHOW_ERRORS" = true ]; then
        echo ""
        echo -e "${YELLOW}🔍 Error Details:${NC}"
        echo "─────────────────────────────────────────"
        
        if grep -q "Test Case.*failed" "$LOG_FILE"; then
            echo -e "${RED}Failed tests:${NC}"
            grep "Test Case.*failed" "$LOG_FILE" | tail -20
            echo ""
        fi
        
        if grep -q "\.swift:[0-9]*:[0-9]*: error:" "$LOG_FILE"; then
            echo -e "${RED}Compilation errors:${NC}"
            grep "\.swift:[0-9]*:[0-9]*: error:" "$LOG_FILE" | head -15
            echo ""
        fi
        
        echo "─────────────────────────────────────────"
        echo -e "${BLUE}💾 Full log: $LOG_FILE${NC}"
        echo -e "${YELLOW}💡 Run with --verbose for complete output${NC}"
    fi
    
    exit 1
fi

