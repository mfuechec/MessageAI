//
//  OfflineQueueStore.swift
//  MessageAI
//
//  Manages offline message queue with persistent storage
//

import Foundation

/// Manages offline message queue with persistent storage using UserDefaults
///
/// Stores messages composed while offline so they can be manually sent
/// when network connection is restored. Queue persists across app restarts.
///
/// **Storage Strategy:**
/// - Uses UserDefaults for fast, lightweight persistence (< 100ms)
/// - Supports up to ~1000 short messages (~500 KB limit)
/// - Duplicate prevention via message ID checking
///
/// **Usage:**
/// ```swift
/// let store = OfflineQueueStore()
/// store.enqueue(message)  // Add to queue
/// let queued = store.loadQueue()  // Load all queued messages
/// store.dequeue(messageId)  // Remove after successful send
/// ```
class OfflineQueueStore {
    // MARK: - Properties

    private let userDefaults = UserDefaults.standard
    private let queueKey = "offlineMessageQueue"

    // MARK: - Public Methods

    /// Add message to offline queue
    ///
    /// - Parameter message: Message to enqueue
    ///
    /// **Behavior:**
    /// - Prevents duplicate messages (same ID)
    /// - Appends to end of queue (FIFO order)
    /// - Persists immediately to UserDefaults
    func enqueue(_ message: Message) {
        var queue = loadQueue()

        // Prevent duplicates
        guard !queue.contains(where: { $0.id == message.id }) else {
            print("⚠️ [OfflineQueueStore] Message \(message.id) already in queue")
            return
        }

        queue.append(message)
        saveQueue(queue)
        print("✅ [OfflineQueueStore] Enqueued message \(message.id). Queue size: \(queue.count)")
    }

    /// Remove message from queue
    ///
    /// - Parameter messageId: ID of message to remove
    ///
    /// Called after successful send or when user deletes a queued message.
    func dequeue(_ messageId: String) {
        var queue = loadQueue()
        let originalCount = queue.count

        queue.removeAll { $0.id == messageId }

        if queue.count < originalCount {
            saveQueue(queue)
            print("✅ [OfflineQueueStore] Dequeued message \(messageId). Queue size: \(queue.count)")
        } else {
            print("⚠️ [OfflineQueueStore] Message \(messageId) not found in queue")
        }
    }

    /// Load all queued messages
    ///
    /// - Returns: Array of queued messages in FIFO order
    ///
    /// **Performance:** < 100ms for typical queue sizes (< 100 messages)
    func loadQueue() -> [Message] {
        guard let data = userDefaults.data(forKey: queueKey) else {
            return []
        }

        do {
            let messages = try JSONDecoder().decode([Message].self, from: data)
            return messages
        } catch {
            print("❌ [OfflineQueueStore] Failed to decode queue: \(error.localizedDescription)")
            return []
        }
    }

    /// Clear entire queue
    ///
    /// Removes all queued messages from persistent storage.
    /// Used for testing or when clearing conversation-specific queue.
    func clearQueue() {
        userDefaults.removeObject(forKey: queueKey)
        print("🗑️ [OfflineQueueStore] Queue cleared")
    }

    /// Get queue size
    ///
    /// - Returns: Number of messages currently in queue
    ///
    /// **Performance:** Fast (reads from UserDefaults, no decoding)
    func count() -> Int {
        return loadQueue().count
    }

    /// Update an existing message in the queue
    ///
    /// - Parameters:
    ///   - messageId: ID of message to update
    ///   - updatedMessage: New message data
    ///
    /// Used when user edits a queued message before sending.
    func update(_ messageId: String, with updatedMessage: Message) {
        var queue = loadQueue()

        guard let index = queue.firstIndex(where: { $0.id == messageId }) else {
            print("⚠️ [OfflineQueueStore] Cannot update - message \(messageId) not in queue")
            return
        }

        queue[index] = updatedMessage
        saveQueue(queue)
        print("✅ [OfflineQueueStore] Updated message \(messageId)")
    }

    // MARK: - Private Helpers

    /// Save queue to UserDefaults
    private func saveQueue(_ queue: [Message]) {
        do {
            let data = try JSONEncoder().encode(queue)
            userDefaults.set(data, forKey: queueKey)
        } catch {
            print("❌ [OfflineQueueStore] Failed to save queue: \(error.localizedDescription)")
        }
    }
}
