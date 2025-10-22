# MessageAI Testing Strategy

**Date:** 2025-10-22
**Coverage Targets:** Domain 80%+, Data 70%+, Presentation 75%+, Overall 70%+

## Tiered Testing Approach

### Tier 1: Story-Level Tests (5-20 seconds)
**Use during development** - Fast iteration on current feature

```bash
./scripts/test-story.sh ChatViewModelTests
```

- Runs ONLY tests for the current story's component
- Single simulator reuse (no parallel testing overhead)
- Perfect for TDD workflow: write test → implement → run → repeat

**When to use:** After implementing each task/subtask

### Tier 2: Epic-Level Tests (20-40 seconds)
**Use before marking story complete** - Verify no epic regressions

```bash
./scripts/test-epic.sh 2
```

- Runs all tests for the current epic (e.g., Epic 2 = messaging features)
- Verifies your changes didn't break related features
- Required before setting story status to "Ready for Review"

**When to use:** After completing all story tasks, before marking Done

### Tier 3: Full Suite (1-2 minutes)
**Use before committing** - Full regression check

```bash
./scripts/quick-test.sh
```

- Runs ALL unit tests across entire codebase
- Catches unexpected cross-feature regressions
- Required before git commit

**When to use:** Before every commit

## Test Organization

```
MessageAITests/
├── Domain/Entities/           # Entity model tests (90%+ coverage)
├── Data/
│   ├── Mocks/                 # Mock repositories (critical!)
│   │   ├── MockMessageRepository.swift
│   │   ├── MockUserRepository.swift
│   │   └── MockConversationRepository.swift
│   └── Repositories/          # Integration tests (requires emulator)
├── Presentation/ViewModels/   # ViewModel unit tests (80%+ coverage)
└── Performance/               # Baseline performance tests
```

## Mock Repository Pattern

**Standard structure for all mocks:**

```swift
class MockMessageRepository: MessageRepositoryProtocol {
    // 1️⃣ Tracking booleans
    var sendMessageCalled = false
    var markMessagesAsReadCalled = false

    // 2️⃣ Configurable return values
    var mockMessages: [Message] = []
    var mockError: Error?
    var shouldFail = false

    // 3️⃣ Captured parameters (for verification)
    var capturedMessage: Message?
    var capturedMessageIds: [String]?
    var capturedUserId: String?

    // 4️⃣ Protocol implementation
    func sendMessage(_ message: Message) async throws {
        sendMessageCalled = true
        capturedMessage = message

        if shouldFail {
            throw mockError ?? RepositoryError.networkError(NSError())
        }

        mockMessages.append(message)
    }

    func markMessagesAsRead(messageIds: [String], userId: String) async throws {
        markMessagesAsReadCalled = true
        capturedMessageIds = messageIds
        capturedUserId = userId

        if shouldFail {
            throw mockError ?? RepositoryError.networkError(NSError())
        }

        // Update mock data
        for messageId in messageIds {
            if let index = mockMessages.firstIndex(where: { $0.id == messageId }) {
                mockMessages[index].readBy.append(userId)
                mockMessages[index].readCount += 1
            }
        }
    }

    // 5️⃣ Reset method (called in tearDown)
    func reset() {
        sendMessageCalled = false
        markMessagesAsReadCalled = false
        mockMessages = []
        mockError = nil
        shouldFail = false
        capturedMessage = nil
        capturedMessageIds = nil
        capturedUserId = nil
    }
}
```

## Test Naming Convention

```swift
// Pattern: test{What}_{Scenario}_{ExpectedOutcome}

func testMarkMessagesAsRead_FiltersOwnMessages()
func testMarkMessagesAsRead_AlreadyRead()
func testMarkMessagesAsRead_OptimisticUI()
func testSendMessage_EmptyText_DoesNotSend()
func testSendMessage_ExceedsMaxLength_ShowsError()
```

## Common Test Patterns

### Pattern 1: Testing Optimistic UI
```swift
func testMarkMessagesAsRead_OptimisticUI() async throws {
    // Given: 3 unread messages
    mockMessageRepo.mockMessages = [
        Message(senderId: "other", readBy: []),
        Message(senderId: "other", readBy: []),
        Message(senderId: "other", readBy: [])
    ]

    // When: Mock repository to delay 2 seconds
    mockMessageRepo.shouldDelay = true
    await sut.markMessagesAsRead()

    // Then: Messages updated locally immediately (< 100ms)
    XCTAssertEqual(sut.messages[0].readBy.count, 1)
    XCTAssertTrue(sut.messages[0].readBy.contains("currentUser"))
}
```

### Pattern 2: Testing Filtering Logic
```swift
func testMarkMessagesAsRead_FiltersOwnMessages() async throws {
    // Given: 5 messages (2 from user, 3 from others)
    mockMessageRepo.mockMessages = [
        Message(senderId: "currentUser", readBy: []),
        Message(senderId: "currentUser", readBy: []),
        Message(senderId: "user2", readBy: []),
        Message(senderId: "user3", readBy: []),
        Message(senderId: "user4", readBy: [])
    ]

    // When
    await sut.markMessagesAsRead()

    // Then: Only 3 messages marked (own messages excluded)
    XCTAssertEqual(mockMessageRepo.capturedReadMessageIds?.count, 3)
    XCTAssertTrue(mockMessageRepo.markMessagesAsReadCalled)
}
```

### Pattern 3: Testing Error Handling
```swift
func testSendMessage_Failure_ShowsError() async throws {
    // Given
    mockMessageRepo.shouldFail = true
    mockMessageRepo.mockError = RepositoryError.networkError(NSError())

    // When
    await sut.sendMessage()

    // Then
    XCTAssertNotNil(sut.errorMessage)
    XCTAssertTrue(sut.errorMessage!.contains("network"))
}
```

### Pattern 4: Testing Lifecycle Methods
```swift
func testOnAppear_CallsMarkMessagesAsRead() async throws {
    // Given: ViewModel with unread messages
    sut.messages = [
        Message(senderId: "other", readBy: [])
    ]

    // When
    sut.onAppear()
    try await Task.sleep(nanoseconds: 100_000_000)  // Wait for async Task

    // Then
    XCTAssertTrue(mockMessageRepo.markMessagesAsReadCalled)
}
```

### Pattern 5: Testing Real-Time Updates
```swift
func testObserveMessages_ReceivesUpdates() async throws {
    // Given: Listener set up
    let expectation = XCTestExpectation(description: "Receive update")
    var receivedMessages: [Message] = []

    let cancellable = sut.messageRepository.observeMessages(conversationId: "test")
        .sink { messages in
            receivedMessages = messages
            if !messages.isEmpty {
                expectation.fulfill()
            }
        }

    // When: New message added
    mockMessageRepo.mockMessages.append(newMessage)
    mockMessageRepo.triggerObserver()

    // Then
    await fulfillment(of: [expectation], timeout: 2.0)
    XCTAssertEqual(receivedMessages.count, 1)
    cancellable.cancel()
}
```

## Integration Tests (Firebase Emulator)

**When to write integration tests:**
- Testing Firebase SDK interactions
- Verifying real-time listeners
- Testing security rules
- End-to-end workflows

**Setup:**
```swift
@MainActor
final class SomeIntegrationTests: XCTestCase {
    var firebaseService: FirebaseService!
    var repository: FirebaseMessageRepository!

    override func setUp() async throws {
        try await super.setUp()

        // Skip if emulator not running
        try XCTSkipIf(true, "Requires Firebase Emulator")

        firebaseService = FirebaseService()
        firebaseService.useEmulator()  // ← Critical!
        firebaseService.configure()

        repository = FirebaseMessageRepository(firebaseService: firebaseService)
    }

    override func tearDown() async throws {
        // Clean up test data
        await cleanupTestData()
        repository = nil
        try await super.tearDown()
    }
}
```

## Performance Testing

**Baseline tests run on iPhone 17 Pro Simulator:**

```swift
func testPerformance_MessageSend() async throws {
    let start = Date()

    try await messageRepository.sendMessage(message)

    let duration = Date().timeIntervalSince(start)
    XCTAssertLessThan(duration, 2.0, "Message send should take < 2s")
}
```

**Established baselines:**
- Message send: < 2 seconds
- Conversation load (50 messages): < 1 second
- Authentication: < 2 seconds
- Read receipt propagation: < 1 second

## Coverage Checking

```bash
# In Xcode
Product → Test (Cmd+U)
View → Navigators → Reports → Coverage tab
```

**Coverage targets by layer:**
- Domain Entities: 90%+ (pure Swift, easy to test)
- Presentation ViewModels: 80%+ (business logic)
- Data Repositories: 70%+ (Firebase integration complexity)
- Views: 30-50% (UI tests expensive, focus on critical flows)

## Common Testing Mistakes

❌ **Running full suite during development**
```bash
# Slow (1-2 minutes) - only use before commit
./scripts/quick-test.sh
```

✅ **Use story tests for fast iteration**
```bash
# Fast (5-20 seconds) - use during development
./scripts/test-story.sh ChatViewModelTests
```

---

❌ **Forgetting to reset mocks**
```swift
override func tearDown() {
    // ❌ Forgot to reset - tests will interfere with each other
    sut = nil
}
```

✅ **Always reset in tearDown**
```swift
override func tearDown() {
    mockRepo.reset()  // ✅ Clean state
    sut = nil
}
```

---

❌ **Testing real Firebase in unit tests**
```swift
let repo = FirebaseMessageRepository()  // ❌ Real Firebase!
```

✅ **Use mocks for unit tests**
```swift
let mockRepo = MockMessageRepository()  // ✅ Fast, isolated
```

---

❌ **Not waiting for async operations**
```swift
sut.onAppear()
XCTAssertTrue(mockRepo.markMessagesAsReadCalled)  // ❌ Timing issue
```

✅ **Wait for Task to complete**
```swift
sut.onAppear()
try await Task.sleep(nanoseconds: 100_000_000)  // ✅ Wait
XCTAssertTrue(mockRepo.markMessagesAsReadCalled)
```

## Test-First Development Workflow

**Story 2.5 Example:**

1. **Write test first** (Red)
   ```swift
   func testMarkMessagesAsRead_FiltersOwnMessages() async throws {
       // Test fails - method doesn't exist yet
   }
   ```

2. **Implement minimum code** (Green)
   ```swift
   func markMessagesAsRead() async {
       // Minimal implementation to make test pass
   }
   ```

3. **Run story tests** (5-20s)
   ```bash
   ./scripts/test-story.sh ChatViewModelTests
   ```

4. **Refactor** (Refactor)
   ```swift
   // Improve code quality while keeping tests green
   ```

5. **Before marking complete** - Run epic tests (20-40s)
   ```bash
   ./scripts/test-epic.sh 2
   ```

6. **Before committing** - Run full suite (1-2min)
   ```bash
   ./scripts/quick-test.sh
   ```

## Key Takeaways

1. ✅ **Use tiered testing** - Story → Epic → Full for efficiency
2. ✅ **Mock repositories** - Fast, isolated, deterministic tests
3. ✅ **Test optimistic UI** - Verify updates happen before await
4. ✅ **Reset mocks in tearDown** - Prevent test interference
5. ✅ **Use integration tests sparingly** - Require emulator, slower
6. ✅ **Follow naming convention** - test{What}_{Scenario}_{Outcome}
7. ✅ **Test error paths** - Not just happy paths
8. ✅ **Check coverage** - Aim for 70%+ overall
