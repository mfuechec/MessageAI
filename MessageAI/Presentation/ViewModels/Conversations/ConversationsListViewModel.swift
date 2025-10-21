import Foundation
import Combine

/// ViewModel for managing conversations list display and real-time updates
@MainActor
class ConversationsListViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var conversations: [Conversation] = []
    @Published var users: [String: User] = [:] // userId -> User mapping for display names
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var isOffline: Bool = false
    
    // MARK: - Private Properties
    
    private let conversationRepository: ConversationRepositoryProtocol
    private let userRepository: UserRepositoryProtocol
    private let currentUserId: String
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(
        conversationRepository: ConversationRepositoryProtocol,
        userRepository: UserRepositoryProtocol,
        currentUserId: String
    ) {
        self.conversationRepository = conversationRepository
        self.userRepository = userRepository
        self.currentUserId = currentUserId
        
        observeConversations()
        observeNetworkStatus()
    }
    
    // MARK: - Real-Time Observations
    
    private func observeConversations() {
        conversationRepository.observeConversations(userId: currentUserId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] conversations in
                self?.conversations = self?.sortConversations(conversations) ?? []
                self?.loadParticipantUsers(from: conversations)
            }
            .store(in: &cancellables)
    }
    
    private func sortConversations(_ conversations: [Conversation]) -> [Conversation] {
        conversations.sorted { (conv1, conv2) in
            let timestamp1 = conv1.lastMessageTimestamp ?? conv1.createdAt
            let timestamp2 = conv2.lastMessageTimestamp ?? conv2.createdAt
            return timestamp1 > timestamp2
        }
    }
    
    private func loadParticipantUsers(from conversations: [Conversation]) {
        // Collect all unique participant IDs
        let participantIds = Set(conversations.flatMap { $0.participantIds })
        
        // Load users for display names
        Task {
            for userId in participantIds {
                if users[userId] == nil {
                    do {
                        let user = try await userRepository.getUser(id: userId)
                        await MainActor.run {
                            users[userId] = user
                        }
                    } catch {
                        // User not found, continue
                        print("⚠️ Failed to load user \(userId): \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    private func observeNetworkStatus() {
        // For MVP: Simple offline detection based on Firestore errors
        // Production would use NWPathMonitor for network reachability
        // For now, this is a placeholder
    }
    
    // MARK: - Display Helper Methods
    
    func displayName(for conversation: Conversation) -> String {
        let participantUsers = conversation.participantIds.compactMap { users[$0] }
        return conversation.displayName(for: currentUserId, users: participantUsers)
    }
    
    func unreadCount(for conversation: Conversation) -> Int {
        conversation.unreadCount(for: currentUserId)
    }
    
    func formattedTimestamp(for conversation: Conversation) -> String {
        guard let timestamp = conversation.lastMessageTimestamp else {
            return RelativeDateTimeFormatter().localizedString(for: conversation.createdAt, relativeTo: Date())
        }
        return RelativeDateTimeFormatter().localizedString(for: timestamp, relativeTo: Date())
    }
}

