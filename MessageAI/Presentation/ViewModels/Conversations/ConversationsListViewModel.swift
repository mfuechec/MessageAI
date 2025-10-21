import Foundation
import Combine

/// ViewModel for managing conversations list display and real-time updates
@MainActor
class ConversationsListViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var conversations: [Conversation] = []
    @Published var users: [String: User] = [:] // userId -> User mapping (single source of truth)
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var isOffline: Bool = false
    
    // MARK: - Private Properties
    
    private let conversationRepository: ConversationRepositoryProtocol
    private let userRepository: UserRepositoryProtocol
    private let currentUserId: String
    private let networkMonitor: any NetworkMonitorProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(
        conversationRepository: ConversationRepositoryProtocol,
        userRepository: UserRepositoryProtocol,
        currentUserId: String,
        networkMonitor: any NetworkMonitorProtocol = NetworkMonitor()
    ) {
        self.conversationRepository = conversationRepository
        self.userRepository = userRepository
        self.currentUserId = currentUserId
        self.networkMonitor = networkMonitor
        
        observeConversations()
        observeNetworkStatus()
    }
    
    // MARK: - Real-Time Observations
    
    private func observeConversations() {
        conversationRepository.observeConversations(userId: currentUserId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] conversations in
                guard let self = self else { return }
                
                print("🔄 [ConversationsListViewModel] Conversations updated: \(conversations.count) conversations")
                
                // CRITICAL: Force array reassignment to trigger SwiftUI update
                // Even if sorting produces same order, create new array instance
                let sortedConversations = self.sortConversations(conversations)
                
                // Log any changed conversations (for debugging)
                for newConv in sortedConversations {
                    if let oldConv = self.conversations.first(where: { $0.id == newConv.id }),
                       oldConv != newConv {
                        print("📝 [ConversationsListViewModel] Conversation \(newConv.id) changed: '\(oldConv.lastMessage ?? "nil")' → '\(newConv.lastMessage ?? "nil")'")
                    }
                }
                
                self.conversations = sortedConversations
                self.loadParticipantUsers(from: conversations)
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
        
        // Load users into single source of truth dictionary
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
    
    /// Helper to get participants array for a conversation from users dictionary
    func getParticipants(for conversation: Conversation) -> [User] {
        return conversation.participantIds.compactMap { users[$0] }
    }
    
    private func observeNetworkStatus() {
        networkMonitor.isConnectedPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                self?.isOffline = !isConnected
            }
            .store(in: &cancellables)
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
            return formattedRelativeTime(for: conversation.createdAt)
        }
        return formattedRelativeTime(for: timestamp)
    }
    
    /// Helper to format timestamp as relative time, ensuring "ago" format (never "in X seconds")
    private func formattedRelativeTime(for date: Date) -> String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        
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
        return formatter.localizedString(for: date, relativeTo: now)
    }
}

