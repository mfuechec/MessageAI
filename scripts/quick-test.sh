#!/bin/bash

# Quick Test Script for MessageAI
# Keeps simulator running and uses cached builds when possible

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIMULATOR_NAME="iPhone 17 Pro"
SCHEME="MessageAI"

# Get simulator ID
SIMULATOR_ID=$(xcrun simctl list devices | grep "$SIMULATOR_NAME" | grep -v "Max" | head -1 | sed -E 's/.*\(([A-F0-9-]+)\).*/\1/')

if [ -z "$SIMULATOR_ID" ]; then
    echo -e "${RED}❌ Could not find simulator: $SIMULATOR_NAME${NC}"
    exit 1
fi

echo -e "${BLUE}ℹ️  Using simulator: $SIMULATOR_NAME ($SIMULATOR_ID)${NC}"

# Check if simulator is booted
SIMULATOR_STATE=$(xcrun simctl list devices | grep "$SIMULATOR_ID" | grep -o "([^)]*)" | tail -1 | tr -d '()')

if [ "$SIMULATOR_STATE" != "Booted" ]; then
    echo -e "${YELLOW}⚡ Booting simulator...${NC}"
    xcrun simctl boot "$SIMULATOR_ID" 2>/dev/null || true
    sleep 3
    echo -e "${GREEN}✅ Simulator booted${NC}"
else
    echo -e "${GREEN}✅ Simulator already booted${NC}"
fi

# Parse command line arguments
BUILD_ONLY=false
TEST_ONLY=false
SPECIFIC_TEST=""
QUICK=false
SKIP_INTEGRATION=true  # Skip integration tests by default (require emulator)

while [[ $# -gt 0 ]]; do
    case $1 in
        --build-only)
            BUILD_ONLY=true
            shift
            ;;
        --test-only)
            TEST_ONLY=true
            shift
            ;;
        --test)
            SPECIFIC_TEST="$2"
            shift 2
            ;;
        --quick|-q)
            QUICK=true
            shift
            ;;
        --with-integration)
            SKIP_INTEGRATION=false
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --build-only          Only build, don't run tests"
            echo "  --test-only           Only run tests (assumes already built)"
            echo "  --test <name>         Run specific test (e.g., ConversationsListViewModelTests)"
            echo "  --quick, -q           Skip build, run tests immediately"
            echo "  --with-integration    Include integration tests (requires emulator)"
            echo "  --help, -h            Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                                    # Build and run unit tests only"
            echo "  $0 --quick                            # Run unit tests without building"
            echo "  $0 --with-integration                 # Run ALL tests (needs emulator)"
            echo "  $0 --test ConversationsListViewModelTests  # Run specific test suite"
            echo ""
            echo "Note: Integration tests require Firebase Emulator to be running."
            echo "      Start it with: ./scripts/start-emulator.sh"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# If --quick flag, skip to testing
if [ "$QUICK" = true ]; then
    TEST_ONLY=true
fi

# Build phase
if [ "$TEST_ONLY" = false ]; then
    echo -e "${BLUE}ℹ️  Building for testing...${NC}"
    
    xcodebuild build-for-testing \
        -scheme "$SCHEME" \
        -destination "id=$SIMULATOR_ID" \
        -parallel-testing-enabled NO \
        -quiet 2>&1 | grep -E "(error:|warning:|BUILD)" || true
    
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        echo -e "${GREEN}✅ Build succeeded${NC}"
    else
        echo -e "${RED}❌ Build failed${NC}"
        exit 1
    fi
fi

# Test phase
if [ "$BUILD_ONLY" = false ]; then
    echo -e "${BLUE}ℹ️  Running tests...${NC}"
    
    TEST_ARGS=""
    if [ -n "$SPECIFIC_TEST" ]; then
        echo -e "${BLUE}ℹ️  Running specific test: $SPECIFIC_TEST${NC}"
        TEST_ARGS="-only-testing:MessageAITests/$SPECIFIC_TEST"
    elif [ "$SKIP_INTEGRATION" = true ]; then
        echo -e "${YELLOW}ℹ️  Skipping integration tests (use --with-integration to include)${NC}"
        TEST_ARGS="-skip-testing:MessageAITests/Integration"
    fi
    
    xcodebuild test-without-building \
        -scheme "$SCHEME" \
        -destination "id=$SIMULATOR_ID" \
        -parallel-testing-enabled NO \
        -maximum-concurrent-test-simulator-destinations 1 \
        $TEST_ARGS \
        2>&1 | grep -E "(Test Suite|Test Case.*passed|Test Case.*failed|Testing started|passed.*failed|Executed [0-9]+ test)" | tail -100
    
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        echo ""
        echo -e "${GREEN}✅ All tests passed!${NC}"
    else
        echo ""
        echo -e "${RED}❌ Some tests failed${NC}"
        exit 1
    fi
fi

echo ""
echo -e "${GREEN}✅ Done!${NC}"
echo -e "${YELLOW}💡 Tip: Keep simulator running between test runs for faster execution${NC}"
echo -e "${YELLOW}💡 Use --quick flag to skip rebuilding: $0 --quick${NC}"

