import Foundation
import Combine

/// ViewModel for managing chat messages and message sending
@MainActor
class ChatViewModel: ObservableObject {
    
    // MARK: - Static Properties (for notification suppression)
    
    /// Tracks the conversation ID that the user is currently viewing
    /// Used to suppress push notifications for messages in the active conversation
    static var currentlyViewingConversationId: String?
    
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
    
    // Force UI refresh for message edits (when count doesn't change)
    @Published var messagesNeedRefresh: Bool = false
    
    // Track loading states separately
    private var messagesLoaded: Bool = false
    private var participantsLoaded: Bool = false
    
    // MARK: - Public Properties
    
    let currentUserId: String  // Exposed for ChatView title filtering
    
    // MARK: - Private Properties
    
    private let conversationId: String
    private let messageRepository: MessageRepositoryProtocol
    private let conversationRepository: ConversationRepositoryProtocol
    private let userRepository: UserRepositoryProtocol
    private let networkMonitor: any NetworkMonitorProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(
        conversationId: String,
        currentUserId: String,
        messageRepository: MessageRepositoryProtocol,
        conversationRepository: ConversationRepositoryProtocol,
        userRepository: UserRepositoryProtocol,
        networkMonitor: any NetworkMonitorProtocol = NetworkMonitor(),
        initialConversation: Conversation? = nil,
        initialParticipants: [User]? = nil
    ) {
        self.conversationId = conversationId
        self.currentUserId = currentUserId
        self.messageRepository = messageRepository
        self.conversationRepository = conversationRepository
        self.userRepository = userRepository
        self.networkMonitor = networkMonitor
        
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
        
        // Always observe messages (async)
        observeMessages()
        setupNetworkMonitoring()
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
                
                // CRITICAL: Detect if message content changed but count stayed same
                // This happens when messages are edited or deleted
                if self.messages.count == sortedMessages.count && self.messages.count > 0 {
                    // Check if any message content changed (edited or deleted)
                    let contentChanged = zip(self.messages, sortedMessages).contains { old, new in
                        old.text != new.text || old.isEdited != new.isEdited || old.isDeleted != new.isDeleted
                    }
                    
                    if contentChanged {
                        print("📝 [ChatViewModel] Message content changed (edit/delete), forcing UI refresh")
                        self.messagesNeedRefresh = true
                    }
                }
                
                self.messages = sortedMessages
                self.messagesLoaded = true
                self.updateLoadingState()
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
                self?.isOffline = !isConnected
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// Sends a message with input validation and optimistic UI
    func sendMessage() async {
        // 1. Sanitize and validate input
        let trimmedText = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Validate not empty
        guard !trimmedText.isEmpty else { return }
        
        // Enforce maximum length
        guard trimmedText.count <= 10000 else {
            errorMessage = "Message too long (max 10,000 characters)"
            return
        }
        
        // 2. Create Message entity with .sending status
        let message = Message(
            id: UUID().uuidString,
            conversationId: conversationId,
            senderId: currentUserId,
            text: trimmedText,
            timestamp: Date(),
            status: .sending,
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
        
        // 3. Optimistic UI: Append message immediately
        messages.append(message)
        messageText = "" // Clear input
        
        // 4. Send to Firestore
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
                messages[index] = updatedMessage
            }
            
            // Update conversation's last message fields
            try await updateConversation(with: message)
            
        } catch {
            // On failure: remove optimistic message, show error
            messages.removeAll { $0.id == message.id }
            errorMessage = "Failed to send message: \(error.localizedDescription)"
            print("Error sending message: \(error)")
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
    /// Sets the static currentlyViewingConversationId to suppress
    /// push notifications for messages in this conversation.
    func onAppear() {
        ChatViewModel.currentlyViewingConversationId = conversationId
        print("👀 Now viewing conversation: \(conversationId)")
    }
    
    /// Called when ChatView disappears
    ///
    /// Clears the static currentlyViewingConversationId to allow
    /// push notifications again when user leaves the conversation.
    func onDisappear() {
        if ChatViewModel.currentlyViewingConversationId == conversationId {
            ChatViewModel.currentlyViewingConversationId = nil
            print("👋 Left conversation: \(conversationId)")
        }
    }
}

