# Read Receipts Implementation Pattern

**Story:** 2.5 - Read Receipts
**Date:** 2025-10-22
**Status:** ✅ Complete

## Architecture Pattern

Read receipts follow Clean Architecture with three layers:

### 1. Domain Layer (Protocol)
```swift
// MessageRepositoryProtocol.swift
func markMessagesAsRead(messageIds: [String], userId: String) async throws
```

### 2. Data Layer (Firebase Implementation)
```swift
// FirebaseMessageRepository.swift
func markMessagesAsRead(messageIds: [String], userId: String) async throws {
    let batch = db.batch()  // ✅ Use batch writes for atomic operations

    for messageId in messageIds {
        let messageRef = db.collection("messages").document(messageId)
        batch.updateData([
            "readBy": FieldValue.arrayUnion([userId]),      // ✅ Atomic array update
            "readCount": FieldValue.increment(Int64(1)),    // ✅ Atomic increment
            "status": MessageStatus.read.rawValue,
            "statusUpdatedAt": FieldValue.serverTimestamp() // ✅ Server time
        ], forDocument: messageRef)
    }

    try await batch.commit()
}
```

**Key Points:**
- ✅ Use `FieldValue.arrayUnion()` for atomic array updates (prevents duplicates)
- ✅ Use `FieldValue.increment()` for atomic counters
- ✅ Use `FieldValue.serverTimestamp()` to avoid clock skew
- ✅ Use batch writes when updating multiple documents

### 3. Presentation Layer (ViewModel)

**Optimistic UI Pattern:**
```swift
// ChatViewModel.swift
func markMessagesAsRead() async {
    let unreadMessages = messages.filter { message in
        !message.readBy.contains(currentUserId) && message.senderId != currentUserId
    }

    // 1. UPDATE LOCAL STATE IMMEDIATELY (Optimistic UI)
    for id in messageIds {
        if let index = messages.firstIndex(where: { $0.id == id }) {
            var updatedMessage = messages[index]
            updatedMessage.readBy.append(currentUserId)
            updatedMessage.readCount += 1

            if updatedMessage.status.canTransitionTo(.read) {
                updatedMessage.status = .read
            }

            var updated = messages
            updated[index] = updatedMessage
            messages = updated  // ✅ Reassign array to trigger @Published
        }
    }

    // 2. PERSIST TO FIRESTORE (background)
    do {
        try await messageRepository.markMessagesAsRead(messageIds: messageIds, userId: currentUserId)
    } catch {
        // ⚠️ DON'T rollback - read receipts are best-effort
        print("Failed to mark as read: \(error)")
    }
}
```

**Lifecycle Integration:**
```swift
func onAppear() {
    ChatViewModel.currentlyViewingConversationId = conversationId
    Task {
        await markMessagesAsRead()  // ✅ Auto-mark on view appear
    }
}
```

## Group Chat Read Count Display

**MessageKit Integration:**
```swift
// ChatView.swift - messageBottomLabelAttributedText
if actualMessage.status == .read && viewModel.isGroupConversation {
    let totalParticipants = viewModel.participants.count - 1  // Exclude sender
    let readCount = actualMessage.readBy.count
    statusText = "✓✓ Read by \(readCount) of \(totalParticipants)"
    statusColor = .systemBlue
}
```

**Visual Indicators:**
- `.sending` → "●" (gray)
- `.sent` → "✓" (gray)
- `.delivered` → "✓✓" (gray)
- `.read` (1-on-1) → "✓✓" (blue)
- `.read` (group) → "✓✓ Read by X of Y" (blue)
- `.failed` → "⚠️ Failed - Tap to retry" (red)

## Read Receipt Detail View (Group Chats)

**Tap Detection:**
```swift
// Detect taps in bottom 30 points of cell (where read receipt is)
if let cell = messagesCollectionView.cellForItem(at: indexPath) as? MessageContentCell {
    let cellTouchPoint = gesture.location(in: cell)
    if cellTouchPoint.y > cell.bounds.height - 30 {
        viewModel.onReadReceiptTapped(message)
    }
}
```

**Modal Sheet:**
```swift
.sheet(item: $viewModel.readReceiptTapped) { message in
    ReadReceiptDetailView(
        message: message,
        participants: viewModel.participants,
        currentUserId: viewModel.currentUserId
    )
}
```

## Status Transition Validation

**Never Allow Downgrades:**
```swift
// MessageStatus.swift
func canTransitionTo(_ newStatus: MessageStatus) -> Bool {
    return newStatus.sortOrder >= self.sortOrder
}

// sortOrder: sending(0) → sent(1) → delivered(2) → read(3)
```

## Offline Queueing

✅ **Automatic** - Firebase SDK handles this:
1. User marks messages as read while offline
2. Firestore queues the batch write locally
3. When online, queued operations execute automatically
4. Real-time listeners propagate changes to all participants

## Testing Patterns

**Unit Test Structure:**
```swift
func testMarkMessagesAsRead_FiltersOwnMessages() async throws {
    // Given: 5 messages (2 from user, 3 from others)
    mockMessageRepo.mockMessages = [
        Message(senderId: "user1", readBy: []),
        Message(senderId: "user1", readBy: []),
        Message(senderId: "user2", readBy: []),
        Message(senderId: "user3", readBy: []),
        Message(senderId: "user4", readBy: [])
    ]

    // When
    await sut.markMessagesAsRead()

    // Then: Only 3 messages marked (own messages excluded)
    XCTAssertEqual(mockMessageRepo.capturedReadMessageIds?.count, 3)
}
```

## Performance Targets

- ✅ Optimistic UI: < 100ms (appears instantly)
- ✅ Firestore persistence: 200-500ms (background)
- ✅ Real-time propagation: < 1 second to sender
- ✅ Batch write: Single network round-trip for multiple messages

## Key Learnings

1. **Always check existing implementation first** - This story was 95% complete already
2. **Optimistic UI is critical** - Read receipts must feel instant
3. **Batch writes are essential** - Marking 10 messages = 1 write, not 10
4. **Status transitions need validation** - Prevent read → delivered downgrades
5. **Real-time listeners handle sync** - No manual refresh needed
6. **Best-effort semantics** - Don't rollback on failure (eventual consistency)
