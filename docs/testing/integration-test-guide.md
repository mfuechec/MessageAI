# Integration Test Guide - MessageAI MVP

**Version:** 1.0
**Last Updated:** 2025-10-22 (Story 2.12)
**Purpose:** Guide for running end-to-end integration tests with Firebase Emulator

---

## Overview

Integration tests validate MessageAI's behavior against a real Firebase backend running locally via the Firebase Emulator Suite. These tests go beyond unit tests by exercising complete user flows with actual Firestore writes, real-time listeners, and authentication.

**Total Integration Tests:** 19 tests across 3 test suites

---

## Quick Start

### Prerequisites

1. **Firebase CLI installed:**
   ```bash
   npm install -g firebase-tools
   # OR
   curl -sL https://firebase.tools | bash
   ```

2. **Java Runtime Environment** (for Firestore emulator):
   ```bash
   java -version  # Verify JRE installed
   ```

3. **Firebase project configured:**
   - `.firebaserc` present in project root
   - `firebase.json` configured
   - `firestore.rules` present

### Running Integration Tests

**Step 1: Start Firebase Emulator**
```bash
# Terminal 1: Start emulator (foreground with logs)
./scripts/start-emulator.sh
```

**Step 2: Run Integration Tests**
```bash
# Terminal 2: Run tests
./scripts/quick-test.sh --with-integration
```

**Step 3: Stop Emulator**
```bash
./scripts/stop-emulator.sh
```

---

## Firebase Emulator Configuration

### Emulator Ports

| Service | Port | URL |
|---------|------|-----|
| **Firestore** | 8080 | http://localhost:8080 |
| **Authentication** | 9099 | http://localhost:9099 |
| **Storage** | 9199 | http://localhost:9199 |
| **Emulator UI** | 4000 | http://localhost:4000 |

### Accessing Emulator UI

While emulator is running, open http://localhost:4000 in browser to:
- View Firestore collections and documents
- Inspect authentication users
- Monitor real-time database changes
- View storage files
- Clear all data

### Emulator Management Scripts

**Check if emulator is running:**
```bash
./scripts/emulator-check.sh
```

**Start emulator (foreground):**
```bash
./scripts/start-emulator.sh
```

**Start emulator (background, silent):**
```bash
./scripts/start-emulator.sh > /dev/null 2>&1 &
```

**Stop emulator:**
```bash
./scripts/stop-emulator.sh
```

---

## Integration Test Suites

### Test Suite 1: Real-Time Messaging Integration

**File:** `MessageAITests/Integration/RealTimeMessagingIntegrationTests.swift`
**Test Count:** 8 tests
**Duration:** ~30-45 seconds

#### Tests Included

1. **testRealTimeMessageDelivery**
   - User A sends message
   - User B's real-time listener receives it
   - Validates: < 2 second delivery

2. **testMessageEditPropagation**
   - User A edits message
   - User B sees edit in real-time
   - Validates: Edit history preserved

3. **testMessageDeletePropagation**
   - User A deletes message
   - User B sees "Message deleted" placeholder
   - Validates: Soft delete behavior

4. **testReadReceiptFlow**
   - User A sends message
   - User B marks as read
   - User A sees "Read" status
   - Validates: Bidirectional read receipt sync

5. **testTypingIndicatorFlow**
   - User A starts typing
   - User B sees "User A is typing..." indicator
   - User A stops typing
   - Indicator disappears after 3 seconds
   - Validates: Real-time typing state

6. **testGroupMessageDelivery**
   - 3-user group conversation
   - One user sends message
   - Other 2 users receive it
   - Validates: Group real-time broadcast

7. **testConcurrentMessageSending**
   - User A and User B send simultaneously
   - Both messages delivered correctly
   - Validates: Firestore concurrent write handling

8. **testOfflineMessageQueue**
   - User A goes offline
   - Attempts to send message (queued)
   - Goes back online
   - Message delivers automatically
   - Validates: Offline → Online transition

#### Running This Suite Alone

```bash
# Start emulator first
./scripts/start-emulator.sh

# Run only this test suite
./scripts/test-story.sh RealTimeMessagingIntegrationTests
```

---

### Test Suite 2: Offline Persistence Integration

**File:** `MessageAITests/Integration/OfflinePersistenceIntegrationTests.swift`
**Test Count:** 6 tests
**Duration:** ~20-30 seconds

#### Tests Included

1. **testOfflineReadFromCache**
   - Load conversations online
   - Go offline
   - Read cached conversations
   - Validates: Firestore offline persistence enabled

2. **testOfflineWriteQueued**
   - Go offline
   - Attempt to send message
   - Message queued locally
   - Validates: Write queue functionality

3. **testOnlineSyncAfterOffline**
   - Queue 5 messages offline
   - Go online
   - Messages sync to Firestore
   - Validates: Batch sync

4. **testConflictResolutionOnSync**
   - User A edits message offline
   - User B edits same message online
   - User A goes online
   - Last write wins (User A's edit)
   - Validates: Firestore conflict resolution

5. **testOfflineCacheExpiration**
   - Load data online
   - Wait 24 hours (simulated)
   - Go offline
   - Verify stale data handling
   - Validates: Cache expiration policy

6. **testOfflinePersistenceSize**
   - Load 100 messages
   - Go offline
   - Verify all 100 messages cached
   - Validates: Cache size limits

#### Running This Suite Alone

```bash
./scripts/test-story.sh OfflinePersistenceIntegrationTests
```

---

### Test Suite 3: Offline Queue Integration

**File:** `MessageAITests/Integration/OfflineQueueIntegrationTests.swift`
**Test Count:** 5 tests
**Duration:** ~15-25 seconds

#### Tests Included

1. **testOfflineQueuePersistence**
   - Queue 10 messages offline
   - Force-quit app
   - Restart app
   - Verify all 10 messages still queued
   - Validates: Queue survives app restart

2. **testOfflineQueueOrder**
   - Queue 20 messages offline (numbered)
   - Go online
   - Send all
   - Verify delivery order matches queue order
   - Validates: FIFO queue behavior

3. **testOfflineQueueRetry**
   - Queue message offline
   - Go online with poor network (simulated)
   - Message send fails
   - Retry automatically
   - Validates: Retry policy in offline queue

4. **testOfflineQueueMaxSize**
   - Attempt to queue 100 messages
   - Verify app handles gracefully (or enforces limit)
   - Validates: Queue size limits

5. **testOfflineQueueClearOnSignOut**
   - Queue 5 messages offline
   - Sign out
   - Sign back in
   - Verify queue cleared for previous user
   - Validates: Queue isolation per user

#### Running This Suite Alone

```bash
./scripts/test-story.sh OfflineQueueIntegrationTests
```

---

## Test Execution Workflow

### Standard Integration Test Run

```bash
# 1. Check emulator status
./scripts/emulator-check.sh

# 2. Start emulator if not running
./scripts/start-emulator.sh

# 3. Wait for emulator to be ready (~10-15 seconds)
# Look for output: "All emulators ready!"

# 4. Run all integration tests (in separate terminal)
./scripts/quick-test.sh --with-integration

# 5. Review results
# Tests should complete in ~2-5 minutes

# 6. Stop emulator when done
./scripts/stop-emulator.sh
```

### Troubleshooting Failed Tests

If integration tests fail:

**Step 1: Verify Emulator Running**
```bash
./scripts/emulator-check.sh
# Should show: "✅ Firebase Emulator is running"
```

**Step 2: Check Emulator Logs**
```bash
# Emulator logs in Terminal 1 where you started it
# Look for errors related to Firestore, Auth, or Storage
```

**Step 3: Clear Emulator Data**
```bash
# Stop emulator
./scripts/stop-emulator.sh

# Restart with clean slate
./scripts/start-emulator.sh
```

**Step 4: Verify Firestore Rules**
```bash
# Deploy rules to emulator
firebase deploy --only firestore:rules --project messageai-dev-1f2ec
```

**Step 5: Check Test Configuration**
```swift
// In integration test setUp()
override func setUp() async throws {
    try await super.setUp()

    // This line configures emulator connection
    firebaseService.useEmulator()
    firebaseService.configure()
}
```

---

## Integration Test Patterns

### Pattern 1: Multi-User Real-Time Testing

```swift
func testRealTimeMessageDelivery() async throws {
    // GIVEN: Two authenticated users
    let userA = try await authRepository.signUp(
        email: "userA@test.com",
        password: "password123"
    )
    try await authRepository.signOut()

    let userB = try await authRepository.signUp(
        email: "userB@test.com",
        password: "password123"
    )

    // Create conversation
    let conversation = try await conversationRepository.createConversation(
        participantIds: [userA.id, userB.id]
    )

    // WHEN: User B observes messages (real-time listener)
    let expectation = XCTestExpectation(description: "Receive message")
    let cancellable = messageRepository.observeMessages(conversationId: conversation.id)
        .sink { messages in
            if !messages.isEmpty {
                expectation.fulfill()
            }
        }

    // Give listener time to establish connection
    try await Task.sleep(nanoseconds: 500_000_000)  // 0.5 seconds

    // THEN: User A sends message
    try await messageRepository.sendMessage(messageFromUserA)

    // VERIFY: User B receives it within 2 seconds
    await fulfillment(of: [expectation], timeout: 2.0)
    cancellable.cancel()
}
```

### Pattern 2: Offline-Online Transition Testing

```swift
func testOfflineOnlineSync() async throws {
    // GIVEN: User online with messages
    let conversation = try await conversationRepository.createConversation(...)

    // WHEN: Go offline
    try await firebaseService.goOffline()

    // Attempt to send 5 messages (should queue)
    for i in 1...5 {
        try await messageRepository.sendMessage(message(text: "Message \(i)"))
    }

    // Verify queued locally
    let queuedMessages = try await offlineQueueStore.getQueuedMessages()
    XCTAssertEqual(queuedMessages.count, 5)

    // THEN: Go online
    try await firebaseService.goOnline()

    // Wait for sync
    try await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds

    // VERIFY: All messages in Firestore
    let firestoreMessages = try await messageRepository.getMessages(conversationId: conversation.id)
    XCTAssertEqual(firestoreMessages.count, 5)
}
```

### Pattern 3: Real-Time Listener Testing

```swift
func testTypingIndicatorRealTime() async throws {
    let expectation = XCTestExpectation(description: "Typing indicator appears")

    // Subscribe to typing state
    let cancellable = conversationRepository.observeTypingState(conversationId: conversationId)
        .sink { typingUsers in
            if typingUsers.contains(where: { $0.id == userA.id }) {
                expectation.fulfill()
            }
        }

    // Wait for listener setup
    try await Task.sleep(nanoseconds: 500_000_000)

    // User A starts typing
    try await conversationRepository.updateTypingState(
        conversationId: conversationId,
        userId: userA.id,
        isTyping: true
    )

    // Verify received within 1 second
    await fulfillment(of: [expectation], timeout: 1.0)
    cancellable.cancel()
}
```

---

## Performance Expectations

### Integration Test Speed

| Test Suite | Test Count | Expected Duration |
|------------|------------|-------------------|
| RealTimeMessagingIntegrationTests | 8 tests | 30-45 seconds |
| OfflinePersistenceIntegrationTests | 6 tests | 20-30 seconds |
| OfflineQueueIntegrationTests | 5 tests | 15-25 seconds |
| **Total** | **19 tests** | **65-100 seconds** (~1.5 minutes) |

### Why Integration Tests Are Slower

- **Real network operations:** Actual Firestore writes over localhost network
- **Real-time listener setup:** 0.5-1 second to establish WebSocket connections
- **Async operations:** `Task.sleep()` for timing validations
- **Multi-user scenarios:** Multiple auth/signout cycles
- **Data cleanup:** Each test cleans up Firestore data

---

## Common Issues & Solutions

### Issue 1: "Address already in use" (Port 8080)

**Cause:** Previous emulator instance still running

**Solution:**
```bash
# Find process using port 8080
lsof -i :8080

# Kill the process
kill -9 <PID>

# OR use stop script
./scripts/stop-emulator.sh
```

---

### Issue 2: Tests Skip with "Emulator not running"

**Cause:** Integration tests check for emulator and skip if not available

**Solution:**
```bash
# Start emulator first
./scripts/start-emulator.sh

# Then run tests
./scripts/quick-test.sh --with-integration
```

---

### Issue 3: Firestore Permission Denied

**Cause:** Firestore security rules rejecting writes

**Solution:**
```bash
# Re-deploy rules to emulator
firebase deploy --only firestore:rules --project messageai-dev-1f2ec

# OR temporarily use permissive rules for testing
# Edit firestore.rules:
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if true;  // ⚠️ Test only!
    }
  }
}
```

---

### Issue 4: Tests Timeout

**Cause:** Real-time listeners not receiving updates

**Solutions:**
1. Increase timeout in test: `await fulfillment(of: [expectation], timeout: 5.0)`
2. Add debug logging to see if writes are reaching Firestore
3. Check emulator UI (http://localhost:4000) for data changes
4. Verify listener setup wait time: `try await Task.sleep(nanoseconds: 500_000_000)`

---

### Issue 5: Emulator Data Pollution

**Cause:** Previous test data affecting new test runs

**Solution:**
```bash
# Stop emulator
./scripts/stop-emulator.sh

# Clear emulator data directory (if exists)
rm -rf .firebase-emulator-data/

# Restart emulator
./scripts/start-emulator.sh
```

---

## Best Practices

### DO ✅

1. **Start emulator before running tests**
   - Always check with `./scripts/emulator-check.sh`

2. **Use unique test data IDs**
   - Use UUIDs for test users, conversations, messages
   - Prevents conflicts between parallel test runs

3. **Wait for real-time listeners to establish**
   - Add `Task.sleep(nanoseconds: 500_000_000)` after listener setup

4. **Clean up test data in tearDown**
   - Delete test users, conversations, messages
   - Prevents data pollution

5. **Use descriptive test names**
   - `testRealTimeMessageDelivery_TwoUsers_UnderTwoSeconds`

6. **Run integration tests weekly**
   - Part of release checklist
   - Before major feature merges

### DON'T ❌

1. **Don't run integration tests without emulator**
   - Tests will skip automatically

2. **Don't hardcode user credentials**
   - Generate unique emails per test run

3. **Don't use production Firebase**
   - Always use emulator for integration tests

4. **Don't ignore test timeouts**
   - Investigate root cause (network, Firestore rules, listener setup)

5. **Don't leave emulator running indefinitely**
   - Consumes resources
   - Stop when done: `./scripts/stop-emulator.sh`

---

## Integration Test Results

### Status: ⏳ Ready to Run

**Command to execute:**
```bash
# Terminal 1
./scripts/start-emulator.sh

# Terminal 2
./scripts/quick-test.sh --with-integration
```

### Expected Results

| Test Suite | Expected Pass Rate |
|------------|-------------------|
| RealTimeMessagingIntegrationTests | 8/8 (100%) |
| OfflinePersistenceIntegrationTests | 6/6 (100%) |
| OfflineQueueIntegrationTests | 5/5 (100%) |
| **Total** | **19/19 (100%)** |

### Actual Results

⏳ **Not yet executed** - Awaiting manual emulator startup and test run

_To be filled after running integration tests_

---

## Related Documentation

- [Regression Test Suite](./regression-test-suite.md) - All test mappings
- [Coverage Report](./coverage-report.md) - Unit test results
- [Reliability Scenarios](./reliability-scenarios.md) - Manual stress tests
- [Testing Strategy](../architecture/testing-strategy.md) - Complete testing workflow

---

## Change Log

| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2025-10-22 | 1.0 | Initial integration test guide created | James (Dev) |

---

**Status:** ✅ Integration Tests Ready
**Emulator Required:** Yes - run `./scripts/start-emulator.sh` first
**Execution Time:** ~2-5 minutes (all 19 tests)
