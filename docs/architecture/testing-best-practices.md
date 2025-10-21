# Testing Best Practices

## Quick Reference

**⚡ We use TIERED TESTING for efficient development:**

```bash
# During story development (5-20 seconds)
./scripts/test-story.sh NewConversationViewModelTests

# Before marking story complete (20-40 seconds)
./scripts/test-epic.sh 2

# Before committing (1-2 minutes)
./scripts/quick-test.sh
```

**📚 See [Testing Strategy Guide](./testing-strategy.md) for complete workflow details.**

**Never run tests with parallel simulators enabled** - it spawns multiple simulator windows and is actually slower!

---

## Why Single-Simulator Testing?

### ❌ Problems with Parallel Testing (Default Xcode Behavior)

- **Spawns multiple simulator clones** - Opens 2-4 simulator windows
- **Slower on most machines** - Resource contention (CPU, RAM, disk I/O)
- **Simulators restart/close** - Constant booting delays
- **Higher resource usage** - Can slow down your entire system
- **More complex debugging** - Which simulator has the issue?

### ✅ Benefits of Single-Simulator Testing

- **10x faster**: One booted simulator reused across test runs
- **Predictable**: Same environment every time
- **Less resource intensive**: Lower CPU/RAM usage
- **Easier debugging**: Single consistent environment
- **Better for CI/CD**: More reliable on limited resources

---

## Testing Tools & When to Use Them

### 1. Quick Test Script (Recommended for Development)

**Use for**: Day-to-day development, quick iteration, regression checks

```bash
# First run (builds and tests)
./scripts/quick-test.sh

# Fast subsequent runs (reuses build)
./scripts/quick-test.sh --quick

# Run specific test suite
./scripts/quick-test.sh -q --test ConversationsListViewModelTests

# Run specific test
./scripts/quick-test.sh -q --test AuthViewModelTests/testSignIn_Success
```

**Features**:
- ⚡ Fast: 5-10 seconds for incremental runs
- 🎯 Focused: Run specific tests easily
- 📊 Clean output: Only shows relevant test results
- 🔄 Reuses simulator: Keeps simulator booted between runs

### 2. Xcode UI Testing (Use for Debugging)

**Use for**: Debugging failing tests, setting breakpoints, stepping through code

```bash
# Run all tests
Cmd+U

# Run single test
Click diamond icon next to test function

# Run test class
Click diamond icon next to test class
```

**Note**: Xcode may spawn multiple simulators by default. This is fine for debugging single tests, but inefficient for full test runs.

### 3. Build Script with Tests (Use for Clean Slate)

**Use for**: Verifying clean builds, checking for subtle issues

```bash
# Clean build + all tests
./scripts/build.sh --action test

# Single simulator enabled by default in build.sh
```

### 4. Manual xcodebuild (Last Resort)

**Only use if scripts are broken or unavailable**

```bash
xcodebuild test \
  -scheme MessageAI \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -parallel-testing-enabled NO \
  -maximum-concurrent-test-simulator-destinations 1
```

---

## Testing Workflow

### During Story Development (FAST - Use Story Tests)

```bash
# 1. Write code
# 2. Write/update tests
# 3. Run STORY tests (5-20 seconds)
./scripts/test-story.sh NewConversationViewModelTests

# 4. Iterate until green ✅
# 5. On failure, debug in Xcode
# Open Xcode, set breakpoints, run specific test (Cmd+U)
```

### Before Marking Story Complete (MEDIUM - Use Epic Tests)

```bash
# Verify you didn't break epic features (20-40 seconds)
./scripts/test-epic.sh 2

# If pass ✅, story is ready for commit
```

### Before Committing (FULL - Use Full Suite)

```bash
# Run ALL unit tests to catch regressions (1-2 minutes)
./scripts/quick-test.sh

# If tests pass, commit
git add .
git commit -m "Story 2.0: Feature with tests"
```

### Continuous Integration (CI)

```yaml
# Example GitHub Actions workflow
- name: Run Tests
  run: |
    ./scripts/quick-test.sh
```

The scripts automatically disable parallel testing, so CI runs are consistent with local development.

---

## Test Creation Guidelines

### When Creating Tests for a Story

**CRITICAL for Tiered Testing:** Each story should have **ONE primary test class** that can be run in isolation.

**Rules:**
1. **One test class per feature/ViewModel**
   - Good: `NewConversationViewModelTests.swift` (tests ONE ViewModel)
   - Bad: Multiple small test files that need to run together

2. **Name tests to match the component**
   - ViewModel: `{ViewModelName}Tests` → `NewConversationViewModelTests`
   - Repository: `{RepositoryName}Tests` → `FirebaseConversationRepositoryTests`
   - Entity: `{EntityName}Tests` → `UserTests`

3. **Organize by architecture layer**
   - Domain: `MessageAITests/Domain/Entities/`
   - Data: `MessageAITests/Data/Repositories/`
   - Presentation: `MessageAITests/Presentation/ViewModels/`

4. **Comprehensive coverage in ONE class**
   - All scenarios for that component in the same test file
   - Enables fast story-level testing: `./scripts/test-story.sh NewConversationViewModelTests`

**Example Story Structure:**
```
Story 2.0: Start New Conversation
│
├── Code:
│   ├── NewConversationViewModel.swift        ← New ViewModel
│   ├── NewConversationView.swift             ← New View
│   └── UserRowView.swift                     ← Helper component
│
└── Tests:
    └── NewConversationViewModelTests.swift   ← ONE test class, 9 tests
        ├── testLoadUsers_Success
        ├── testLoadUsers_Failure
        ├── testSearchFilter_ByName
        ├── testSearchFilter_ByEmail
        ├── testSelectUser_Success
        ├── testSelectUser_Failure
        ├── testSelectUser_PreventsSelf
        ├── testSearchFilter_Empty
        └── testSearchDebounce
        
→ Run: ./scripts/test-story.sh NewConversationViewModelTests (10s)
```

---

## Test Organization

### Test File Structure

```
MessageAITests/
├── Data/
│   ├── Mocks/                          # Mock implementations
│   │   ├── MockAuthRepository.swift
│   │   ├── MockUserRepository.swift
│   │   └── MockConversationRepository.swift
│   └── Repositories/                   # Repository tests
│       └── Firebase*RepositoryTests.swift
│
├── Domain/
│   └── Entities/                       # Entity tests
│       ├── UserTests.swift
│       ├── MessageTests.swift
│       └── ConversationTests.swift
│
└── Presentation/
    └── ViewModels/                     # ViewModel tests
        ├── AuthViewModelTests.swift
        ├── ProfileSetupViewModelTests.swift
        ├── ConversationsListViewModelTests.swift
        └── NewConversationViewModelTests.swift  ← Story 2.0
```

### Test Naming Conventions

```swift
// Test function naming: test{What}_{Scenario}_{ExpectedOutcome}
func testSignIn_ValidCredentials_ReturnsUser()
func testSignIn_InvalidEmail_ThrowsError()
func testFetchMessages_EmptyConversation_ReturnsEmptyArray()

// Test class naming: {What}Tests
class AuthViewModelTests: XCTestCase { }
class NewConversationViewModelTests: XCTestCase { }
class UserRepositoryTests: XCTestCase { }
```

---

## Mock Repository Pattern

**Always follow this pattern for mock repositories:**

```swift
class MockConversationRepository: ConversationRepositoryProtocol {
    // 1. Tracking booleans
    var observeConversationsCalled = false
    var getConversationCalled = false
    
    // 2. Configurable return values
    var mockConversations: [Conversation] = []
    var mockError: Error?
    var shouldFail = false
    
    // 3. Captured parameters (for verification)
    var capturedUserId: String?
    var capturedConversationId: String?
    
    // 4. Protocol implementation
    func observeConversations(userId: String) -> AnyPublisher<[Conversation], Never> {
        observeConversationsCalled = true
        capturedUserId = userId
        return Just(mockConversations).eraseToAnyPublisher()
    }
    
    // 5. Reset method
    func reset() {
        observeConversationsCalled = false
        mockConversations = []
        capturedUserId = nil
    }
}
```

**Why this pattern?**
- ✅ Easy to verify method calls
- ✅ Configurable behavior per test
- ✅ Can simulate both success and failure
- ✅ Captures parameters for assertions
- ✅ Clean state between tests with reset()

---

## Test Speed Guidelines

### Target Test Speeds

- **Unit tests (ViewModels, Entities)**: < 100ms each
- **Repository tests with mocks**: < 200ms each
- **Full test suite**: < 30 seconds total

### If Tests Are Slow

1. **Check for accidental network calls**: Ensure using mocks
2. **Check for large Task.sleep() calls**: Keep delays < 200ms
3. **Check test setup complexity**: Move to setUp() if reusable
4. **Use quick-test.sh**: Much faster than Xcode parallel testing

---

## Common Pitfalls to Avoid

### ❌ DON'T: Use Xcode Parallel Testing for Full Runs

```bash
# This spawns multiple simulators (slow!)
xcodebuild test -scheme MessageAI -destination '...'
```

### ✅ DO: Use Single Simulator

```bash
# Fast, single simulator
./scripts/quick-test.sh -q
```

---

### ❌ DON'T: Commit Without Running Tests

```bash
git commit -m "Fixed bug"  # Without testing!
```

### ✅ DO: Always Test Before Commit

```bash
./scripts/quick-test.sh && git commit -m "Fixed bug"
```

---

### ❌ DON'T: Write Tests That Depend on External Services

```swift
// Bad: Real Firebase call
func testSignIn() {
    let repo = FirebaseAuthRepository()  // Real Firebase!
    let user = try await repo.signIn(...)
}
```

### ✅ DO: Use Protocol Mocks

```swift
// Good: Mock repository
func testSignIn() {
    let mockRepo = MockAuthRepository()
    mockRepo.mockUser = User(id: "123", email: "test@example.com")
    let sut = AuthViewModel(authRepository: mockRepo)
    // ...
}
```

---

### ❌ DON'T: Create Date() in Tests Without Control

```swift
// Bad: Timing-dependent test (flaky!)
let entity1 = Message(timestamp: Date())
let entity2 = Message(timestamp: Date())
XCTAssertEqual(entity1.timestamp, entity2.timestamp)  // Might fail!
```

### ✅ DO: Use Fixed Date Values

```swift
// Good: Predictable test
let fixedDate = Date()
let entity1 = Message(timestamp: fixedDate)
let entity2 = Message(timestamp: fixedDate)
XCTAssertEqual(entity1.timestamp, entity2.timestamp)  // Always passes
```

---

## Debugging Tests

### When a Test Fails

1. **Read the failure message**: XCTest provides detailed output
2. **Run test in isolation**: `./scripts/quick-test.sh -q --test FailingTestName`
3. **Add print statements**: Temporary debugging
4. **Use Xcode debugger**: Set breakpoints, press Cmd+U
5. **Check recent changes**: `git diff` to see what changed

### Xcode Debugging Tips

- **Breakpoint in test**: Click line number, run test (Cmd+U)
- **Step through test**: F6 (step over), F7 (step into)
- **Inspect variables**: Hover over variable or use Debug Console
- **Run to cursor**: Ctrl+Cmd+C

---

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_15.0.app
      
      - name: Run Tests
        run: ./scripts/quick-test.sh
```

**Note**: Scripts automatically handle single-simulator testing, so no additional configuration needed!

---

## Test Coverage Goals

| Layer | Target Coverage | Why |
|-------|----------------|-----|
| **Domain Entities** | 90%+ | Pure Swift, easy to test |
| **ViewModels** | 80%+ | Core business logic |
| **Repositories** | 70%+ | Integration complexity |
| **Views (UI)** | 30-50% | UI tests expensive, focus on critical flows |
| **Overall** | 70%+ | Balanced coverage |

### Checking Coverage

```bash
# In Xcode: Product → Test (Cmd+U)
# Then: View → Navigators → Reports → Coverage tab
```

---

## Integration Testing with Firebase Emulator

### When to Use Integration Tests

- Testing Firebase SDK interactions (Auth, Firestore, Storage)
- Verifying real-time listeners work correctly
- End-to-end workflows (sign up → send message → receive message)
- Offline persistence behavior
- Multi-user real-time scenarios

### Integration Test Pattern

```swift
@MainActor
final class FeatureIntegrationTests: XCTestCase {
    var firebaseService: FirebaseService!
    var repository: SomeRepository!
    
    override func setUp() async throws {
        // 1. Configure emulator
        firebaseService = FirebaseService()
        firebaseService.useEmulator()
        firebaseService.configure()
        
        // 2. Initialize repositories
        repository = FirebaseRepository(firebaseService: firebaseService)
        
        // 3. Create test data
        await createTestData()
    }
    
    override func tearDown() async throws {
        // 4. Clean up test data
        await cleanupTestData()
        
        repository = nil
        try await super.tearDown()
    }
    
    func testFeature_Scenario_Outcome() async throws {
        // Given: Setup preconditions
        
        // When: Execute action
        
        // Then: Verify results using XCTAssert*
    }
}
```

### Real-Time Listener Testing

```swift
func testRealTimeListener() async throws {
    let expectation = XCTestExpectation(description: "Receive message")
    
    // Subscribe to real-time updates
    let cancellable = repository.observeMessages(conversationId: "test")
        .sink { messages in
            if !messages.isEmpty {
                expectation.fulfill()
            }
        }
    
    // Wait for listener to set up
    try await Task.sleep(nanoseconds: 500_000_000)
    
    // Trigger update
    try await repository.sendMessage(testMessage)
    
    // Wait for listener to fire
    await fulfillment(of: [expectation], timeout: 5.0)
    
    cancellable.cancel()
}
```

### Emulator Best Practices

- **Use unique IDs** for test data (UUID) to prevent conflicts
- **Clean up after each test** to prevent cross-test pollution
- **Use descriptive test names**: `testFeature_Scenario_ExpectedOutcome`
- **Keep tests fast** (< 5 seconds each) by minimizing Task.sleep
- **Avoid testing UI** in integration tests (use unit tests with mocks)
- **Test one thing** per test method

### Multi-User Testing

```swift
func testMultiUserRealTime() async throws {
    // Create two users
    let userA = try await authRepository.signUp(
        email: "userA@test.com",
        password: "password123"
    )
    try await authRepository.signOut()
    
    let userB = try await authRepository.signUp(
        email: "userB@test.com",
        password: "password123"
    )
    
    // User B observes messages
    let expectation = XCTestExpectation(description: "User B receives message")
    let cancellable = messageRepository.observeMessages(conversationId: conversationId)
        .sink { messages in
            if !messages.isEmpty {
                expectation.fulfill()
            }
        }
    
    // User A sends message
    try await messageRepository.sendMessage(messageFromUserA)
    
    // Verify User B received it
    await fulfillment(of: [expectation], timeout: 5.0)
    cancellable.cancel()
}
```

### Coverage Goals

| Layer | Target | Rationale |
|-------|--------|-----------|
| Domain Layer | 80%+ | Pure Swift, easy to test |
| Data Layer | 70%+ | Firebase integration, some paths hard to test |
| Presentation Layer | 75%+ | ViewModels, use mocks |

### Performance Testing

Measure critical paths to detect regressions:

```swift
func testPerformance_MessageSend() async throws {
    let start = Date()
    try await messageRepository.sendMessage(message)
    let duration = Date().timeIntervalSince(start)
    
    XCTAssertLessThan(duration, 2.0, "Message send should take < 2 seconds")
}
```

### Running Integration Tests

```bash
# Terminal 1: Start emulator
./scripts/start-emulator.sh

# Terminal 2: Run integration tests
./scripts/run-integration-tests.sh

# Or run complete test suite (skips integration tests if emulator not running)
./scripts/ci-test.sh
```

### Common Integration Test Pitfalls

**❌ DON'T: Forget to clean up test data**
```swift
// Bad: Test data persists, affects other tests
func testFeature() async throws {
    let user = try await authRepository.signUp(...)
    // Test completes, user still in emulator
}
```

**✅ DO: Clean up in tearDown**
```swift
// Good: Each test starts with clean slate
override func tearDown() async throws {
    if authRepository.auth.currentUser != nil {
        try await authRepository.signOut()
    }
    try await super.tearDown()
}
```

---

**❌ DON'T: Use production Firebase in tests**
```swift
// Bad: Hits real Firebase, slow and dangerous
func testFeature() {
    let service = FirebaseService.shared
    // Uses production Firebase!
}
```

**✅ DO: Use emulator**
```swift
// Good: Uses local emulator
override func setUp() async throws {
    firebaseService = FirebaseService()
    firebaseService.useEmulator()  // 🔥 Critical!
    firebaseService.configure()
}
```

---

**❌ DON'T: Forget to wait for real-time listeners**
```swift
// Bad: Listener hasn't set up yet
let cancellable = repository.observeMessages(...)
try await repository.sendMessage(message)  // Listener might miss this!
```

**✅ DO: Wait for listener to set up**
```swift
// Good: Give listener time to establish connection
let cancellable = repository.observeMessages(...)
try await Task.sleep(nanoseconds: 500_000_000)  // 0.5 seconds
try await repository.sendMessage(message)
```

## Summary

**✅ Do This**:
- Use **tiered testing**: story → epic → full suite (see [Testing Strategy](./testing-strategy.md))
- Use `./scripts/test-story.sh <TestName>` during development (5-20s)
- Use `./scripts/test-epic.sh <num>` before marking story complete (20-40s)
- Use `./scripts/quick-test.sh` before committing (1-2min)
- Keep simulator running between test runs
- Write tests for all ViewModels and Entities
- Use mock repositories with the standard pattern
- Test before every commit
- Use Firebase Emulator for integration tests (weekly)
- Clean up test data in tearDown
- Use unique IDs (UUID) for test data

**❌ Don't Do This**:
- Don't run full test suite during story development (use story tests instead)
- Don't use parallel testing (multiple simulators)
- Don't run tests without using the tiered test scripts
- Don't commit without running full test suite (`./scripts/quick-test.sh`)
- Don't write tests that hit real external services
- Don't use Date() without controlling the value
- Don't use production Firebase in integration tests
- Don't forget to wait for real-time listeners to set up

**Questions?** Check `docs/architecture/testing-strategy.md` for complete testing strategy guide.

