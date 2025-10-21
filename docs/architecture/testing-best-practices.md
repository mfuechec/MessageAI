# Testing Best Practices

## Quick Reference

**Always use the quick-test script for terminal testing:**

```bash
./scripts/quick-test.sh --quick
```

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

### Daily Development

```bash
# 1. Write code
# 2. Write/update tests
# 3. Run quick test
./scripts/quick-test.sh -q

# 4. If tests pass, commit
git add .
git commit -m "Feature: Add X with tests"

# 5. On failure, debug in Xcode
# Open Xcode, set breakpoints, run specific test (Cmd+U)
```

### Before Committing

```bash
# Run ALL tests to catch regressions
./scripts/quick-test.sh

# Verify clean build
./scripts/build.sh

# Check linter
# (Future: add linter check here)
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
        └── ConversationsListViewModelTests.swift
```

### Test Naming Conventions

```swift
// Test function naming: test{What}_{Scenario}_{ExpectedOutcome}
func testSignIn_ValidCredentials_ReturnsUser()
func testSignIn_InvalidEmail_ThrowsError()
func testFetchMessages_EmptyConversation_ReturnsEmptyArray()

// Test class naming: {What}Tests
class AuthViewModelTests: XCTestCase { }
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

## Summary

**✅ Do This**:
- Use `./scripts/quick-test.sh -q` for fast iteration
- Keep simulator running between test runs
- Write tests for all ViewModels and Entities
- Use mock repositories with the standard pattern
- Test before every commit

**❌ Don't Do This**:
- Don't use parallel testing (multiple simulators)
- Don't run tests without quick-test.sh script
- Don't commit without running tests
- Don't write tests that hit real external services
- Don't use Date() without controlling the value

**Questions?** Check `docs/architecture/testing-strategy.md` for detailed testing strategy.

