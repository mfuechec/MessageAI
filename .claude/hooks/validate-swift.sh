#!/bin/bash
#
# validate-swift.sh
# Pre-write/edit hook for Swift files - enforces Clean Architecture rules
#
# Usage: ./validate-swift.sh <file_path> <content>
#

FILE_PATH="$1"
CONTENT="$2"

# Exit codes:
# 0 = success (allow operation)
# 1 = warning (allow with message)
# 2 = block operation (show error to Claude)

# Helper function to check if string contains pattern
contains() {
    local string="$1"
    local pattern="$2"
    echo "$string" | grep -q "$pattern"
}

# ============================================================
# SwiftLint Validation (if installed)
# ============================================================
if command -v swiftlint &> /dev/null; then
    # Only run SwiftLint for existing files (not new files being written)
    if [ -f "$FILE_PATH" ]; then
        # Create temporary file with new content
        TEMP_FILE=$(mktemp "${FILE_PATH}.XXXXX")
        echo "$CONTENT" > "$TEMP_FILE"

        # Run SwiftLint on temporary file
        SWIFTLINT_OUTPUT=$(swiftlint lint "$TEMP_FILE" --quiet 2>&1)
        SWIFTLINT_EXIT_CODE=$?

        # Clean up temp file
        rm -f "$TEMP_FILE"

        # Check if SwiftLint found errors (not warnings)
        if [ $SWIFTLINT_EXIT_CODE -ne 0 ]; then
            echo "⚠️  SwiftLint found issues:" >&2
            echo "$SWIFTLINT_OUTPUT" >&2
            echo "" >&2
            echo "Run 'swiftlint lint $FILE_PATH' for details" >&2
            # Allow but warn (exit 1) - SwiftLint issues are not blockers
            # Architectural violations below will be blockers
        fi
    fi
fi

# ============================================================
# Rule 1: NO Firebase imports in Domain layer
# ============================================================
if echo "$FILE_PATH" | grep -q "MessageAI/Domain/"; then
    if contains "$CONTENT" "import Firebase"; then
        echo "❌ BLOCKED: Firebase imports are FORBIDDEN in Domain layer" >&2
        echo "" >&2
        echo "Domain layer must be pure Swift with ZERO external dependencies." >&2
        echo "" >&2
        echo "Fix: Remove 'import FirebaseFirestore', 'import FirebaseAuth', etc." >&2
        echo "     Use Swift Date instead of Firestore Timestamp" >&2
        echo "     Use String instead of DocumentReference" >&2
        echo "" >&2
        echo "See: CLAUDE.md - 'Domain Layer = Pure Swift Only'" >&2
        exit 2
    fi

    if contains "$CONTENT" "import UIKit"; then
        echo "❌ BLOCKED: UIKit imports are FORBIDDEN in Domain layer" >&2
        echo "" >&2
        echo "Domain layer must be framework-independent." >&2
        echo "Use Foundation types only (String, Date, etc.)" >&2
        exit 2
    fi

    if contains "$CONTENT" "import SwiftUI"; then
        echo "❌ BLOCKED: SwiftUI imports are FORBIDDEN in Domain layer" >&2
        echo "" >&2
        echo "Domain layer must be framework-independent." >&2
        echo "SwiftUI belongs in Presentation layer only." >&2
        exit 2
    fi
fi

# ============================================================
# Rule 2: ViewModels MUST use @MainActor
# ============================================================
if echo "$FILE_PATH" | grep -q "Presentation/ViewModels/.*ViewModel.swift$"; then
    if contains "$CONTENT" "ObservableObject" && ! contains "$CONTENT" "@MainActor"; then
        echo "⚠️  WARNING: ViewModel should use @MainActor for Swift 6 concurrency safety" >&2
        echo "" >&2
        echo "Add @MainActor to the class:" >&2
        echo "  @MainActor" >&2
        echo "  class YourViewModel: ObservableObject {" >&2
        echo "" >&2
        echo "See: CLAUDE.md - 'ViewModels Must Use @MainActor'" >&2
        # Allow but warn (exit 1)
        exit 1
    fi
fi

# ============================================================
# Rule 3: NO force unwrapping in production code
# ============================================================
if ! echo "$FILE_PATH" | grep -q "Tests/"; then
    # Count force unwraps (allow a few for guard/precondition patterns)
    force_unwrap_count=$(echo "$CONTENT" | grep -o "!" | wc -l | tr -d ' ')

    if [ "$force_unwrap_count" -gt 5 ]; then
        echo "⚠️  WARNING: High number of force unwraps detected ($force_unwrap_count occurrences)" >&2
        echo "" >&2
        echo "Force unwrapping (!) is discouraged in production code." >&2
        echo "Use optional binding instead:" >&2
        echo "  ✅ if let value = optional { }" >&2
        echo "  ✅ guard let value = optional else { return }" >&2
        echo "  ❌ let value = optional!" >&2
        echo "" >&2
        echo "See: CLAUDE.md - 'NO force unwrapping (!)'" >&2
        # Allow but warn
        exit 1
    fi
fi

# ============================================================
# Rule 4: NO direct Firebase usage in Presentation layer
# ============================================================
if echo "$FILE_PATH" | grep -q "Presentation/"; then
    if contains "$CONTENT" "Firestore.firestore()"; then
        echo "❌ BLOCKED: Direct Firestore usage in Presentation layer" >&2
        echo "" >&2
        echo "ViewModels must use repository protocols, NOT Firebase directly." >&2
        echo "" >&2
        echo "Fix: Inject repository via initializer:" >&2
        echo "  class YourViewModel {" >&2
        echo "    private let repository: MessageRepositoryProtocol" >&2
        echo "    init(repository: MessageRepositoryProtocol) { ... }" >&2
        echo "  }" >&2
        echo "" >&2
        echo "See: CLAUDE.md - 'Repository Abstraction is MANDATORY'" >&2
        exit 2
    fi
fi

# ============================================================
# Rule 5: Repositories must be in correct layer
# ============================================================
if echo "$FILE_PATH" | grep -q "Repository.swift$"; then
    # Protocol definitions must be in Domain/Repositories
    if contains "$CONTENT" "protocol.*Repository.*Protocol" && ! echo "$FILE_PATH" | grep -q "Domain/Repositories/"; then
        echo "❌ BLOCKED: Repository protocols must be in Domain/Repositories/" >&2
        echo "" >&2
        echo "Current path: $FILE_PATH" >&2
        echo "Expected: MessageAI/Domain/Repositories/YourRepositoryProtocol.swift" >&2
        exit 2
    fi

    # Firebase implementations must be in Data/Repositories
    if contains "$CONTENT" "class.*Firebase.*Repository" && ! echo "$FILE_PATH" | grep -q "Data/Repositories/"; then
        echo "❌ BLOCKED: Firebase repository implementations must be in Data/Repositories/" >&2
        echo "" >&2
        echo "Current path: $FILE_PATH" >&2
        echo "Expected: MessageAI/Data/Repositories/FirebaseYourRepository.swift" >&2
        exit 2
    fi
fi

# ============================================================
# Rule 6: Entities must be in Domain/Entities
# ============================================================
if contains "$CONTENT" "struct.*: Codable" && \
   ! echo "$FILE_PATH" | grep -q "Domain/Entities/" && \
   ! echo "$FILE_PATH" | grep -q "Tests/" && \
   ! contains "$CONTENT" "FirestoreMapper"; then

    # Check if this looks like a domain entity (User, Message, Conversation, etc.)
    if contains "$CONTENT" "struct User" || \
       contains "$CONTENT" "struct Message" || \
       contains "$CONTENT" "struct Conversation"; then
        echo "⚠️  WARNING: Domain entities should be in Domain/Entities/" >&2
        echo "" >&2
        echo "Current path: $FILE_PATH" >&2
        echo "Expected: MessageAI/Domain/Entities/YourEntity.swift" >&2
        # Allow but warn
        exit 1
    fi
fi

# ============================================================
# Rule 7: Check for async/await (not completion handlers)
# ============================================================
if contains "$CONTENT" "completion: @escaping" && \
   ! echo "$FILE_PATH" | grep -q "Tests/"; then
    echo "⚠️  WARNING: Consider using async/await instead of completion handlers" >&2
    echo "" >&2
    echo "Modern Swift uses async/await:" >&2
    echo "  ✅ func sendMessage() async throws" >&2
    echo "  ❌ func sendMessage(completion: @escaping (Result<Void, Error>) -> Void)" >&2
    echo "" >&2
    echo "See: CLAUDE.md - 'Use async/await (NO completion handlers)'" >&2
    # Allow but warn
    exit 1
fi

# ============================================================
# All checks passed
# ============================================================
exit 0
