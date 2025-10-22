# Optimistic UI Pattern in MessageAI

**Pattern Type:** Presentation Layer Best Practice
**Date:** 2025-10-22
**Used In:** Message Sending, Editing, Deletion, Read Receipts

## Core Principle

**Show changes immediately, persist in background, rollback only on critical failures.**

## Pattern Template

```swift
@MainActor
class SomeViewModel: ObservableObject {
    @Published var items: [Item] = []

    func performAction() async {
        // 1️⃣ UPDATE LOCAL STATE IMMEDIATELY
        let optimisticItem = Item(/* ... */)
        items.append(optimisticItem)  // UI updates instantly

        // 2️⃣ PERSIST IN BACKGROUND
        do {
            try await repository.save(optimisticItem)
            // Success - local state already matches server
        } catch {
            // 3️⃣ ROLLBACK ONLY IF CRITICAL
            if isCriticalFailure(error) {
                items.removeAll { $0.id == optimisticItem.id }
            }
            // Show error to user
            errorMessage = userFriendlyMessage(error)
        }
    }
}
```

## When to Rollback vs. Keep Optimistic Update

### ✅ ALWAYS ROLLBACK (Critical Failures)
- **Message sending** - If save fails, mark as `.failed` but keep in array
- **Message editing** - Revert to original text on failure
- **User creation** - Remove if auth fails

### ❌ NEVER ROLLBACK (Best-Effort)
- **Read receipts** - Eventual consistency is fine
- **Typing indicators** - Ephemeral, doesn't matter
- **Presence updates** - Will sync eventually

## Array Reassignment for @Published

**CRITICAL:** SwiftUI doesn't detect in-place array mutations. Must reassign entire array.

```swift
// ❌ WRONG - SwiftUI won't update
messages[index].status = .read

// ✅ CORRECT - Triggers @Published
var updated = messages
updated[index].status = .read
messages = updated  // ← Reassignment triggers UI update
```

## Force UI Refresh When Count Doesn't Change

When editing/deleting messages, array count stays same but content changes:

```swift
@Published var messagesNeedRefresh: Bool = false

func saveEdit() async {
    // Update message text
    var updated = messages
    updated[index].text = newText
    messages = updated
    messagesNeedRefresh = true  // ← Force MessageKit refresh
}
```

## Real-World Examples

### Example 1: Message Sending (Story 2.0, 2.4)
```swift
func sendMessage() async {
    let message = Message(/* ... */, status: .sending)

    // 1. Optimistic UI
    messages.append(message)
    messageText = ""  // Clear input

    // 2. Persist
    do {
        try await messageRepository.sendMessage(message)
        // Update status to .sent
        if let index = messages.firstIndex(where: { $0.id == message.id }) {
            var updated = messages
            updated[index].status = .sent
            messages = updated
        }
    } catch {
        // 3. Mark as failed (keep in array for retry)
        if let index = messages.firstIndex(where: { $0.id == message.id }) {
            var updated = messages
            updated[index].status = .failed
            messages = updated
        }
        errorMessage = "Message failed. Tap to retry."
    }
}
```

### Example 2: Message Editing (Story 2.2)
```swift
func saveEdit() async {
    let originalMessage = messages[index]

    // 1. Optimistic UI
    var updated = messages
    updated[index].text = trimmedText
    updated[index].isEdited = true
    messages = updated
    messagesNeedRefresh = true

    // 2. Persist
    do {
        try await messageRepository.editMessage(id: messageId, newText: trimmedText)
    } catch {
        // 3. ROLLBACK on failure (editing is critical)
        var rollback = messages
        rollback[index] = originalMessage
        messages = rollback
        errorMessage = "Failed to save changes"
    }
}
```

### Example 3: Read Receipts (Story 2.5)
```swift
func markMessagesAsRead() async {
    // 1. Optimistic UI
    for id in messageIds {
        var updated = messages
        updated[index].readBy.append(currentUserId)
        updated[index].status = .read
        messages = updated
    }

    // 2. Persist
    do {
        try await messageRepository.markMessagesAsRead(messageIds, userId)
    } catch {
        // 3. NO ROLLBACK - read receipts are best-effort
        print("Failed to mark as read: \(error)")
    }
}
```

## Performance Benefits

| Action | Without Optimistic UI | With Optimistic UI |
|--------|----------------------|-------------------|
| Message send | Wait 200-500ms | Appears instantly |
| Message edit | Wait 200-500ms | Updates instantly |
| Message delete | Wait 200-500ms | Removes instantly |
| Read receipt | Wait 200-500ms | Shows immediately |

**User Perception:** App feels **10x faster** with optimistic UI.

## Error Handling Strategy

### Critical Actions (Must Rollback)
- Message send/edit/delete to Firestore
- User authentication
- Payment processing

### Best-Effort Actions (No Rollback)
- Read receipts
- Typing indicators
- Presence updates
- Analytics events

### Hybrid Actions (Conditional Rollback)
```swift
catch {
    if isNetworkError(error) {
        // Transient error - queue for retry, don't rollback
        failedMessageStore.save(message)
    } else if isAuthError(error) {
        // Permanent error - rollback and show error
        messages.removeAll { $0.id == message.id }
        errorMessage = "Authentication failed"
    }
}
```

## Testing Pattern

```swift
func testOptimisticUI_UpdatesImmediately() async throws {
    // Given
    let startCount = sut.messages.count

    // When - Mock repository to delay 2 seconds
    mockRepo.shouldDelay = true
    await sut.sendMessage()

    // Then - Message appears immediately (< 100ms)
    XCTAssertEqual(sut.messages.count, startCount + 1)
    XCTAssertEqual(sut.messages.last?.status, .sending)
}

func testOptimisticUI_RollbackOnFailure() async throws {
    // Given
    mockRepo.shouldFail = true
    let originalMessage = sut.messages[0]

    // When
    await sut.saveEdit()

    // Then - Reverted to original
    XCTAssertEqual(sut.messages[0].text, originalMessage.text)
}
```

## Common Pitfalls

❌ **Forgetting array reassignment**
```swift
messages[index].status = .read  // SwiftUI won't update
```

❌ **Rolling back best-effort operations**
```swift
catch {
    messages.removeAll { $0.readBy.contains(userId) }  // Too aggressive
}
```

❌ **Not clearing input fields**
```swift
messages.append(message)
// ❌ Forgot: messageText = ""
```

❌ **Updating status too late**
```swift
try await repository.sendMessage(message)
messages.append(message)  // ❌ Should append BEFORE await
```

## Key Takeaways

1. ✅ **Update UI first, persist second** - Users expect instant feedback
2. ✅ **Reassign arrays** - In-place mutations don't trigger @Published
3. ✅ **Rollback selectively** - Only for critical failures
4. ✅ **Clear inputs immediately** - Don't wait for server confirmation
5. ✅ **Use status enums** - .sending → .sent → .delivered → .read progression
6. ✅ **Test optimistic updates** - Verify UI updates before await completes
