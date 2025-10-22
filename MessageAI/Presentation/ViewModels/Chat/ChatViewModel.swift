import Foundation
import Combine
import UIKit
import FirebaseFirestore

/// Metadata for queued offline uploads (stored in UserDefaults)
struct OfflineUploadMetadata: Codable {
    let messageId: String
    let conversationId: String
    let timestamp: Date
    let filePath: String  // Relative path from temp directory
}

/// Error types for image upload operations
enum ImageUploadError: LocalizedError {
    case invalidImageData

    var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "Invalid image data"
        }
    }
}

/// ViewModel for managing chat messages and message sending
@MainActor
class ChatViewModel: ObservableObject {
    
    // MARK: - Published Properties

    @Published var messages: [Message] = []
    @Published var messageText: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var isOffline: Bool = false
    @Published var isSending: Bool = false
    @Published var users: [String: User] = [:]
    @Published var conversation: Conversation?
    @Published var participants: [User] = []
    
    // Edit mode state
    @Published var isEditingMessage: Bool = false
    @Published var editingMessageId: String? = nil
    @Published var editingMessageText: String = ""
    
    // Edit history modal state
    @Published var showEditHistoryModal: Bool = false
    @Published var editHistoryMessage: Message? = nil
    
    // Delete confirmation state
    @Published var showDeleteConfirmation: Bool = false
    @Published var messageToDelete: Message? = nil
    
    // Read receipt detail state (for group chats)
    @Published var readReceiptTapped: Message? = nil
    
    // Force UI refresh for message edits (when count doesn't change)
    @Published var messagesNeedRefresh: Bool = false
    
    // Failed message handling
    @Published var retryingMessageId: String?  // Track retry in progress
    @Published var failedMessageTapped: Message?

    // Offline queue handling (Story 2.9)
    @Published var queuedMessages: [Message] = []
    @Published var showConnectivityToast: Bool = false

    // Typing indicator state
    @Published var typingUserNames: [String] = []

    // Image upload state
    @Published var uploadProgress: [String: Double] = [:]
    @Published var uploadErrors: [String: String] = [:]
    @Published var isImagePickerPresented: Bool = false
    @Published var selectedImage: UIImage?
    @Published var selectedImageURL: String?  // For full-screen viewer

    // Document upload state
    @Published var isDocumentPickerPresented: Bool = false
    @Published var selectedDocumentURL: URL?
    @Published var showDocumentPreview: Bool = false
    @Published var documentPreviewURL: URL?

    // Track loading states separately
    private var messagesLoaded: Bool = false
    private var participantsLoaded: Bool = false
    
    // MARK: - Public Properties
    
    let currentUserId: String  // Exposed for ChatView title filtering
    
    // MARK: - Private Properties
    
    private let conversationId: String
    let messageRepository: MessageRepositoryProtocol  // Story 2.9: Expose for OfflineQueueViewModel
    private let conversationRepository: ConversationRepositoryProtocol
    private let userRepository: UserRepositoryProtocol
    private let storageRepository: StorageRepositoryProtocol
    private let networkMonitor: any NetworkMonitorProtocol
    private var cancellables = Set<AnyCancellable>()
    private let failedMessageStore = FailedMessageStore()
    let offlineQueueStore: OfflineQueueStore  // Story 2.9: Expose for OfflineQueueViewModel

    // Typing indicator private state
    private var typingThrottleTimer: Timer?
    private var typingAutoStopTimer: Timer?
    private var isCurrentlyTyping: Bool = false
    private var lastTypingUpdateTime: Date = .distantPast

    // Offline queue management
    private let offlineQueueKey = "offlineImageUploads_metadata"

    // MARK: - Initialization
    
    init(
        conversationId: String,
        currentUserId: String,
        messageRepository: MessageRepositoryProtocol,
        conversationRepository: ConversationRepositoryProtocol,
        userRepository: UserRepositoryProtocol,
        storageRepository: StorageRepositoryProtocol,
        networkMonitor: any NetworkMonitorProtocol = NetworkMonitor(),
        offlineQueueStore: OfflineQueueStore = OfflineQueueStore(),
        initialConversation: Conversation? = nil,
        initialParticipants: [User]? = nil
    ) {
        self.conversationId = conversationId
        self.currentUserId = currentUserId
        self.messageRepository = messageRepository
        self.conversationRepository = conversationRepository
        self.userRepository = userRepository
        self.storageRepository = storageRepository
        self.networkMonitor = networkMonitor
        self.offlineQueueStore = offlineQueueStore
        
        // If we have initial data, use it immediately (no loading needed for participants)
        if let conv = initialConversation, let parts = initialParticipants {
            self.conversation = conv
            self.participants = parts
            for user in parts {
                self.users[user.id] = user
            }
            self.participantsLoaded = true
            print("✅ ChatViewModel initialized with cached data (no fetch needed)")
        } else {
            // No initial data, will need to load participants
            self.isLoading = true
            loadParticipantUsers()
        }
        
        // Load failed messages from local persistence
        loadFailedMessages()

        // Load queued messages from offline queue (Story 2.9)
        loadQueuedMessages()

        // Always observe messages (async)
        observeMessages()
        observeTypingUsers()
        observeNetworkStatus()
        setupNetworkMonitoring()
        observeConnectivity()  // Story 2.9: Watch for offline → online transitions
    }
    
    // MARK: - Private Methods
    
    private func observeMessages() {
        messageRepository.observeMessages(conversationId: conversationId)
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)  // Batch rapid-fire updates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] messages in
                guard let self = self else { return }
                print("🔄 [ChatViewModel] Messages updated: \(messages.count) messages")

                let sortedMessages = messages.sorted { $0.timestamp < $1.timestamp }

                // CRITICAL: Preserve local state for failed messages (Story 2.4)
                // Failed messages never made it to Firestore, so we need to merge them
                let failedMessages = self.messages.filter { $0.status == .failed }
                let localMessageMap = Dictionary(uniqueKeysWithValues: self.messages.map { ($0.id, $0) })
                let firestoreMessageIds = Set(sortedMessages.map { $0.id })
                let localOnlyFailedMessages = failedMessages.filter { !firestoreMessageIds.contains($0.id) }

                if !localOnlyFailedMessages.isEmpty {
                    print("💾 [ChatViewModel] Preserving \(localOnlyFailedMessages.count) local-only failed message(s)")
                }

                // Merge Firestore messages, preserving local .failed status
                var mergedMessages: [Message] = sortedMessages.map { firestoreMessage in
                    if let localMessage = localMessageMap[firestoreMessage.id],
                       localMessage.status == .failed {
                        return localMessage  // Keep failed status
                    }
                    return firestoreMessage
                }

                // Add local-only failed messages
                mergedMessages.append(contentsOf: localOnlyFailedMessages)
                mergedMessages.sort { $0.timestamp < $1.timestamp }

                // CRITICAL: Detect if message content changed but count stayed same
                // This happens when messages are edited, deleted, or read status changes
                if self.messages.count == mergedMessages.count && self.messages.count > 0 {
                    // Check if any message content changed (edited, deleted, or status updated)
                    let contentChanged = zip(self.messages, mergedMessages).contains { old, new in
                        old.text != new.text ||
                        old.isEdited != new.isEdited ||
                        old.isDeleted != new.isDeleted ||
                        old.status != new.status ||          // ← Read receipt status changes
                        old.readBy != new.readBy ||          // ← Read receipt array changes
                        old.readCount != new.readCount       // ← Read receipt count changes
                    }

                    if contentChanged {
                        print("📝 [ChatViewModel] Message content changed (edit/delete/status), forcing UI refresh")
                        self.messagesNeedRefresh = true
                    }
                }

                self.messages = mergedMessages
                self.messagesLoaded = true
                self.updateLoadingState()

                // Mark messages as read when they load (if user is viewing)
                if AppState.shared.currentlyViewingConversationId == self.conversationId {
                    print("📖 [ChatViewModel] Messages loaded while viewing - marking as read")
                    Task {
                        await self.markMessagesAsRead()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func loadParticipantUsers() {
        Task {
            do {
                // Get conversation to find participant IDs
                let loadedConversation = try await conversationRepository.getConversation(id: conversationId)
                conversation = loadedConversation
                
                // Load all participant users (including current user for group display)
                let loadedUsers = try await userRepository.getUsers(ids: loadedConversation.participantIds)
                participants = loadedUsers
                
                // Also populate users dictionary for quick lookup
                for user in loadedUsers {
                    users[user.id] = user
                }
                
                participantsLoaded = true
                updateLoadingState()
                
                print("✅ Loaded \(loadedUsers.count) participants for conversation \(conversationId)")
            } catch {
                print("❌ Failed to load conversation participants: \(error)")
                participantsLoaded = true // Mark as "loaded" even on error to unblock UI
                updateLoadingState()
            }
        }
    }
    
    /// Updates isLoading based on both loading states
    private func updateLoadingState() {
        // Only set loading to false when BOTH messages and participants are loaded
        isLoading = !(messagesLoaded && participantsLoaded)
    }
    
    private func setupNetworkMonitoring() {
        networkMonitor.isConnectedPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                guard let self = self else { return }
                let wasOffline = self.isOffline
                self.isOffline = !isConnected
                print("🌐 [ChatViewModel] Network status changed: isConnected=\(isConnected), isOffline=\(self.isOffline)")
                if wasOffline != self.isOffline {
                    print("   State changed: wasOffline=\(wasOffline) → isOffline=\(self.isOffline)")
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// Sends a message with input validation and optimistic UI
    func sendMessage() async {
        // Clear typing indicator immediately
        stopTyping()

        // 1. Sanitize and validate input
        let trimmedText = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Validate not empty
        guard !trimmedText.isEmpty else { return }
        
        // Enforce maximum length
        guard trimmedText.count <= 10000 else {
            errorMessage = "Message too long (max 10,000 characters)"
            return
        }
        
        // 2. Check if offline (Story 2.9) - if so, queue message instead of sending
        let isCurrentlyOffline = !networkMonitor.isConnected

        // 3. Create Message entity with appropriate status
        let message = Message(
            id: UUID().uuidString,
            conversationId: conversationId,
            senderId: currentUserId,
            text: trimmedText,
            timestamp: Date(),
            status: isCurrentlyOffline ? .queued : .sending,  // Story 2.9: queue if offline
            statusUpdatedAt: Date(),
            attachments: [],
            editHistory: nil,
            editCount: 0,
            isEdited: false,
            isDeleted: false,
            deletedAt: nil,
            deletedBy: nil,
            readBy: [currentUserId], // Mark as read by sender
            readCount: 1,
            isPriority: false,
            priorityReason: nil,
            schemaVersion: 1
        )

        // 4. Optimistic UI: Append message immediately
        messages.append(message)
        messageText = "" // Clear input

        // 5. If offline, enqueue and return early (Story 2.9)
        if isCurrentlyOffline {
            offlineQueueStore.enqueue(message)
            queuedMessages.append(message)
            print("⚠️ [ChatViewModel] Offline: Message queued (\(queuedMessages.count) total)")
            return
        }

        // 6. Send to Firestore (only if online)
        isSending = true
        defer { isSending = false }

        do {
            // Send message
            try await messageRepository.sendMessage(message)

            // Update message status to .sent (Firestore listener will handle this)
            if let index = messages.firstIndex(where: { $0.id == message.id }) {
                var updatedMessage = messages[index]
                updatedMessage.status = .sent
                updatedMessage.statusUpdatedAt = Date()

                // Reassign array to trigger @Published
                var updated = messages
                updated[index] = updatedMessage
                messages = updated
            }

            // Update conversation's last message fields
            try await updateConversation(with: message)
            
        } catch {
            print("❌ [ChatViewModel] Message send failed: \(error)")

            // On failure: mark message as failed, keep in array
            if let index = messages.firstIndex(where: { $0.id == message.id }) {
                var failedMessage = messages[index]
                failedMessage.status = .failed
                failedMessage.statusUpdatedAt = Date()

                // Reassign array to trigger @Published
                var updated = messages
                updated[index] = failedMessage
                messages = updated

                print("💾 [ChatViewModel] Message marked as failed and saved locally")
            }

            // Save failed message to local persistence
            saveFailedMessageLocally(message)

            // Detect offline state from error (workaround for simulator)
            // NWPathMonitor doesn't work in simulator with Network Link Conditioner
            if let nsError = error as? NSError,
               nsError.domain == NSURLErrorDomain,
               (nsError.code == NSURLErrorNotConnectedToInternet ||
                nsError.code == NSURLErrorNetworkConnectionLost ||
                nsError.code == NSURLErrorTimedOut) {
                print("🌐 [ChatViewModel] Detected offline state from error (simulator workaround)")
                isOffline = true
            }

            // Show user-friendly error
            errorMessage = mapErrorToUserMessage(error)
            print("❌ Message failed: \(error)")
        }
    }
    
    /// Updates the conversation with the latest message information
    private func updateConversation(with message: Message) async throws {
        do {
            try await conversationRepository.updateConversation(
                id: conversationId,
                updates: [
                    "lastMessage": message.text,
                    "lastMessageTimestamp": message.timestamp,
                    "lastMessageSenderId": currentUserId,
                    "lastMessageId": message.id
                ]
            )
        } catch {
            // Non-critical error: log but don't show to user
            print("Failed to update conversation last message: \(error)")
        }
    }
    
    /// Clears the current error message
    func clearError() {
        errorMessage = nil
    }
    
    /// Loads more messages for pagination (stub for future implementation)
    func loadMoreMessages() async {
        // Pagination implementation deferred to Story 2.x (Performance Optimization)
        // For MVP, all messages are loaded via the real-time listener
    }
    
    // MARK: - Group Chat Helpers
    
    /// Computed property indicating if this is a group conversation
    var isGroupConversation: Bool {
        return conversation?.isGroup ?? false
    }
    
    /// Returns the sender name for a message (used in group chats)
    /// - Parameter senderId: The ID of the message sender
    /// - Returns: "You" if current user, otherwise the user's display name
    func getSenderName(for senderId: String) -> String {
        if senderId == currentUserId {
            return "You"
        }
        return users[senderId]?.displayName ?? "Unknown User"
    }
    
    /// Returns the other participant's name (for one-on-one chats)
    var otherParticipantName: String? {
        guard let conversation = conversation, !conversation.isGroup else {
            return nil
        }
        let otherParticipantId = conversation.participantIds.first { $0 != currentUserId }
        return otherParticipantId.flatMap { users[$0]?.displayName }
    }
    
    // MARK: - Display Helper Methods
    
    /// Returns the display name for a given user ID
    func displayName(for userId: String) -> String {
        if userId == currentUserId {
            return "You"
        }
        return users[userId]?.displayName ?? "Unknown"
    }
    
    /// Returns the formatted timestamp for a message
    func formattedTimestamp(for message: Message) -> String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(message.timestamp)
        
        // Handle very recent messages (< 1 minute) - show "now"
        if timeInterval >= -1 && timeInterval < 60 {
            return "now"
        }
        
        // For timestamps in the future (due to server time skew), treat as "now"
        if timeInterval < 0 {
            return "now"
        }
        
        // Use RelativeDateTimeFormatter for older messages
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: message.timestamp, relativeTo: now)
    }
    
    // MARK: - Message Editing
    
    /// Initiates edit mode for a message
    /// Only allows editing of own messages
    func startEdit(message: Message) {
        guard message.senderId == currentUserId else {
            print("⚠️ Cannot edit message from another user")
            return
        }
        editingMessageId = message.id
        editingMessageText = message.text
        isEditingMessage = true
        print("✏️ Started editing message: \(message.id)")
    }
    
    /// Cancels edit mode and clears edit state
    func cancelEdit() {
        isEditingMessage = false
        editingMessageId = nil
        editingMessageText = ""
        print("🚪 Closed edit mode")
    }
    
    /// Saves the edited message with validation and optimistic UI
    func saveEdit() async {
        // 1. Input validation: trim whitespace
        let trimmedText = editingMessageText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 2. Guard against empty text
        guard !trimmedText.isEmpty else {
            errorMessage = "Message cannot be empty"
            print("⚠️ Edit rejected: empty text")
            cancelEdit()
            return
        }
        
        // 3. Enforce maximum length
        guard trimmedText.count <= 10000 else {
            errorMessage = "Message is too long. Please keep it under 10,000 characters."
            print("❌ Edit rejected: message too long (\(trimmedText.count) chars)")
            cancelEdit()
            return
        }
        
        // 4. Verify we have a message ID
        guard let messageId = editingMessageId else {
            errorMessage = "Unable to edit message. Please try again."
            print("❌ Edit failed: no message ID")
            return
        }
        
        // 5. Find message in local array
        guard let index = messages.firstIndex(where: { $0.id == messageId }) else {
            errorMessage = "Message not found. It may have been deleted."
            print("❌ Edit failed: message not found in array")
            cancelEdit()
            return
        }
        
        // 6. Check if text actually changed
        let originalMessage = messages[index]
        if originalMessage.text == trimmedText {
            print("ℹ️ Text unchanged, closing edit mode")
            cancelEdit()
            return
        }
        
        // 7. Optimistic UI: Update message immediately
        var updatedMessage = originalMessage
        updatedMessage.text = trimmedText
        updatedMessage.isEdited = true
        
        // CRITICAL: Reassign entire array to trigger @Published change detection
        var updatedMessages = messages
        updatedMessages[index] = updatedMessage
        messages = updatedMessages
        messagesNeedRefresh = true  // Force UI reload even though count didn't change
        print("✏️ Optimistic update: message \(messageId) updated locally")
        
        // 8. Clear edit mode
        let savedMessageId = messageId  // Save before cancelEdit clears it
        cancelEdit()
        
        // 9. Call repository to persist edit
        do {
            try await messageRepository.editMessage(id: savedMessageId, newText: trimmedText)
            print("✅ Message edited successfully: \(savedMessageId)")
            
            // Update conversation's lastMessage if this was the most recent message
            if let conversation = conversation, 
               conversation.lastMessage == originalMessage.text {
                await updateConversationLastMessage(with: trimmedText)
            }
        } catch {
            // Rollback optimistic update on failure
            var rollbackMessages = messages
            if let rollbackIndex = rollbackMessages.firstIndex(where: { $0.id == savedMessageId }) {
                rollbackMessages[rollbackIndex] = originalMessage
                messages = rollbackMessages
                print("↩️ Rolled back optimistic update for message \(savedMessageId)")
            }
            
            // Show user-friendly error message
            if let repoError = error as? RepositoryError {
                switch repoError {
                case .networkError:
                    errorMessage = "No internet connection. Please check your network and try again."
                case .unauthorized:
                    errorMessage = "You don't have permission to edit this message."
                case .messageNotFound:
                    errorMessage = "Message not found. It may have been deleted."
                case .invalidInput:
                    errorMessage = "Invalid message content. Please try again."
                default:
                    errorMessage = "Unable to save changes. Please try again."
                }
            } else {
                errorMessage = "Unable to save changes. Please try again."
            }
            print("❌ Edit message error: \(error)")
        }
    }
    
    /// Updates the conversation's lastMessage field when the most recent message is edited
    private func updateConversationLastMessage(with newText: String) async {
        guard let conversation = conversation else { return }
        
        do {
            let updates: [String: Any] = [
                "lastMessage": newText,
                "lastMessageTimestamp": Date()
            ]
            try await conversationRepository.updateConversation(id: conversation.id, updates: updates)
            print("✅ Updated conversation lastMessage after edit")
        } catch {
            print("⚠️ Failed to update conversation lastMessage: \(error)")
            // Non-critical failure - don't show error to user
        }
    }
    
    // MARK: - Edit History
    
    /// Shows the edit history modal for a message
    func showEditHistory(for message: Message) {
        editHistoryMessage = message
        showEditHistoryModal = true
        print("📜 Showing edit history for message: \(message.id)")
    }
    
    /// Closes the edit history modal
    func closeEditHistory() {
        showEditHistoryModal = false
        editHistoryMessage = nil
        print("📜 Closed edit history")
    }
    
    // MARK: - Message Deletion
    
    /// Checks if a message can be deleted (own message, within 24 hours, not already deleted)
    func canDelete(message: Message) -> Bool {
        guard message.senderId == currentUserId else { return false }
        guard !message.isDeleted else { return false }
        
        let hoursSinceSent = Date().timeIntervalSince(message.timestamp) / 3600
        return hoursSinceSent < 24
    }
    
    /// Shows delete confirmation alert
    func showDeleteConfirmation(for message: Message) {
        guard canDelete(message: message) else {
            if message.senderId != currentUserId {
                errorMessage = "You can only delete your own messages"
            } else if message.isDeleted {
                errorMessage = "This message has already been deleted"
            } else {
                errorMessage = "Messages can only be deleted within 24 hours"
            }
            return
        }
        
        messageToDelete = message
        showDeleteConfirmation = true
    }
    
    /// Cancels delete action
    func cancelDelete() {
        showDeleteConfirmation = false
        messageToDelete = nil
    }
    
    /// Deletes message with optimistic UI
    func confirmDelete() async {
        guard let message = messageToDelete else { return }
        
        // Find message in local array
        guard let index = messages.firstIndex(where: { $0.id == message.id }) else {
            errorMessage = "Message not found"
            cancelDelete()
            return
        }
        
        // Store original message for rollback on error
        let originalMessage = messages[index]
        
        // Optimistic UI: Mark as deleted immediately
        var deletedMessage = originalMessage
        deletedMessage.isDeleted = true
        deletedMessage.deletedAt = Date()
        deletedMessage.deletedBy = currentUserId
        deletedMessage.text = "" // Clear text locally
        
        // CRITICAL: Reassign entire array to trigger @Published change detection
        var updatedMessages = messages
        updatedMessages[index] = deletedMessage
        messages = updatedMessages
        messagesNeedRefresh = true  // Force UI reload
        
        print("🗑️ Optimistic delete: message \(message.id) marked as deleted locally")
        
        // Clear confirmation state immediately for instant UX
        cancelDelete()
        
        // Call repository
        do {
            try await messageRepository.deleteMessage(id: message.id)
            print("✅ Message deleted successfully: \(message.id)")
            
            // Update conversation preview with most recent message
            // Check if deleted message is the most recent by comparing with current messages array
            let sortedMessages = messages.sorted { $0.timestamp > $1.timestamp }
            if let mostRecentMessage = sortedMessages.first, mostRecentMessage.id == message.id {
                print("🔄 Deleted message was most recent, updating conversation preview")
                try await updateConversationAfterDelete()
            }
            
        } catch {
            // Rollback optimistic update on failure
            var rollbackMessages = messages
            rollbackMessages[index] = originalMessage
            messages = rollbackMessages
            
            // Show user-friendly error message
            if let repoError = error as? RepositoryError {
                switch repoError {
                case .networkError:
                    errorMessage = "No internet connection. Please check your network and try again."
                case .unauthorized:
                    errorMessage = "You don't have permission to delete this message."
                case .messageNotFound:
                    errorMessage = "Message not found. It may have already been deleted."
                default:
                    errorMessage = "Unable to delete message. Please try again."
                }
            } else {
                errorMessage = "Unable to delete message. Please try again."
            }
            print("❌ Delete message error: \(error)")
        }
    }
    
    /// Updates conversation last message after deleting the most recent message
    private func updateConversationAfterDelete() async throws {
        print("🔄 [updateConversationAfterDelete] Starting update for conversation: \(conversationId)")
        print("  📝 Setting lastMessage to: [Message deleted]")
        
        try await conversationRepository.updateConversation(
            id: conversationId,
            updates: [
                "lastMessage": "[Message deleted]"
            ]
        )
        print("✅ [updateConversationAfterDelete] Firestore update completed")
        print("  💡 ConversationsListViewModel listener should fire now...")
    }
    
    // MARK: - Lifecycle Methods (for notification suppression)

    /// Called when ChatView appears
    ///
    /// Sets AppState.currentlyViewingConversationId to suppress
    /// push notifications for messages in this conversation.
    /// Also marks unread messages as read.
    func onAppear() {
        AppState.shared.currentlyViewingConversationId = conversationId
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("👀 [LIFECYCLE] ChatView.onAppear()")
        print("   Conversation ID: \(conversationId)")
        print("   Current User: \(currentUserId)")
        print("   Messages loaded: \(messages.count)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        // Mark messages as read (AC #1, #5)
        Task {
            await markMessagesAsRead()
        }
    }
    
    /// Called when ChatView disappears
    ///
    /// Clears AppState.currentlyViewingConversationId to allow
    /// push notifications again when user leaves the conversation.
    func onDisappear() {
        // Clear typing indicator when leaving chat
        stopTyping()

        // Cancel all active uploads
        for messageId in uploadProgress.keys {
            Task {
                try? await storageRepository.cancelUpload(for: messageId)
            }
        }

        if AppState.shared.currentlyViewingConversationId == conversationId {
            AppState.shared.currentlyViewingConversationId = nil
            print("👋 Left conversation: \(conversationId)")
        }
    }
    
    // MARK: - Read Receipts
    
    /// Triggered when user taps read receipt in group chat (AC #7)
    func onReadReceiptTapped(_ message: Message) {
        readReceiptTapped = message
    }
    
    /// Mark all unread messages in conversation as read (AC #1, #4, #5)
    func markMessagesAsRead() async {
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("📖 [READ RECEIPTS] markMessagesAsRead() called")
        print("   Current User ID: \(currentUserId)")
        print("   Total Messages: \(messages.count)")
        
        // Debug: Show all messages and their read status
        for (index, msg) in messages.enumerated() {
            print("   Message [\(index)]: id=\(msg.id.prefix(8))... sender=\(msg.senderId.prefix(8))... status=\(msg.status) readBy=\(msg.readBy.count) users")
        }
        
        // Find messages not yet read by current user (AC #2.3 - filter logic)
        let unreadMessages = messages.filter { message in
            !message.readBy.contains(currentUserId) && message.senderId != currentUserId
        }
        
        print("   Unread Messages (not from self): \(unreadMessages.count)")
        
        guard !unreadMessages.isEmpty else {
            print("📖 No unread messages to mark")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            return
        }
        
        let messageIds = unreadMessages.map { $0.id }
        
        print("📖 Marking \(messageIds.count) messages as read:")
        for id in messageIds {
            print("     - \(id.prefix(12))...")
        }
        
        // Optimistic UI: Update local array immediately (AC #9 - fast UX)
        for id in messageIds {
            if let index = messages.firstIndex(where: { $0.id == id }) {
                var updatedMessage = messages[index]
                let oldStatus = updatedMessage.status
                
                // Add current user to readBy array
                if !updatedMessage.readBy.contains(currentUserId) {
                    updatedMessage.readBy.append(currentUserId)
                    updatedMessage.readCount += 1
                }
                
                // Upgrade status to .read if possible (AC #10 - canTransitionTo)
                if updatedMessage.status.canTransitionTo(.read) {
                    updatedMessage.status = .read
                    updatedMessage.statusUpdatedAt = Date()
                    print("   ✅ Updated message \(id.prefix(8))... status: \(oldStatus) → \(updatedMessage.status)")
                } else {
                    print("   ⚠️ Cannot transition message \(id.prefix(8))... from \(oldStatus) to .read")
                }
                
                var updated = messages
                updated[index] = updatedMessage
                messages = updated
            }
        }
        
        print("   Local array updated (optimistic UI)")
        
        // Persist to Firestore (offline-queued if no connection) (AC #8)
        do {
            print("   🔄 Calling repository.markMessagesAsRead()...")
            try await messageRepository.markMessagesAsRead(messageIds: messageIds, userId: currentUserId)
            print("✅ Messages marked as read in Firestore")
        } catch {
            // Non-critical error: Firestore listener will eventually sync
            print("⚠️ Failed to mark messages as read: \(error.localizedDescription)")
            // Don't rollback optimistic update - read receipts are best-effort
        }
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }
    
    // MARK: - Failed Message Retry
    
    /// Retry sending a failed message
    func retryMessage(_ message: Message) async {
        guard message.status == .failed else {
            print("⚠️ Cannot retry message that isn't failed")
            return
        }

        print("🔄 [ChatViewModel] Retrying message: \(message.id)")
        retryingMessageId = message.id
        defer { retryingMessageId = nil }

        // 1. Update status to .sending (optimistic UI)
        if let index = messages.firstIndex(where: { $0.id == message.id }) {
            var retryingMessage = messages[index]
            retryingMessage.status = .sending
            retryingMessage.statusUpdatedAt = Date()

            var updated = messages
            updated[index] = retryingMessage
            messages = updated
        }

        // 2. Prepare message with .sent status for Firestore
        var messageToSend = message
        messageToSend.status = .sent  // Mark as sent BEFORE sending to Firestore
        messageToSend.statusUpdatedAt = Date()

        // 3. Attempt to send
        do {
            try await messageRepository.sendMessage(messageToSend)

            // Success: Update local status to .sent
            if let index = messages.firstIndex(where: { $0.id == message.id }) {
                var sentMessage = messages[index]
                sentMessage.status = .sent
                sentMessage.statusUpdatedAt = Date()

                var updated = messages
                updated[index] = sentMessage
                messages = updated
            }
            
            // Remove from failed messages store
            failedMessageStore.remove(message.id)
            
            // Update conversation
            try await updateConversation(with: message)
            
            print("✅ Retry successful: \(message.id)")
            
        } catch {
            // Retry failed: Mark as failed again
            if let index = messages.firstIndex(where: { $0.id == message.id }) {
                var failedMessage = messages[index]
                failedMessage.status = .failed
                failedMessage.statusUpdatedAt = Date()
                
                var updated = messages
                updated[index] = failedMessage
                messages = updated
            }
            
            errorMessage = mapErrorToUserMessage(error)
            print("❌ Retry failed: \(error)")
        }
    }
    
    /// Delete a failed message permanently
    func deleteFailedMessage(_ message: Message) {
        print("🗑️ Deleting failed message: \(message.id)")
        
        // Remove from messages array
        messages.removeAll { $0.id == message.id }
        
        // Remove from local persistence
        failedMessageStore.remove(message.id)
        
        print("✅ Failed message deleted")
    }
    
    /// Triggered when user taps failed message
    func onFailedMessageTapped(_ message: Message) {
        failedMessageTapped = message
    }
    
    // MARK: - Failed Message Helpers
    
    /// Load failed messages from local persistence on init
    private func loadFailedMessages() {
        let failedMessages = failedMessageStore.loadAll()
        
        // Filter to only messages for this conversation
        let conversationFailedMessages = failedMessages.filter { $0.conversationId == conversationId }
        
        if !conversationFailedMessages.isEmpty {
            print("💾 Loaded \(conversationFailedMessages.count) failed message(s) from local storage")
            
            // Add to messages array if not already present
            for failedMessage in conversationFailedMessages {
                if !messages.contains(where: { $0.id == failedMessage.id }) {
                    messages.append(failedMessage)
                }
            }
            
            // Sort by timestamp
            messages.sort { $0.timestamp < $1.timestamp }
        }
    }
    
    /// Helper: Map error to user-friendly message
    private func mapErrorToUserMessage(_ error: Error) -> String {
        if let repoError = error as? RepositoryError {
            switch repoError {
            case .networkError:
                return "No internet connection. Message will be saved and you can retry later."
            case .unauthorized:
                return "Authentication error. Please sign in again."
            case .encodingError, .decodingError:
                return "Message format error. Please try again."
            case .conversationNotFound, .userNotFound, .messageNotFound:
                return "Conversation not found. Please refresh and try again."
            case .invalidInput:
                return "Invalid message. Please try again."
            case .unknown:
                return "Failed to send message. Please try again."
            }
        }
        return "Failed to send message: \(error.localizedDescription)"
    }
    
    /// Helper: Save failed message to local storage
    private func saveFailedMessageLocally(_ message: Message) {
        var failedMessage = message
        failedMessage.status = .failed
        failedMessageStore.save(failedMessage)
    }

    // MARK: - Offline Queue Methods (Story 2.9)

    /// Load queued messages from offline queue for this conversation
    private func loadQueuedMessages() {
        let allQueued = offlineQueueStore.loadQueue()

        // Filter to only messages for this conversation
        let conversationQueued = allQueued.filter { $0.conversationId == conversationId }

        if !conversationQueued.isEmpty {
            print("📦 [ChatViewModel] Loaded \(conversationQueued.count) queued message(s) from offline queue")
            queuedMessages = conversationQueued

            // Add to messages array if not already present
            for queuedMessage in conversationQueued {
                if !messages.contains(where: { $0.id == queuedMessage.id }) {
                    messages.append(queuedMessage)
                }
            }

            // Sort by timestamp
            messages.sort { $0.timestamp < $1.timestamp }
        }
    }

    /// Observe connectivity changes (Story 2.9)
    /// Shows toast when transitioning from offline → online with queued messages
    private func observeConnectivity() {
        var wasOffline = isOffline

        networkMonitor.isConnectedPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                guard let self = self else { return }

                let isNowOffline = !isConnected

                // Detect offline → online transition
                if wasOffline && !isNowOffline && !self.queuedMessages.isEmpty {
                    print("🌐 [ChatViewModel] Connectivity restored with \(self.queuedMessages.count) queued messages")
                    self.showConnectivityToast = true

                    // Auto-dismiss toast after 10 seconds
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 10_000_000_000)  // 10 seconds
                        self.showConnectivityToast = false
                    }
                }

                wasOffline = isNowOffline
            }
            .store(in: &cancellables)
    }

    /// Send all queued messages sequentially (Story 2.9)
    ///
    /// Called when user taps "Send All" button in offline banner or connectivity toast.
    /// Sends messages in FIFO order, continuing even if individual messages fail.
    func sendAllQueuedMessages() async {
        guard !queuedMessages.isEmpty else {
            print("⚠️ [ChatViewModel] sendAllQueuedMessages called but queue is empty")
            return
        }

        print("📤 [ChatViewModel] Sending \(queuedMessages.count) queued messages...")

        // Send in order (FIFO)
        for message in queuedMessages {
            await sendSingleQueuedMessage(message)
        }

        print("✅ [ChatViewModel] Finished sending queued messages")
    }

    /// Send a single queued message (Story 2.9)
    ///
    /// Used by OfflineQueueView for per-message send action.
    /// On success: Removes from queue. On failure: Marks as failed.
    func sendSingleQueuedMessage(_ message: Message) async {
        print("📤 [ChatViewModel] Attempting to send queued message \(message.id)")

        // Update status to .sending
        if let index = messages.firstIndex(where: { $0.id == message.id }) {
            var updated = messages
            updated[index].status = .sending
            updated[index].statusUpdatedAt = Date()
            messages = updated
        }

        do {
            try await messageRepository.sendMessage(message)

            // Success: Remove from queue
            offlineQueueStore.dequeue(message.id)
            queuedMessages.removeAll { $0.id == message.id }

            // Update status to .sent
            if let index = messages.firstIndex(where: { $0.id == message.id }) {
                var updated = messages
                updated[index].status = .sent
                updated[index].statusUpdatedAt = Date()
                messages = updated
            }

            // Update conversation's last message
            try? await updateConversation(with: message)

            print("✅ [ChatViewModel] Successfully sent queued message \(message.id)")

        } catch {
            print("❌ [ChatViewModel] Failed to send queued message \(message.id): \(error)")

            // Failure: Keep in queue with .failed status
            if let index = messages.firstIndex(where: { $0.id == message.id }) {
                var updated = messages
                updated[index].status = .failed
                updated[index].statusUpdatedAt = Date()
                messages = updated
            }

            // Also update in queue array
            if let queueIndex = queuedMessages.firstIndex(where: { $0.id == message.id }) {
                queuedMessages[queueIndex].status = .failed
                queuedMessages[queueIndex].statusUpdatedAt = Date()
            }

            errorMessage = "Failed to send message: \(error.localizedDescription)"
        }
    }

    /// Delete a queued message (Story 2.9)
    ///
    /// Removes from offline queue and messages array.
    /// Called from OfflineQueueView when user deletes a queued message.
    func deleteQueuedMessage(_ messageId: String) {
        offlineQueueStore.dequeue(messageId)
        queuedMessages.removeAll { $0.id == messageId }
        messages.removeAll { $0.id == messageId }
        print("🗑️ [ChatViewModel] Deleted queued message \(messageId)")
    }

    // MARK: - Typing Indicator Methods

    /// Start typing indicator (throttled to max 1 update per second)
    func startTyping() {
        let now = Date()
        let timeSinceLastUpdate = now.timeIntervalSince(lastTypingUpdateTime)

        // Throttle: Only send update if > 1 second since last update
        guard timeSinceLastUpdate >= 1.0 else {
            // Reset auto-stop timer even if throttled
            resetAutoStopTimer()
            return
        }

        // Send typing state to Firestore
        Task {
            do {
                try await conversationRepository.updateTypingState(
                    conversationId: conversationId,
                    userId: currentUserId,
                    isTyping: true
                )
                lastTypingUpdateTime = Date()
                isCurrentlyTyping = true
            } catch {
                print("⚠️ Failed to set typing state: \(error.localizedDescription)")
            }
        }

        // Reset auto-stop timer (3 seconds)
        resetAutoStopTimer()
    }

    /// Stop typing indicator
    func stopTyping() {
        guard isCurrentlyTyping else { return }

        Task {
            do {
                try await conversationRepository.updateTypingState(
                    conversationId: conversationId,
                    userId: currentUserId,
                    isTyping: false
                )
                isCurrentlyTyping = false
            } catch {
                print("⚠️ Failed to clear typing state: \(error.localizedDescription)")
            }
        }

        // Invalidate timers
        typingAutoStopTimer?.invalidate()
        typingAutoStopTimer = nil
    }

    /// Reset auto-stop timer (called on each keystroke)
    private func resetAutoStopTimer() {
        typingAutoStopTimer?.invalidate()
        typingAutoStopTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            self?.stopTyping()
        }
    }

    /// Observe typing users in real-time
    private func observeTypingUsers() {
        // Listen to conversation changes
        conversationRepository.observeConversations(userId: currentUserId)
            .compactMap { [weak self] (conversations: [Conversation]) -> Conversation? in
                guard let self = self else { return nil }
                return conversations.first { $0.id == self.conversationId }
            }
            .sink { [weak self] (conversation: Conversation) in
                guard let self = self else { return }

                // Filter out current user (don't show "You are typing...")
                let otherUsersTyping = conversation.typingUsers.filter { $0 != self.currentUserId }

                // Map user IDs to display names
                let names = otherUsersTyping.compactMap { userId in
                    self.users[userId]?.displayName
                }

                // Format names for display
                self.typingUserNames = names
            }
            .store(in: &cancellables)
    }

    // MARK: - Image Upload Methods

    /// Open image picker
    func selectImage() {
        isImagePickerPresented = true
    }

    /// Open document picker
    func selectDocument() {
        isDocumentPickerPresented = true
    }

    /// Send image message with compression and upload
    func sendImageMessage(image: UIImage) {
        Task {
            let messageId = UUID().uuidString

            // Step 1: Compress image
            guard let compressedImage = ImageCompressor.compress(
                image: image,
                maxSizeBytes: 2 * 1024 * 1024
            ) else {
                errorMessage = "Unable to compress image to required size. Please select a different image."
                return
            }

            guard let imageData = compressedImage.jpegData(compressionQuality: 0.8) else {
                errorMessage = "Unable to process image."
                return
            }

            // Step 2: Save to temporary storage for retry capability
            do {
                _ = try ImageCacheManager.saveTemporaryImage(imageData, forMessageId: messageId)
            } catch {
                print("⚠️ Failed to save temporary image: \(error)")
                errorMessage = "Failed to save image temporarily."
                return
            }

            // Step 3: Create optimistic message with caption support
            let caption = messageText  // Capture current text for caption
            let message = Message(
                id: messageId,
                conversationId: conversationId,
                senderId: currentUserId,
                text: caption,  // Include caption (empty string if no caption)
                timestamp: Date(),
                status: .sending,
                statusUpdatedAt: Date(),
                attachments: []  // Will be populated after upload
            )

            messages.append(message)
            uploadProgress[messageId] = 0.0
            messageText = ""  // Clear text input after creating message

            // Step 4: Upload image in background
            await performImageUpload(messageId: messageId, imageData: imageData)
        }
    }

    /// Perform the actual image upload (extracted for reuse in retry)
    private func performImageUpload(messageId: String, imageData: Data) async {
        do {
            // Convert Data back to UIImage for upload
            guard let image = UIImage(data: imageData) else {
                throw ImageUploadError.invalidImageData
            }

            // Upload to Firebase Storage
            let attachment = try await storageRepository.uploadMessageImage(
                image,
                conversationId: conversationId,
                messageId: messageId
            ) { progress in
                Task { @MainActor in
                    self.uploadProgress[messageId] = progress
                }
            }

            // Update message with attachment
            guard let index = messages.firstIndex(where: { $0.id == messageId }) else {
                return
            }

            var updatedMessage = messages[index]
            updatedMessage.attachments = [attachment]
            updatedMessage.status = .sent
            updatedMessage.statusUpdatedAt = Date()

            // Save to Firestore
            try await messageRepository.sendMessage(updatedMessage)

            // Update local array
            messages[index] = updatedMessage

            // Clean up
            uploadProgress.removeValue(forKey: messageId)
            uploadErrors.removeValue(forKey: messageId)
            ImageCacheManager.deleteTemporaryImage(forMessageId: messageId)
            removeFromOfflineQueue(messageId: messageId)

            print("✅ Image message sent: \(messageId)")

        } catch {
            print("❌ Image upload failed: \(error.localizedDescription)")

            // Check if error is due to network unavailability
            let isOfflineError = (error as NSError).code == NSURLErrorNotConnectedToInternet ||
                                 (error as NSError).code == FirestoreErrorCode.unavailable.rawValue

            if isOfflineError {
                // Queue for retry when online
                queueOfflineUpload(messageId: messageId, imageData: imageData)

                // Update UI to show queued status
                if let index = messages.firstIndex(where: { $0.id == messageId }) {
                    messages[index].status = .queued
                }

                uploadProgress.removeValue(forKey: messageId)
                // Don't set uploadErrors - queued uploads will auto-retry

            } else {
                // Non-network error (permissions, quota, etc.) - show retry button
                if let index = messages.firstIndex(where: { $0.id == messageId }) {
                    messages[index].status = .failed
                }

                uploadProgress.removeValue(forKey: messageId)
                uploadErrors[messageId] = "Failed to upload image. Tap to retry."
            }
        }
    }

    /// Retry failed image upload (loads from temp storage)
    func retryImageUpload(messageId: String) {
        Task {
            // Load image data from temporary storage
            guard let imageData = ImageCacheManager.loadTemporaryImage(forMessageId: messageId) else {
                errorMessage = "Image no longer available. Please send again."

                // Remove failed message if image is gone
                messages.removeAll { $0.id == messageId }
                uploadErrors.removeValue(forKey: messageId)
                return
            }

            // Reset error state
            uploadErrors.removeValue(forKey: messageId)

            // Update message status back to sending
            if let index = messages.firstIndex(where: { $0.id == messageId }) {
                messages[index].status = .sending
            }

            // Retry upload with cached image data
            await performImageUpload(messageId: messageId, imageData: imageData)
        }
    }

    /// Cancel in-progress upload
    func cancelImageUpload(messageId: String) {
        Task {
            do {
                try await storageRepository.cancelUpload(for: messageId)

                // Remove message from list
                messages.removeAll { $0.id == messageId }
                uploadProgress.removeValue(forKey: messageId)
                uploadErrors.removeValue(forKey: messageId)

                print("✅ Upload cancelled: \(messageId)")
            } catch {
                print("❌ Failed to cancel upload: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Document Upload Methods

    /// Send a document message with optional caption
    func sendDocumentMessage(fileURL: URL) {
        Task {
            let messageId = UUID().uuidString

            // Step 1: Validate document
            do {
                let (fileName, _) = try DocumentValidator.validate(fileURL: fileURL)
                print("📎 Validated document: \(fileName)")
            } catch {
                errorMessage = error.localizedDescription
                return
            }

            // Step 2: Copy to temporary storage for retry capability
            let tempURL: URL
            do {
                tempURL = try copyDocumentToTemp(fileURL: fileURL, messageId: messageId)
            } catch {
                print("⚠️ Failed to copy document to temp: \(error)")
                errorMessage = "Failed to save document temporarily."
                return
            }

            // Step 3: Create optimistic message with caption support
            let caption = messageText  // Capture current text for caption
            let message = Message(
                id: messageId,
                conversationId: conversationId,
                senderId: currentUserId,
                text: caption,  // Include caption (empty string if no caption)
                timestamp: Date(),
                status: .sending,
                statusUpdatedAt: Date(),
                attachments: []  // Will be populated after upload
            )

            messages.append(message)
            uploadProgress[messageId] = 0.0
            messageText = ""  // Clear text input after creating message

            // Step 4: Upload document in background
            await performDocumentUpload(messageId: messageId, fileURL: tempURL)
        }
    }

    /// Perform the actual document upload (extracted for reuse in retry)
    private func performDocumentUpload(messageId: String, fileURL: URL) async {
        do {
            // Upload to Firebase Storage
            let attachment = try await storageRepository.uploadMessageDocument(
                fileURL,
                conversationId: conversationId,
                messageId: messageId
            ) { progress in
                Task { @MainActor in
                    self.uploadProgress[messageId] = progress
                }
            }

            // Update message with attachment
            guard let index = messages.firstIndex(where: { $0.id == messageId }) else {
                return
            }

            var updatedMessage = messages[index]
            updatedMessage.attachments = [attachment]
            updatedMessage.status = .sent
            updatedMessage.statusUpdatedAt = Date()

            // Save to Firestore
            try await messageRepository.sendMessage(updatedMessage)

            // Update local array
            messages[index] = updatedMessage

            // Clean up
            uploadProgress.removeValue(forKey: messageId)
            uploadErrors.removeValue(forKey: messageId)
            deleteTemporaryDocument(messageId: messageId)

            print("✅ Document message sent: \(messageId)")

        } catch {
            print("❌ Document upload failed: \(error.localizedDescription)")

            // Check if error is due to network unavailability
            let isOfflineError = (error as NSError).code == NSURLErrorNotConnectedToInternet ||
                                 (error as NSError).code == FirestoreErrorCode.unavailable.rawValue

            if isOfflineError {
                // Update UI to show queued status (will auto-retry when online)
                if let index = messages.firstIndex(where: { $0.id == messageId }) {
                    messages[index].status = .queued
                }

                uploadProgress.removeValue(forKey: messageId)

            } else {
                // Non-network error (permissions, quota, validation) - show retry button
                if let index = messages.firstIndex(where: { $0.id == messageId }) {
                    messages[index].status = .failed
                }

                uploadProgress.removeValue(forKey: messageId)
                uploadErrors[messageId] = "Failed to upload document. Tap to retry."
            }
        }
    }

    /// Retry failed document upload (loads from temp storage)
    func retryDocumentUpload(messageId: String) {
        Task {
            // Load document URL from temporary storage
            guard let tempURL = getTemporaryDocumentURL(messageId: messageId),
                  FileManager.default.fileExists(atPath: tempURL.path) else {
                errorMessage = "Document no longer available. Please send again."

                // Remove failed message if document is gone
                messages.removeAll { $0.id == messageId }
                uploadErrors.removeValue(forKey: messageId)
                return
            }

            // Reset error state
            uploadErrors.removeValue(forKey: messageId)

            // Update message status back to sending
            if let index = messages.firstIndex(where: { $0.id == messageId }) {
                messages[index].status = .sending
            }

            // Retry upload with cached document
            await performDocumentUpload(messageId: messageId, fileURL: tempURL)
        }
    }

    // MARK: - Document File Management

    /// Copy document to temporary directory for retry capability
    private func copyDocumentToTemp(fileURL: URL, messageId: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent("\(messageId).pdf")

        // Access security-scoped resource if needed
        let accessed = fileURL.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        try FileManager.default.copyItem(at: fileURL, to: tempURL)
        print("📋 Copied document to temp: \(tempURL.path)")
        return tempURL
    }

    /// Get temporary document URL for a message
    private func getTemporaryDocumentURL(messageId: String) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        return tempDir.appendingPathComponent("\(messageId).pdf")
    }

    /// Delete temporary document file
    private func deleteTemporaryDocument(messageId: String) {
        guard let tempURL = getTemporaryDocumentURL(messageId: messageId) else { return }

        try? FileManager.default.removeItem(at: tempURL)
        print("🗑️ Deleted temporary document: \(tempURL.path)")
    }

    // MARK: - Offline Queue Management

    /// Save failed upload to offline queue (uses file system)
    private func queueOfflineUpload(messageId: String, imageData: Data) {
        do {
            // Save image data to temporary storage (already done via ImageCacheManager)
            // File was saved earlier in sendImageMessage(), just reference it

            // Create metadata
            let metadata = OfflineUploadMetadata(
                messageId: messageId,
                conversationId: conversationId,
                timestamp: Date(),
                filePath: "\(messageId).jpg"  // Filename in temp directory
            )

            // Load existing queue
            var queue = loadOfflineQueue()
            queue.append(metadata)

            // Save metadata to UserDefaults (small JSON, not image data)
            if let encoded = try? JSONEncoder().encode(queue) {
                UserDefaults.standard.set(encoded, forKey: offlineQueueKey)
                print("📦 Queued offline upload: \(messageId) (\(queue.count) in queue)")
            }

        } catch {
            print("❌ Failed to queue offline upload: \(error)")
        }
    }

    /// Load offline queue metadata from UserDefaults
    private func loadOfflineQueue() -> [OfflineUploadMetadata] {
        guard let data = UserDefaults.standard.data(forKey: offlineQueueKey),
              let queue = try? JSONDecoder().decode([OfflineUploadMetadata].self, from: data) else {
            return []
        }
        return queue
    }

    /// Save offline queue metadata to UserDefaults
    private func saveOfflineQueue(_ queue: [OfflineUploadMetadata]) {
        if let encoded = try? JSONEncoder().encode(queue) {
            UserDefaults.standard.set(encoded, forKey: offlineQueueKey)
        }
    }

    /// Retry all queued uploads when online (loads from file system)
    private func retryOfflineUploads() {
        let queue = loadOfflineQueue()

        guard !queue.isEmpty else {
            return
        }

        print("📤 Retrying \(queue.count) offline uploads")

        Task {
            var successfulUploads: [String] = []

            for metadata in queue {
                // Load image data from temporary storage
                guard let imageData = ImageCacheManager.loadTemporaryImage(forMessageId: metadata.messageId) else {
                    print("⚠️ Image data not found for \(metadata.messageId), removing from queue")
                    successfulUploads.append(metadata.messageId)
                    continue
                }

                // Only retry uploads for THIS conversation
                guard metadata.conversationId == conversationId else {
                    continue  // Leave in queue for other conversations
                }

                // Retry upload
                await performImageUpload(messageId: metadata.messageId, imageData: imageData)

                // Check if upload succeeded (no error in uploadErrors)
                if uploadErrors[metadata.messageId] == nil {
                    successfulUploads.append(metadata.messageId)
                }
            }

            // Remove successful uploads from queue
            if !successfulUploads.isEmpty {
                var updatedQueue = queue.filter { !successfulUploads.contains($0.messageId) }
                saveOfflineQueue(updatedQueue)
                print("✅ Removed \(successfulUploads.count) successful uploads from queue")
            }
        }
    }

    /// Remove message from offline queue
    private func removeFromOfflineQueue(messageId: String) {
        var queue = loadOfflineQueue()
        queue.removeAll { $0.messageId == messageId }
        saveOfflineQueue(queue)
        // Note: Temp file deleted separately in performImageUpload()
    }

    /// Get count of queued uploads for this conversation
    func getQueuedUploadCount() -> Int {
        let queue = loadOfflineQueue()
        return queue.filter { $0.conversationId == conversationId }.count
    }

    /// Observe network status and retry uploads
    private func observeNetworkStatus() {
        networkMonitor.isConnectedPublisher
            .sink { [weak self] (isConnected: Bool) in
                if isConnected {
                    self?.retryOfflineUploads()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Full-Screen Image Viewer

    /// Full-screen image viewer presentation (called by MessageKit tap)
    func presentFullScreenImage(url: String) {
        selectedImageURL = url
    }

    /// Dismiss full-screen image viewer
    func dismissFullScreenImage() {
        selectedImageURL = nil
    }
}

