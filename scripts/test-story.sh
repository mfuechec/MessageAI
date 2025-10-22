#!/bin/bash
# Test specific story implementation (FAST: 5-10 seconds)
# Usage: ./scripts/test-story.sh <story-test-name> [--verbose|-v] [--quiet|-q]
#
# Examples:
#   ./scripts/test-story.sh NewConversationViewModelTests
#   ./scripts/test-story.sh ConversationsListViewModelTests --verbose
#   ./scripts/test-story.sh MessageTests -v

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Parse arguments
TEST_NAME=""
VERBOSE=false
SHOW_ERRORS=true

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
            TEST_NAME="$1"
            shift
            ;;
    esac
done

if [ -z "$TEST_NAME" ]; then
    echo -e "${RED}❌ Error: Test name required${NC}"
    echo ""
    echo "Usage: $0 <test-name> [--verbose|-v] [--quiet|-q]"
    echo ""
    echo "Examples:"
    echo "  $0 NewConversationViewModelTests"
    echo "  $0 ConversationsListViewModelTests --verbose"
    echo "  $0 MessageTests -v"
    echo ""
    echo "Flags:"
    echo "  --verbose, -v    Show full xcodebuild output"
    echo "  --quiet, -q      Don't show error details on failure"
    echo ""
    echo "💡 Tip: Test names are case-sensitive and should match the XCTest class name"
    exit 1
fi

SIMULATOR_NAME="iPhone 17 Pro"

# Setup logging
LOG_DIR=".cursor/.agent-tools/test-logs"
mkdir -p "$LOG_DIR"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOG_FILE="$LOG_DIR/${TEST_NAME}-${TIMESTAMP}.log"

echo -e "${BLUE}📝 Running Story Tests: $TEST_NAME${NC}"
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

# Run tests with appropriate output
if [ "$VERBOSE" = true ]; then
    # Show everything
    xcodebuild test \
        -scheme MessageAI \
        -destination "id=$SIMULATOR_ID" \
        -only-testing:MessageAITests/$TEST_NAME \
        -parallel-testing-enabled NO 2>&1 | tee "$LOG_FILE"
    TEST_RESULT=${PIPESTATUS[0]}
else
    # Filtered output + save to log
    xcodebuild test \
        -scheme MessageAI \
        -destination "id=$SIMULATOR_ID" \
        -only-testing:MessageAITests/$TEST_NAME \
        -parallel-testing-enabled NO 2>&1 | tee "$LOG_FILE" | \
        grep -E "(Test Suite|Test Case.*passed|Test Case.*failed|Executed [0-9]+ test)" | tail -50
    TEST_RESULT=${PIPESTATUS[0]}
fi

echo ""

# Handle results
if [ $TEST_RESULT -eq 0 ]; then
    echo -e "${GREEN}✅ Story tests passed!${NC}"
    echo -e "${YELLOW}💡 Next: Run epic tests with ./scripts/test-epic.sh <epic-number>${NC}"
    exit 0
else
    echo -e "${RED}❌ Story tests failed${NC}"
    
    if [ "$SHOW_ERRORS" = true ]; then
        echo ""
        echo -e "${YELLOW}🔍 Error Details:${NC}"
        echo "─────────────────────────────────────────"
        
        # Smart error detection
        if grep -q "Cannot find" "$LOG_FILE"; then
            echo -e "${RED}Missing symbols:${NC}"
            grep "Cannot find" "$LOG_FILE" | head -10
            echo ""
        fi
        
        if grep -q "does not conform to protocol" "$LOG_FILE"; then
            echo -e "${RED}Protocol conformance issues:${NC}"
            grep -B 1 "does not conform to protocol" "$LOG_FILE" | head -10
            echo ""
        fi
        
        if grep -q "\.swift:[0-9]*:[0-9]*: error:" "$LOG_FILE"; then
            echo -e "${RED}Compilation errors:${NC}"
            grep "\.swift:[0-9]*:[0-9]*: error:" "$LOG_FILE" | head -15
            echo ""
        fi
        
        if grep -q "Test Case.*failed" "$LOG_FILE"; then
            echo -e "${RED}Failed tests:${NC}"
            grep "Test Case.*failed" "$LOG_FILE" | tail -10
            echo ""
        fi
        
        echo "─────────────────────────────────────────"
        echo -e "${BLUE}💾 Full log: $LOG_FILE${NC}"
        echo -e "${YELLOW}💡 Run with --verbose for complete output${NC}"
    fi
    
    exit 1
fi

