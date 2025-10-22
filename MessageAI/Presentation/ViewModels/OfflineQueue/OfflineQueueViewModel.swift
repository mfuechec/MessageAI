//
//  OfflineQueueViewModel.swift
//  MessageAI
//
//  ViewModel for managing offline message queue
//  Story 2.9: Offline Message Queue with Manual Send
//

import Foundation
import Combine

/// ViewModel for OfflineQueueView - manages queued messages
///
/// Handles per-message actions:
/// - Send individual message
/// - Edit message text before sending
/// - Delete message from queue
/// - Send all messages sequentially
///
/// **Performance:** Loads queue synchronously from UserDefaults (< 100ms)
///
/// **Usage:**
/// ```swift
/// let viewModel = OfflineQueueViewModel(
///     offlineQueueStore: store,
///     messageRepository: repository
/// )
/// ```
@MainActor
class OfflineQueueViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var queuedMessages: [Message] = []
    @Published var selectedMessageForEdit: Message?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // MARK: - Private Properties

    private let offlineQueueStore: OfflineQueueStore
    private let messageRepository: MessageRepositoryProtocol

    // MARK: - Initialization

    init(
        offlineQueueStore: OfflineQueueStore,
        messageRepository: MessageRepositoryProtocol
    ) {
        self.offlineQueueStore = offlineQueueStore
        self.messageRepository = messageRepository

        loadQueue()
    }

    // MARK: - Public Methods

    /// Load queued messages from persistent storage
    func loadQueue() {
        queuedMessages = offlineQueueStore.loadQueue()
        print("📦 [OfflineQueueViewModel] Loaded \(queuedMessages.count) queued message(s)")
    }

    /// Send a single message
    ///
    /// - Parameter message: Message to send
    ///
    /// **Behavior:**
    /// - Updates status to .sending
    /// - Attempts to send to Firebase
    /// - On success: Removes from queue
    /// - On failure: Marks as .failed, keeps in queue
    func sendMessage(_ message: Message) async {
        print("📤 [OfflineQueueViewModel] Sending message \(message.id)")

        // Update status to sending
        if let index = queuedMessages.firstIndex(where: { $0.id == message.id }) {
            queuedMessages[index].status = .sending
            queuedMessages[index].statusUpdatedAt = Date()
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await messageRepository.sendMessage(message)

            // Success: Remove from queue
            offlineQueueStore.dequeue(message.id)
            queuedMessages.removeAll { $0.id == message.id }

            print("✅ [OfflineQueueViewModel] Successfully sent message \(message.id)")

        } catch {
            print("❌ [OfflineQueueViewModel] Failed to send message \(message.id): \(error)")

            // Failure: Mark as failed, keep in queue
            if let index = queuedMessages.firstIndex(where: { $0.id == message.id }) {
                queuedMessages[index].status = .failed
                queuedMessages[index].statusUpdatedAt = Date()

                // Update in store with failed status
                offlineQueueStore.update(message.id, with: queuedMessages[index])
            }

            errorMessage = "Failed to send message: \(error.localizedDescription)"
        }
    }

    /// Send all queued messages sequentially
    ///
    /// Continues sending even if individual messages fail.
    /// Messages are sent in FIFO order (oldest first).
    func sendAllMessages() async {
        guard !queuedMessages.isEmpty else { return }

        print("📤 [OfflineQueueViewModel] Sending all \(queuedMessages.count) queued messages...")

        // Create snapshot of messages to send (in case queue changes during sending)
        let messagesToSend = queuedMessages

        for message in messagesToSend {
            await sendMessage(message)
        }

        print("✅ [OfflineQueueViewModel] Finished sending all queued messages")
    }

    /// Edit message text
    ///
    /// - Parameters:
    ///   - message: Message to edit
    ///   - newText: Updated message text
    ///
    /// Updates message in both queuedMessages array and persistent store.
    func editMessage(_ message: Message, newText: String) {
        guard let index = queuedMessages.firstIndex(where: { $0.id == message.id }) else {
            print("⚠️ [OfflineQueueViewModel] Cannot edit - message \(message.id) not found")
            return
        }

        // Update message text
        var updatedMessage = queuedMessages[index]
        updatedMessage.text = newText

        queuedMessages[index] = updatedMessage

        // Update in persistent store
        offlineQueueStore.update(message.id, with: updatedMessage)

        print("✅ [OfflineQueueViewModel] Edited message \(message.id)")
    }

    /// Delete message from queue
    ///
    /// - Parameter message: Message to delete
    ///
    /// Removes from both queuedMessages array and persistent store.
    func deleteMessage(_ message: Message) {
        offlineQueueStore.dequeue(message.id)
        queuedMessages.removeAll { $0.id == message.id }

        print("🗑️ [OfflineQueueViewModel] Deleted message \(message.id)")
    }
}
