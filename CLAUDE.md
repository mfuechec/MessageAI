# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MessageAI is an iOS messaging application built with **Clean Architecture + MVVM**, featuring real-time messaging with Firebase backend and AI-powered intelligence. The app follows strict architectural boundaries with 70%+ test coverage requirements.

## Essential Commands

### Building

```bash
# Build project (recommended method)
./scripts/build.sh

# Build for Release
./scripts/build.sh --config Release

# Clean build
./scripts/build.sh --action clean

# Xcode build
open MessageAI.xcodeproj
# Press Cmd+B to build, Cmd+R to build and run
```

### Testing

```bash
# Quick unit tests (5-10 seconds) - USE THIS FOR FAST ITERATION
./scripts/quick-test.sh -q

# First-time run (builds + runs all tests)
./scripts/quick-test.sh

# Run specific test class
./scripts/quick-test.sh -q --test ChatViewModelTests

# Complete test suite with coverage
xcodebuild test -scheme MessageAI \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    -enableCodeCoverage YES
```

**IMPORTANT**: Always use `./scripts/quick-test.sh -q` for fast terminal testing. It's 10x faster than raw xcodebuild.

### Integration Tests (Requires Firebase Emulator)

```bash
# Terminal 1: Start Firebase emulator
./scripts/start-emulator.sh

# Terminal 2: Run integration tests
./scripts/run-integration-tests.sh

# Stop emulator when done
./scripts/stop-emulator.sh
```

### Firebase Deployment

```bash
# Deploy Firestore security rules to dev environment
firebase deploy --only firestore:rules --project messageai-dev-1f2ec

# Deploy to production
firebase deploy --only firestore:rules --project messageai-prod-4d3a8
```

## Architecture Fundamentals

### Clean Architecture Layers

The codebase is structured in **strict layers** with **inward-pointing dependencies**:

```
Presentation → Domain ← Data
     ↓
   Domain (Protocols)
     ↑
   Data (Implementations)
```

**Layer Structure:**
```
MessageAI/
├── App/                    # Application entry, DI container, Firebase config
├── Domain/                 # Pure Swift - NO external dependencies
│   ├── Entities/           # Business models (User, Message, Conversation)
│   └── Repositories/       # Protocol definitions ONLY
├── Data/                   # Firebase implementations
│   ├── Repositories/       # FirebaseAuthRepository, FirebaseMessageRepository, etc.
│   ├── Network/            # FirebaseService wrapper
│   └── Models/             # Firestore ↔ Entity mappers
└── Presentation/           # SwiftUI + ViewModels
    ├── ViewModels/         # @MainActor ObservableObjects with @Published state
    ├── Views/              # SwiftUI views
    └── Components/         # Reusable UI components
```

### Critical Architectural Rules

**1. Repository Abstraction is MANDATORY**

ViewModels MUST depend on protocols, NEVER concrete implementations:

```swift
✅ CORRECT:
class ChatViewModel {
    private let messageRepository: MessageRepositoryProtocol
    init(messageRepository: MessageRepositoryProtocol) { ... }
}

❌ WRONG:
import FirebaseFirestore
class ChatViewModel {
    private let db = Firestore.firestore()  // NEVER
}
```

**2. Domain Layer = Pure Swift Only**

NO Firebase, UIKit, or SwiftUI imports in Domain layer:

```swift
✅ CORRECT (Domain/Entities/Message.swift):
import Foundation  // Only Foundation allowed
struct Message: Codable {
    let timestamp: Date  // Swift Date
}

❌ WRONG:
import FirebaseFirestore
struct Message {
    let timestamp: Timestamp  // Firebase type
}
```

**3. Dependency Injection via Initializer**

All dependencies must be injected through initializers, managed by `DIContainer`:

```swift
✅ CORRECT:
class ChatViewModel {
    init(messageRepository: MessageRepositoryProtocol,
         userRepository: UserRepositoryProtocol) { ... }
}

❌ WRONG:
class ChatViewModel {
    private let repo = FirebaseMessageRepository()  // Hard-coded
}
```

**4. ViewModels Must Use @MainActor**

All ViewModels MUST be marked `@MainActor` for Swift 6 concurrency safety:

```swift
✅ CORRECT:
@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
}

❌ WRONG:
class ChatViewModel: ObservableObject {
    // Missing @MainActor - data race risk
}
```

**5. Optimistic UI Updates for Messaging**

Messages must appear immediately, then save in background:

```swift
✅ CORRECT:
func sendMessage(_ text: String) async {
    let message = Message(/* ... */, status: .sending)
    messages.append(message)  // Optimistic UI - show immediately
    try await messageRepository.sendMessage(message)
}

❌ WRONG:
func sendMessage(_ text: String) async {
    try await messageRepository.sendMessage(message)  // User waits
    messages.append(message)
}
```

### Dependency Injection Container

`DIContainer.swift` manages all dependency wiring. Use factory methods to create ViewModels:

```swift
// App entry point
let authViewModel = DIContainer.shared.makeAuthViewModel()

// Creating ChatViewModel
let chatViewModel = DIContainer.shared.makeChatViewModel(
    conversationId: id,
    currentUserId: userId
)
```

**Never instantiate ViewModels directly** - always use `DIContainer` factory methods.

### Key Entities

**User** (`Domain/Entities/User.swift`):
- `id: String` - Firebase Auth UID
- `email: String`
- `displayName: String`
- `isOnline: Bool`
- `lastSeen: Date`

**Message** (`Domain/Entities/Message.swift`):
- `id: String` - UUID
- `conversationId: String` - Parent conversation
- `senderId: String` - User who sent message
- `text: String`
- `timestamp: Date`
- `status: MessageStatus` - `.sending`, `.sent`, `.delivered`, `.read`
- `isEdited: Bool`
- `isDeleted: Bool`
- `editHistory: [MessageEdit]?` - History of edits
- `readBy: [String]` - User IDs who read this message

**Conversation** (`Domain/Entities/Conversation.swift`):
- `id: String` - UUID
- `participantIds: [String]` - User IDs in conversation
- `isGroup: Bool` - true if > 2 participants
- `groupName: String?` - Optional group name
- `lastMessageText: String?`
- `lastMessageTimestamp: Date?`
- `unreadCounts: [String: Int]` - Unread count per user

### Repository Protocols

All data access goes through repository protocols in `Domain/Repositories/`:

- `MessageRepositoryProtocol` - Message CRUD, real-time observers
- `ConversationRepositoryProtocol` - Conversation management
- `UserRepositoryProtocol` - User profiles, presence
- `AuthRepositoryProtocol` - Authentication flows
- `StorageRepositoryProtocol` - File uploads (profile images, attachments)

Implementations are in `Data/Repositories/` (e.g., `FirebaseMessageRepository`).

## Firebase Configuration

### Environment Setup

The app uses **two Firebase projects**:
- **Development**: `messageai-dev-1f2ec` (DEBUG builds)
- **Production**: `messageai-prod-4d3a8` (RELEASE builds)

Configuration files (gitignored):
- `MessageAI/Resources/GoogleService-Info-Dev.plist`
- `MessageAI/Resources/GoogleService-Info-Prod.plist`

Environment is auto-selected based on build configuration in `FirebaseService.swift`.

### Firestore Collections

**users/** - User profiles
- Indexed on `isOnline` for presence queries
- Contains `fcmToken` for push notifications

**conversations/** - Conversation metadata
- Indexed on `participantIds` (array-contains) for user's conversations
- Real-time listeners for unread counts

**messages/** - Message documents
- Composite index on `conversationId` + `timestamp` (ascending)
- Real-time listeners for live message updates
- Soft-delete pattern with `isDeleted: Bool`

### Security Rules

Firestore rules enforce strict access control (`firestore.rules`):
- Users can only read/write their own user document
- Conversation access restricted to participants
- Messages require conversation participant membership
- Read receipts allow participants to mark messages as read

## Coding Standards

### Naming Conventions

- **Types**: PascalCase (`MessageRepository`, `ChatViewModel`, `User`)
- **Functions/Variables**: camelCase (`sendMessage`, `isOnline`, `conversationId`)
- **Protocols**: Suffix with `Protocol` (`MessageRepositoryProtocol`)
- **Constants**: camelCase (NOT SCREAMING_CASE) (`maxParticipants`, `defaultTimeout`)

### Modern Swift Requirements

**Use async/await (NO completion handlers):**
```swift
✅ func sendMessage(_ message: Message) async throws
❌ func sendMessage(_ message: Message, completion: @escaping (Result<Void, Error>) -> Void)
```

**Use guard for early returns:**
```swift
✅ guard let message = message else { return }
❌ if let message = message { /* nested code */ }
```

**Prefer struct over class** (unless inheritance needed):
```swift
✅ struct Message: Codable { }
❌ class Message: Codable { }  // Without good reason
```

**NO force unwrapping (!)** except in tests:
```swift
✅ if let user = currentUser { }
✅ guard let user = currentUser else { return }
❌ let user = currentUser!  // FORBIDDEN
```

### Code Quality Limits

- **Function length**: MAX 50 lines (extract helpers if longer)
- **Cyclomatic complexity**: MAX 10
- **Line length**: 120 characters max
- **View body**: Extract components if > 30 lines

### Error Handling

**NEVER silent failures** - always provide user feedback:

```swift
✅ CORRECT:
do {
    messages = try await repository.getMessages(id)
} catch {
    errorMessage = "Failed to load messages: \(error.localizedDescription)"
}

❌ WRONG:
do {
    messages = try await repository.getMessages(id)
} catch {
    // Silent failure - user sees nothing
}
```

## Testing Requirements

### Test Coverage Targets

- **Domain Layer**: 80%+ coverage
- **Data Layer**: 70%+ coverage
- **Presentation Layer**: 75%+ coverage
- **Overall**: 70%+ minimum

### Test File Organization

```
MessageAITests/
├── Domain/Entities/         # Entity model tests
├── Data/
│   ├── Mocks/               # Mock repositories (MockMessageRepository, etc.)
│   └── Repositories/        # Firebase repository tests
├── Presentation/ViewModels/ # ViewModel unit tests
├── Integration/             # End-to-end integration tests (requires emulator)
└── Performance/             # Performance baseline tests
```

### Test Patterns

**Unit tests use mock repositories:**
```swift
class ChatViewModelTests: XCTestCase {
    var mockMessageRepo: MockMessageRepository!
    var viewModel: ChatViewModel!

    override func setUp() {
        mockMessageRepo = MockMessageRepository()
        viewModel = ChatViewModel(messageRepository: mockMessageRepo)
    }
}
```

**Integration tests use Firebase Emulator:**
```swift
class RealTimeMessagingIntegrationTests: XCTestCase {
    // Tests against local Firebase Emulator
    // Requires ./scripts/start-emulator.sh running
}
```

### Performance Baselines

Established on iPhone 17 Pro Simulator:
- Message send: < 2 seconds
- Conversation load (50 messages): < 1 second
- Authentication: < 2 seconds

## Common Development Workflows

### Adding a New Feature

1. **Start with Domain layer** - Define entities and repository protocols
2. **Write tests first** - Create test file before implementation
3. **Implement Data layer** - Firebase repository implementation
4. **Create ViewModel** - Add to Presentation/ViewModels with @MainActor
5. **Add factory method** - Update DIContainer with factory method
6. **Build SwiftUI view** - Use ViewModel via @StateObject/@ObservedObject
7. **Run tests** - `./scripts/quick-test.sh -q`
8. **Check coverage** - Xcode: Product → Test → Show Code Coverage

### Modifying Entities

When changing Domain entities (User, Message, Conversation):

1. Update entity in `Domain/Entities/`
2. Update Firestore mapper in `Data/Models/FirestoreMappers.swift`
3. Update all affected ViewModels
4. Update corresponding entity tests
5. Consider Firestore migration if schema changes
6. Run full test suite: `./scripts/quick-test.sh`

### Testing Message Features

For features involving real-time messaging:

1. Write unit tests with `MockMessageRepository`
2. Test optimistic UI updates (message appears immediately)
3. Test error handling (network failures)
4. Test offline behavior (Firestore persistence)
5. Run integration tests with emulator for real-time scenarios

### Working with Push Notifications

Push notification flow:
1. AppDelegate registers for APNs and FCM (Story 2.10)
2. FCM token saved to Firestore `users/{userId}/fcmToken`
3. Cloud Functions send notifications when new messages arrive
4. Foreground notifications suppressed if user viewing conversation
5. Notification taps trigger deep link to conversation

Debug with `NotificationSimulator.swift` in DEBUG builds.

## Tech Stack

- **Language**: Swift 5.9+
- **UI**: SwiftUI (iOS 15+)
- **Architecture**: Clean Architecture + MVVM
- **Backend**: Firebase (Firestore, Auth, Cloud Functions, FCM, Storage)
- **State Management**: Combine + @Published
- **Testing**: XCTest
- **Dependency Manager**: Swift Package Manager

## Important Files to Know

- `MessageAI/App/DIContainer.swift` - All dependency wiring
- `MessageAI/App/MessageAIApp.swift` - App entry point, Firebase setup, AppDelegate
- `MessageAI/Data/Network/FirebaseService.swift` - Firebase initialization
- `firestore.rules` - Firestore security rules
- `scripts/quick-test.sh` - Fast testing script
- `docs/architecture/` - Detailed architecture documentation
- `docs/stories/` - Story-by-story implementation details

## Firebase Emulator Notes

Integration tests require Firebase Emulator:
- Emulator UI: http://localhost:4000
- Firestore: localhost:8080
- Auth: localhost:9099
- Storage: localhost:9199

Data is ephemeral - cleared on emulator restart. Perfect for isolated testing.

## Performance Considerations

- **Optimistic UI**: Messages appear instantly, save in background
- **Offline-first**: Firestore offline persistence enabled by default
- **Real-time listeners**: Use Combine publishers, auto-cleanup with `cancellables`
- **Image caching**: Not yet implemented (planned for future stories)
- **Pagination**: Load messages in batches (planned for optimization)

## Firestore Standards

### Critical Firestore Rules

**1. ALWAYS Use Server Timestamps**

Use `FieldValue.serverTimestamp()`, NEVER client-side `Date()`:

```swift
✅ CORRECT:
try await db.collection("messages").document(id).setData([
    "timestamp": FieldValue.serverTimestamp(),  // Server time
    "text": message.text
])

❌ WRONG:
try await db.collection("messages").document(id).setData([
    "timestamp": Date(),  // Client time - causes clock skew issues
    "text": message.text
])
```

**Why**: Prevents clock skew issues across devices. Server time is always consistent.

**2. Use Batch Writes for Multiple Operations**

Batch writes are atomic (all succeed or all fail):

```swift
✅ CORRECT:
let batch = db.batch()

let messageRef = db.collection("messages").document()
batch.setData(messageData, forDocument: messageRef)

let conversationRef = db.collection("conversations").document(conversationId)
batch.updateData(["lastMessage": text], forDocument: conversationRef)

try await batch.commit()  // Single network round-trip

❌ WRONG:
try await db.collection("messages").document().setData(messageData)
try await db.collection("conversations").document(conversationId).updateData(["lastMessage": text])
// Sequential writes - can fail halfway through
```

**3. ALWAYS Use Query Limits**

```swift
✅ CORRECT:
let query = db.collection("messages")
    .whereField("conversationId", isEqualTo: conversationId)
    .order(by: "timestamp", descending: true)
    .limit(to: 50)  // ALWAYS limit

❌ WRONG:
let query = db.collection("messages")
    .whereField("conversationId", isEqualTo: conversationId)
    .order(by: "timestamp", descending: true)
    // No limit - could load 10,000+ messages
```

**Why**: Cost optimization (Firestore charges per document read). Performance optimization.

**4. Security Rules Must Match Swift Logic**

If Swift code allows an action, Firestore security rules must allow it too:

```swift
// Swift Code
guard message.senderId == currentUserId else {
    throw MessageError.unauthorized
}
try await db.collection("messages").document(id).updateData(...)

// Corresponding Firestore Security Rule (firestore.rules)
match /messages/{messageId} {
  allow update: if request.auth.uid == resource.data.senderId;
}
```

**5. Handle Offline Mode Explicitly**

```swift
do {
    try await messageRepository.sendMessage(message)
} catch let error as NSError where error.domain == FirestoreErrorDomain {
    if error.code == FirestoreErrorCode.unavailable.rawValue {
        // Offline - show queued state
        message.status = .queued
    }
}
```

### Query Optimization

**Composite Indexes**

Complex queries require composite indexes defined in `firestore.indexes.json`:

```swift
// Query requiring composite index
db.collection("messages")
    .whereField("conversationId", isEqualTo: id)
    .whereField("isPriority", isEqualTo: true)
    .order(by: "timestamp", descending: true)
```

Deploy indexes before running queries:
```bash
firebase deploy --only firestore:indexes
```

**Pagination Pattern**

```swift
var lastDocument: DocumentSnapshot?

func loadMoreMessages() async throws {
    var query = db.collection("messages")
        .whereField("conversationId", isEqualTo: conversationId)
        .order(by: "timestamp", descending: true)
        .limit(to: 50)

    if let lastDoc = lastDocument {
        query = query.start(afterDocument: lastDoc)
    }

    let snapshot = try await query.getDocuments()
    lastDocument = snapshot.documents.last
}
```

**Smart Caching with Snapshot Listeners**

```swift
✅ CORRECT (use snapshot listeners for real-time):
db.collection("messages")
    .whereField("conversationId", isEqualTo: id)
    .addSnapshotListener { snapshot, error in
        snapshot?.documentChanges.forEach { change in
            switch change.type {
            case .added: // Handle new message
            case .modified: // Handle edited message
            case .removed: // Handle deleted message
            }
        }
    }

❌ WRONG (expensive polling):
Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
    let messages = try await getMessages()  // Re-fetches ALL messages
}
```

### Collection Structure Best Practices

**Use Flat Collections** (not deep nesting):

```
✅ CORRECT:
messages/{messageId}
conversations/{conversationId}
users/{userId}

❌ WRONG:
conversations/{conversationId}/messages/{messageId}
// Deep nesting limits query capabilities
```

**Denormalize for Performance**:

```swift
// Store lastMessage in conversation for fast list display
struct Conversation {
    let lastMessage: String?          // Denormalized
    let lastMessageTimestamp: Date?   // Denormalized
}
```

Accept some data duplication for speed - avoids loading all messages just to show conversation preview.

## Cloud Functions Standards

### Critical Cloud Functions Rules

**1. ALWAYS Validate Authentication**

Every Cloud Function MUST check authentication:

```typescript
✅ CORRECT:
export const summarizeThread = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError(
            'unauthenticated',
            'User must be authenticated'
        );
    }

    const userId = context.auth.uid;

    // Validate user has access to conversation
    const conversation = await db.collection('conversations').doc(data.conversationId).get();
    const participantIds = conversation.data()?.participantIds || [];

    if (!participantIds.includes(userId)) {
        throw new functions.https.HttpsError(
            'permission-denied',
            'User not a participant in conversation'
        );
    }
});

❌ WRONG:
export const summarizeThread = functions.https.onCall(async (data, context) => {
    // No authentication check - SECURITY HOLE
    const conversationId = data.conversationId;
});
```

**2. Validate All Input Parameters**

```typescript
✅ CORRECT:
if (!data.conversationId || typeof data.conversationId !== 'string') {
    throw new functions.https.HttpsError(
        'invalid-argument',
        'conversationId must be a non-empty string'
    );
}

if (data.messageIds && !Array.isArray(data.messageIds)) {
    throw new functions.https.HttpsError(
        'invalid-argument',
        'messageIds must be an array'
    );
}
```

**3. Check AI Cache Before Calling LLM**

```typescript
✅ CORRECT:
const cacheKey = `summary_${conversationId}_${latestMessageId}`;
const cachedResult = await db.collection('ai_cache').doc(cacheKey).get();

if (cachedResult.exists && !isCacheExpired(cachedResult)) {
    // Cache hit - return immediately (< 1 second)
    return JSON.parse(cachedResult.data()!.result);
}

// Cache miss - call LLM (expensive, 5-10 seconds)
const summary = await generateSummary(messages);

// Store in cache
await db.collection('ai_cache').doc(cacheKey).set({
    result: JSON.stringify(summary),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000) // 24 hours
});
```

**Why**: 70%+ cost savings, < 1s cache hit vs 5-10s LLM call.

**4. Set Timeout Limits**

```typescript
export const summarizeThread = functions
    .runWith({
        timeoutSeconds: 60,  // Max 60 seconds
        memory: '512MB'
    })
    .https.onCall(async (data, context) => {
        // Function will timeout after 60 seconds
    });
```

**5. Catch ALL Errors and Return Structured Responses**

```typescript
export const summarizeThread = functions.https.onCall(async (data, context) => {
    try {
        // Call LLM
        const summary = await openai.chat.completions.create(/* ... */);

        return {
            success: true,
            summary: summary.choices[0].message.content,
            timestamp: new Date().toISOString()
        };

    } catch (error) {
        console.error('Error in summarizeThread:', error);

        // OpenAI rate limit
        if (error.status === 429) {
            throw new functions.https.HttpsError(
                'resource-exhausted',
                'AI service rate limit exceeded. Please try again later.'
            );
        }

        // Generic error
        throw new functions.https.HttpsError(
            'internal',
            'Failed to generate summary'
        );
    }
});
```

### Idempotency & Rate Limiting

**Make Functions Safe to Retry**:

```typescript
const requestId = data.requestId;  // Client generates unique ID

// Check if already processed
const existing = await db.collection('action_items')
    .where('requestId', '==', requestId)
    .get();

if (!existing.empty) {
    return existing.docs[0].data();  // Already processed
}
```

**Implement Per-User Rate Limits**:

```typescript
const userId = context.auth!.uid;
const rateLimit = await db.collection('rate_limits').doc(userId).get();
const today = new Date().toISOString().split('T')[0];

if (rateLimit.exists) {
    const data = rateLimit.data()!;
    if (data.date === today && data.count >= 100) {
        throw new functions.https.HttpsError(
            'resource-exhausted',
            'Daily AI request limit exceeded (100 requests per day)'
        );
    }
}

// Increment counter
await db.collection('rate_limits').doc(userId).set({
    date: today,
    count: admin.firestore.FieldValue.increment(1)
}, { merge: true });
```

### OpenAI Integration

**Proper LLM Prompt Structure**:

```typescript
const completion = await openai.chat.completions.create({
    model: "gpt-4-turbo",
    messages: [
        {
            role: "system",
            content: "You are an AI assistant that summarizes team conversations."
        },
        {
            role: "user",
            content: `Summarize this conversation:\n\n${messagesText}`
        }
    ],
    temperature: 0.3,  // Lower = more deterministic
    max_tokens: 500
});
```

**Use Function Calling for Structured Output**:

```typescript
const completion = await openai.chat.completions.create({
    model: "gpt-4-turbo",
    messages: [/* ... */],
    tools: [{
        type: "function",
        function: {
            name: "extract_action_items",
            description: "Extract action items from conversation",
            parameters: {
                type: "object",
                properties: {
                    actionItems: {
                        type: "array",
                        items: {
                            type: "object",
                            properties: {
                                task: { type: "string" },
                                assignee: { type: "string" },
                                dueDate: { type: "string" }
                            }
                        }
                    }
                }
            }
        }
    }],
    tool_choice: { type: "function", function: { name: "extract_action_items" } }
});

// Guaranteed structured output
const args = JSON.parse(completion.choices[0].message.tool_calls[0].function.arguments);
```

### Environment Variables

**Store API Keys Securely**:

```bash
# Set in Firebase
firebase functions:config:set openai.api_key="sk-..." --project=messageai-dev

# Access in function
const openaiApiKey = functions.config().openai.api_key;
```

**NEVER hardcode API keys in source code.**

### Deployment

```bash
# Deploy all functions
firebase deploy --only functions

# Deploy single function
firebase deploy --only functions:summarizeThread

# Test locally with emulator
firebase emulators:start --only functions,firestore
```

## What NOT to Do

❌ Import Firebase SDK in Domain layer
❌ Hard-code dependencies in ViewModels
❌ Use completion handlers instead of async/await
❌ Force unwrap optionals (!) in production code
❌ Skip writing tests for new features
❌ Create ViewModels without @MainActor
❌ Modify entities without updating Firestore mappers
❌ Silent error handling (empty catch blocks)
❌ Instantiate ViewModels directly (use DIContainer)
❌ Use client-side timestamps (always use FieldValue.serverTimestamp())
❌ Skip query limits on Firestore queries
❌ Deploy Cloud Functions without authentication checks
❌ Call LLM APIs without checking cache first
❌ Use deep collection nesting in Firestore
❌ Poll Firestore - use snapshot listeners instead

## Story-Driven Development

This project follows a **story-driven approach** with detailed acceptance criteria in `docs/stories/`. Each story includes:
- Requirements and acceptance criteria
- Architecture diagrams
- Test coverage requirements
- Performance targets

Current progress tracked in git commits. See README.md for completed stories.
