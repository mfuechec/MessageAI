# Story Scoping Patterns & Learnings

**Purpose:** Quick reference for SM when drafting Stories 2.11-2.12 and beyond.

**Source:** Lessons learned from Story 2.7 and 2.10 reviews (2024-10-22)

---

## Top 10 Checklist (Quick Pre-Draft Scan)

Before drafting any story, verify:

1. ✅ **No global static variables** - Use AppState or dependency injection
2. ✅ **Cleanup on sign-out** - Clear tokens, state, caches
3. ✅ **Retry logic for critical ops** - Network writes need 3-retry + backoff
4. ✅ **Large data → File system** - Not UserDefaults (max 100KB)
5. ✅ **Edge case: Account switching** - Multi-user device scenarios
6. ✅ **Edge case: Data not loaded** - Handle nil/empty states gracefully
7. ✅ **Explicit error handling** - Every network call needs error path
8. ✅ **Performance targets in AC** - "< 2 seconds", "< 2MB" specificity
9. ✅ **Regression AC included** - "Existing feature X still works"
10. ✅ **200+ lines code samples** - Complex features need detailed implementation

---

## Approved Architectural Patterns

### Pattern 1: AppState for Shared State (Replaces Static Variables)

**Use When:** Multiple components need access to app-level state

**Template:**
```swift
// NEW FILE: MessageAI/App/AppState.swift
@MainActor
class AppState: ObservableObject {
    static let shared = AppState()

    @Published var someSharedState: String?
    @Published var currentUserId: String?

    private init() {}

    func clearState() {
        someSharedState = nil
        currentUserId = nil
    }
}

// Usage in ViewModel
func onAppear() {
    AppState.shared.someSharedState = value
}

// Cleanup in AuthViewModel.signOut()
func signOut() async throws {
    AppState.shared.clearState()
    // ... rest of sign out
}
```

**Why:**
- ✅ Thread-safe (@MainActor)
- ✅ Testable (can reset state)
- ✅ Clears on sign-out
- ❌ Avoids static variables that persist forever

---

### Pattern 2: Retry Logic with Exponential Backoff

**Use When:** Network operations that can fail transiently (token registration, critical writes)

**Template:**
```swift
private func saveImportantData() async {
    var retryCount = 0
    let maxRetries = 3

    while retryCount < maxRetries {
        do {
            try await repository.save(data)
            print("✅ Data saved successfully")
            return  // Success - exit retry loop

        } catch {
            retryCount += 1

            if retryCount < maxRetries {
                // Exponential backoff: 1s, 2s, 4s
                let delay = UInt64(pow(2.0, Double(retryCount - 1)) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: delay)
                print("⚠️ Save failed (attempt \(retryCount)/\(maxRetries)), retrying...")
            } else {
                print("❌ Failed after \(maxRetries) attempts: \(error)")
                // Log error, queue for later, or show user message
            }
        }
    }
}
```

**Why:**
- ✅ Handles transient network failures
- ✅ Doesn't spam server (backoff)
- ✅ Gives up after reasonable attempts

---

### Pattern 3: Temporary File Storage (Not UserDefaults)

**Use When:** Storing data > 100KB (images, large JSON, offline queues)

**Template:**
```swift
// NEW FILE: MessageAI/Presentation/Utils/TemporaryStorageManager.swift
import Foundation

enum TemporaryStorageManager {
    private static let tempDirectory: URL = {
        let tempDir = FileManager.default.temporaryDirectory
        let storageDir = tempDir.appendingPathComponent("app_storage")
        try? FileManager.default.createDirectory(at: storageDir, withIntermediateDirectories: true)
        return storageDir
    }()

    /// Save data to temp storage
    static func save(_ data: Data, forKey key: String) throws -> URL {
        let fileURL = tempDirectory.appendingPathComponent("\(key).dat")
        try data.write(to: fileURL)
        return fileURL
    }

    /// Load data from temp storage
    static func load(forKey key: String) -> Data? {
        let fileURL = tempDirectory.appendingPathComponent("\(key).dat")
        return try? Data(contentsOf: fileURL)
    }

    /// Delete data
    static func delete(forKey key: String) {
        let fileURL = tempDirectory.appendingPathComponent("\(key).dat")
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// Clean up old files (> 24 hours)
    static func cleanupExpired() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: tempDirectory,
            includingPropertiesForKeys: [.creationDateKey]
        ) else { return }

        let expiration = Date().addingTimeInterval(-24 * 60 * 60)

        for fileURL in files {
            guard let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
                  let created = attributes[.creationDate] as? Date,
                  created < expiration else { continue }

            try? FileManager.default.removeItem(at: fileURL)
        }
    }
}

// Metadata in UserDefaults (lightweight)
struct OfflineQueueMetadata: Codable {
    let itemId: String
    let filePath: String
    let timestamp: Date
}

// Usage
let imageData = compressedImage.jpegData(compressionQuality: 0.8)!
try TemporaryStorageManager.save(imageData, forKey: messageId)

// Store metadata only
let metadata = OfflineQueueMetadata(itemId: messageId, filePath: "\(messageId).dat", timestamp: Date())
UserDefaults.standard.set(try? JSONEncoder().encode(metadata), forKey: "queue_\(messageId)")
```

**Why:**
- ✅ UserDefaults max ~1MB total
- ✅ File system handles GB of data
- ✅ Automatic cleanup possible

---

### Pattern 4: Deep Link Fallback (Data Not Loaded)

**Use When:** Opening specific items from notifications, URLs, or other triggers

**Template:**
```swift
// In ConversationsListView or similar
.onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenItem"))) { notification in
    if let itemId = notification.userInfo?["itemId"] as? String {

        // Try to find in loaded data first (fast path)
        if let item = viewModel.items.first(where: { $0.id == itemId }) {
            openItem(item)
        } else {
            // Not loaded yet - fetch from repository (slow path)
            Task {
                do {
                    let item = try await viewModel.fetchItem(id: itemId)
                    await MainActor.run {
                        openItem(item)
                    }
                } catch {
                    await MainActor.run {
                        viewModel.errorMessage = "This item is no longer available"
                    }
                }
            }
        }
    }
}

// In ViewModel
func fetchItem(id: String) async throws -> Item {
    return try await repository.getItem(id: id)
}
```

**Why:**
- ✅ Handles race condition (notification arrives before data loads)
- ✅ Provides user feedback if item deleted
- ✅ Fast path for common case (data already loaded)

---

### Pattern 5: Account Switching Cleanup

**Use When:** User can sign out and different user sign in on same device

**Required in AuthViewModel.signOut():**

```swift
func signOut() async throws {
    // 1. Clear user-specific server data
    if let userId = currentUserId {
        try await clearUserServerData(userId)
    }

    // 2. Clear app-level state
    await MainActor.run {
        AppState.shared.clearState()
    }

    // 3. Clear cached data
    clearCaches()

    // 4. Sign out from Firebase Auth
    try Auth.auth().signOut()

    // 5. Clear local state
    currentUser = nil
}

private func clearUserServerData(_ userId: String) async throws {
    let db = Firestore.firestore()

    // Clear FCM token (prevent cross-user notifications)
    try? await db.collection("users").document(userId).updateData([
        "fcmToken": FieldValue.delete(),
        "fcmTokenUpdatedAt": FieldValue.delete()
    ])

    // Clear presence/online status
    try? await db.collection("users").document(userId).updateData([
        "isOnline": false,
        "lastSeen": FieldValue.serverTimestamp()
    ])
}

private func clearCaches() {
    // Clear image cache
    URLCache.shared.removeAllCachedResponses()

    // Clear temporary files
    TemporaryStorageManager.cleanup()

    // Clear UserDefaults user-specific keys
    let keysToRemove = ["currentUserId", "draftMessages", "offlineQueue"]
    keysToRemove.forEach { UserDefaults.standard.removeObject(forKey: $0) }
}
```

**Why:**
- ✅ Prevents User A data leaking to User B
- ✅ Clears FCM tokens (no cross-user notifications)
- ✅ Resets app to clean state

---

## Anti-Patterns to AVOID

### ❌ Anti-Pattern 1: Global Static Variables

**DON'T:**
```swift
class SomeViewModel {
    static var sharedState: String?  // ❌ Never deallocates, persists across sign-outs
}
```

**DO:**
```swift
// Use AppState pattern (see Pattern 1)
AppState.shared.someState = value
```

---

### ❌ Anti-Pattern 2: Silent Network Failures

**DON'T:**
```swift
do {
    try await repository.save(data)
} catch {
    print("Error: \(error)")  // ❌ User has no idea it failed
}
```

**DO:**
```swift
do {
    try await repository.save(data)
} catch {
    print("Error: \(error)")
    errorMessage = "Failed to save. Tap to retry."  // ✅ User feedback
    // OR queue for retry
}
```

---

### ❌ Anti-Pattern 3: Unbounded Queries

**DON'T:**
```swift
let messages = db.collection("messages")
    .whereField("conversationId", isEqualTo: id)
    .order(by: "timestamp", descending: true)
    // ❌ Could load 10,000 messages
```

**DO:**
```swift
let messages = db.collection("messages")
    .whereField("conversationId", isEqualTo: id)
    .order(by: "timestamp", descending: true)
    .limit(to: 50)  // ✅ Bounded query
```

---

### ❌ Anti-Pattern 4: Large Data in UserDefaults

**DON'T:**
```swift
let imageData = image.jpegData(compressionQuality: 0.8)!  // 2MB
UserDefaults.standard.set(imageData.base64EncodedString(), forKey: "image")  // ❌ Overflow
```

**DO:**
```swift
try TemporaryStorageManager.save(imageData, forKey: messageId)  // ✅ File system
UserDefaults.standard.set(messageId, forKey: "cachedImageId")  // ✅ Just metadata
```

---

### ❌ Anti-Pattern 5: Assumption Data Exists

**DON'T:**
```swift
.onReceive(...) { notification in
    let item = items.first(where: { $0.id == id })!  // ❌ Force unwrap - crashes if not loaded
    openItem(item)
}
```

**DO:**
```swift
.onReceive(...) { notification in
    if let item = items.first(where: { $0.id == id }) {
        openItem(item)  // ✅ Safe unwrap
    } else {
        Task { await fetchAndOpen(id) }  // ✅ Fallback
    }
}
```

---

## Story-Specific Patterns for 2.11 & 2.12

### For Story 2.11 (Performance & Caching)

**Key Patterns to Include:**

1. **LRU Cache with Size Limit:**
```swift
class LRUCache<Key: Hashable, Value> {
    private var cache: [Key: Value] = [:]
    private var accessOrder: [Key] = []
    private let maxSize: Int

    init(maxSize: Int = 100) {
        self.maxSize = maxSize
    }

    func get(_ key: Key) -> Value? {
        guard let value = cache[key] else { return nil }

        // Move to end (most recently used)
        accessOrder.removeAll { $0 == key }
        accessOrder.append(key)

        return value
    }

    func set(_ key: Key, value: Value) {
        cache[key] = value
        accessOrder.append(key)

        // Evict least recently used if over limit
        while accessOrder.count > maxSize {
            let lruKey = accessOrder.removeFirst()
            cache.removeValue(forKey: lruKey)
        }
    }

    func clear() {
        cache.removeAll()
        accessOrder.removeAll()
    }
}
```

2. **Cache Invalidation Strategy:**
- Time-based: Expire after 5 minutes
- Event-based: Clear on sign-out, app background
- Size-based: LRU eviction when > 100 items

3. **Pagination Pattern:**
```swift
func loadMoreMessages() async {
    guard !isLoadingMore && hasMore else { return }

    isLoadingMore = true
    defer { isLoadingMore = false }

    let newMessages = try await repository.getMessages(
        conversationId: conversationId,
        limit: 50,
        startAfter: lastDocument
    )

    messages.insert(contentsOf: newMessages, at: 0)
    lastDocument = newMessages.last
    hasMore = newMessages.count == 50
}
```

---

### For Story 2.12 (Testing & Deployment)

**Key Patterns to Include:**

1. **Reliability Test Scenarios (AC):**
```
- Scenario 1: Network drops mid-message send
- Scenario 2: App killed during image upload
- Scenario 3: Sign out while messages in offline queue
- Scenario 4: Receive 100 messages while offline
- Scenario 5: Battery dies, app force-quit
```

2. **Performance Baseline Tests:**
```swift
func testMessageLoadPerformance() throws {
    measure {
        // Load 1000 messages from Firestore
        let messages = try await loadMessages(limit: 1000)
    }
    // XCTest will report average time - should be < 2 seconds
}
```

3. **Memory Leak Detection:**
```swift
func testChatViewModelMemoryLeak() {
    weak var weakViewModel: ChatViewModel?

    autoreleasepool {
        let viewModel = makeChatViewModel()
        weakViewModel = viewModel
        viewModel.onAppear()
        viewModel.loadMessages()
        viewModel.onDisappear()
    }

    XCTAssertNil(weakViewModel, "ChatViewModel should be deallocated")
}
```

---

## Acceptance Criteria Templates

### Performance AC Template
```
X. Performance: [Operation] completes within [N] seconds on [Network Condition]
   - [Sub-operation 1]: < [N1] seconds
   - [Sub-operation 2]: < [N2] seconds
   - Total end-to-end: < [N] seconds
   - Optimistic UI: < 1 second perceived performance
```

### Error Handling AC Template
```
X. When [operation] fails due to [error type]:
   - User sees error message: "[User-friendly message]"
   - Retry option provided: [Button/Auto-retry with backoff]
   - Operation queued for later if offline
   - Existing data remains intact (no data loss)
```

### Account Switching AC Template
```
X. When user signs out:
   - [User-specific data] cleared from Firestore
   - [App state] reset to initial state
   - [Caches] cleared
   - [Temporary files] deleted

Y. When new user signs in:
   - Fresh data loaded (no previous user data)
   - [User-specific tokens] registered for new user
   - No cross-user data leakage
```

### Edge Case AC Template
```
X. When [edge case condition] occurs:
   - Fallback behavior: [Fetch from server / Show cached / Show error]
   - User feedback: [Loading indicator / Error message / Empty state]
   - Timeout: [N] seconds
   - Retry strategy: [Manual / Automatic with backoff / Queue for later]
```

---

## Quick Pre-Submit Checklist

Before submitting story to PO:

1. ✅ Run through story-quality-checklist.md (full checklist)
2. ✅ Check against anti-patterns above
3. ✅ Verify 200+ lines of code samples for complex features
4. ✅ Ensure all patterns applied (AppState, retry, cleanup, etc.)
5. ✅ Account switching scenarios covered
6. ✅ Edge cases explicit in AC (not just implied)
7. ✅ Performance targets measurable (not vague)
8. ✅ Regression AC included
9. ✅ Test plan complete (unit + manual)
10. ✅ Deferred items documented with rationale

---

## Summary

**Use this doc when drafting 2.11-2.12 to:**
- Apply proven patterns (AppState, retry, temp storage)
- Avoid anti-patterns (static vars, UserDefaults overflow)
- Include comprehensive edge cases (account switching, data not loaded)
- Write specific, measurable AC
- Provide detailed code samples (200+ lines)

**Story quality bar:** Match Story 2.10 (⭐⭐⭐⭐☆), not Story 2.7 (⭐⭐⭐☆☆)

---

## Version History

| Date | Version | Changes |
|------|---------|---------|
| 2024-10-22 | 1.0 | Initial patterns doc from Story 2.7/2.10 reviews |
