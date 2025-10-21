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
    
    // MARK: - Private Properties
    
    private let conversationId: String
    private let currentUserId: String
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
        networkMonitor: any NetworkMonitorProtocol = NetworkMonitor()
    ) {
        self.conversationId = conversationId
        self.currentUserId = currentUserId
        self.messageRepository = messageRepository
        self.conversationRepository = conversationRepository
        self.userRepository = userRepository
        self.networkMonitor = networkMonitor
        
        observeMessages()
        loadParticipantUsers()
        setupNetworkMonitoring()
    }
    
    // MARK: - Private Methods
    
    private func observeMessages() {
        isLoading = true
        
        messageRepository.observeMessages(conversationId: conversationId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] messages in
                self?.messages = messages.sorted { $0.timestamp < $1.timestamp }
                self?.isLoading = false
            }
            .store(in: &cancellables)
    }
    
    private func loadParticipantUsers() {
        Task {
            do {
                // Get conversation to find participant IDs
                let conversation = try await conversationRepository.getConversation(id: conversationId)
                
                // Load all participant users
                for participantId in conversation.participantIds where participantId != currentUserId {
                    do {
                        let user = try await userRepository.getUser(id: participantId)
                        users[participantId] = user
                    } catch {
                        print("Failed to load user \(participantId): \(error)")
                    }
                }
            } catch {
                print("Failed to load conversation participants: \(error)")
            }
        }
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
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: message.timestamp, relativeTo: Date())
    }
}

