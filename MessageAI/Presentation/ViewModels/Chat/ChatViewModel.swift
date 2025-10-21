import Foundation
import Combine

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
                print("🔄 [ChatViewModel] Messages updated: \(messages.count) messages")
                self?.messages = messages.sorted { $0.timestamp < $1.timestamp }
                self?.messagesLoaded = true
                self?.updateLoadingState()
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
            return
        }
        
        // 3. Enforce maximum length
        guard trimmedText.count <= 10000 else {
            errorMessage = "Message is too long. Please keep it under 10,000 characters."
            print("❌ Edit rejected: message too long (\(trimmedText.count) chars)")
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
}

