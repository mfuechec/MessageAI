#!/bin/bash

# MessageAI Build Script
# Simplifies Xcode command-line builds with sensible defaults

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Project configuration
PROJECT_NAME="MessageAI"
SCHEME="MessageAI"
PROJECT_FILE="${PROJECT_NAME}.xcodeproj"

# Default configuration
CONFIGURATION="Debug"
PLATFORM="iOS Simulator"
SIMULATOR_NAME=""
ACTION="build"
SHOW_FULL_OUTPUT=false

# Function to print colored output
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Function to find available simulators
find_simulator() {
    # Try to find iPhone 17 Pro first (project default)
    local preferred_sim=$(xcrun simctl list devices available iPhone | grep "iPhone 17 Pro" | grep -v "Max" | head -1)
    
    if [ -n "$preferred_sim" ]; then
        SIMULATOR_NAME=$(echo "$preferred_sim" | sed -E 's/^[[:space:]]*(.*)[[:space:]]\([A-Z0-9-]+\).*$/\1/' | xargs)
    else
        # Fallback to any available iPhone
        local simulators=$(xcrun simctl list devices available iPhone | grep -E "iPhone [0-9]" | head -1)
        if [ -z "$simulators" ]; then
            print_error "No iPhone simulator found"
            exit 1
        fi
        SIMULATOR_NAME=$(echo "$simulators" | sed -E 's/^[[:space:]]*(.*)[[:space:]]\([A-Z0-9-]+\).*$/\1/' | xargs)
    fi
    
    print_info "Using simulator: $SIMULATOR_NAME"
}

# Function to display usage
usage() {
    cat << EOF
MessageAI Build Script

USAGE:
    ./scripts/build.sh [OPTIONS]

OPTIONS:
    -c, --config [Debug|Release]    Build configuration (default: Debug)
    -s, --simulator NAME            Specific simulator to use
    -a, --action [build|clean]      Action to perform (default: build)
    -f, --full-output              Show full xcodebuild output
    -h, --help                      Show this help message

EXAMPLES:
    # Build for Debug (default)
    ./scripts/build.sh

    # Build for Release
    ./scripts/build.sh --config Release

    # Clean and build
    ./scripts/build.sh --action clean
    ./scripts/build.sh

    # Use specific simulator
    ./scripts/build.sh --simulator "iPhone 15 Pro"

    # Show full output
    ./scripts/build.sh --full-output

ENVIRONMENT:
    Debug builds use Development Firebase configuration
    Release builds use Production Firebase configuration

EOF
}

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--config)
            CONFIGURATION="$2"
            shift 2
            ;;
        -s|--simulator)
            SIMULATOR_NAME="$2"
            shift 2
            ;;
        -a|--action)
            ACTION="$2"
            shift 2
            ;;
        -f|--full-output)
            SHOW_FULL_OUTPUT=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Main build function
main() {
    print_info "MessageAI Build Script"
    print_info "Configuration: $CONFIGURATION"
    print_info "Action: $ACTION"
    
    # Find simulator if not specified
    if [ -z "$SIMULATOR_NAME" ]; then
        find_simulator
    fi
    
    # Construct destination
    DESTINATION="platform=$PLATFORM,name=$SIMULATOR_NAME"
    
    print_info "Destination: $DESTINATION"
    echo ""
    
    # Build command
    BUILD_CMD="xcodebuild -project $PROJECT_FILE -scheme $SCHEME -configuration $CONFIGURATION -destination '$DESTINATION' $ACTION"
    
    if [ "$SHOW_FULL_OUTPUT" = true ]; then
        print_info "Executing: $BUILD_CMD"
        echo ""
        eval $BUILD_CMD
    else
        print_info "Building... (use --full-output to see details)"
        echo ""
        
        # Run build and filter output for readability
        if eval $BUILD_CMD 2>&1 | tee /tmp/xcodebuild.log | grep -E "(error:|warning:|BUILD SUCCEEDED|BUILD FAILED)"; then
            echo ""
            if grep -q "BUILD SUCCEEDED" /tmp/xcodebuild.log; then
                print_success "Build completed successfully!"
                
                # Show warnings count if any
                WARNING_COUNT=$(grep -c "warning:" /tmp/xcodebuild.log || true)
                if [ "$WARNING_COUNT" -gt 0 ]; then
                    print_warning "Build had $WARNING_COUNT warning(s)"
                fi
                
                exit 0
            else
                print_error "Build failed! See errors above."
                print_info "Full log available at: /tmp/xcodebuild.log"
                exit 1
            fi
        fi
    fi
}

# Run main function
main

