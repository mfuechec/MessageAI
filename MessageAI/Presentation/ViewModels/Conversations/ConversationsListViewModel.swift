import Foundation
import Combine
import UIKit
import UserNotifications

/// ViewModel for managing conversations list display and real-time updates
@MainActor
class ConversationsListViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var conversations: [Conversation] = []
    @Published var users: [String: User] = [:] // userId -> User mapping (single source of truth)
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var isOffline: Bool = false
    @Published var notificationPermissionDenied: Bool = false // Story 2.10a AC 11

    // Story 2.11 - AC #3: Pagination state
    @Published var isLoadingMore: Bool = false
    @Published var hasMoreConversations: Bool = true

    // MARK: - Private Properties
    
    private let conversationRepository: ConversationRepositoryProtocol
    private let userRepository: UserRepositoryProtocol
    private let currentUserId: String
    private let networkMonitor: any NetworkMonitorProtocol
    private var cancellables = Set<AnyCancellable>()
    
    #if DEBUG
    private var notificationSimulator: NotificationSimulator?
    #endif
    
    // MARK: - Initialization
    
    init(
        conversationRepository: ConversationRepositoryProtocol,
        userRepository: UserRepositoryProtocol,
        currentUserId: String,
        networkMonitor: any NetworkMonitorProtocol = NetworkMonitor(),
        messageRepository: MessageRepositoryProtocol? = nil
    ) {
        self.conversationRepository = conversationRepository
        self.userRepository = userRepository
        self.currentUserId = currentUserId
        self.networkMonitor = networkMonitor
        
        observeConversations()
        observeNetworkStatus()
        
        #if DEBUG
        // Enable notification simulation in DEBUG builds (for simulator testing)
        if let messageRepo = messageRepository {
            notificationSimulator = NotificationSimulator(
                conversationRepository: conversationRepository,
                messageRepository: messageRepo,
                userRepository: userRepository,
                currentUserId: currentUserId
            )
            notificationSimulator?.start()
            print("🔔 Notification simulator enabled (messages will trigger notifications)")
        }
        #endif
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
                self.updateBadgeCount()  // Update app badge with total unread count
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
    
    /// Updates the app icon badge count with total unread messages
    ///
    /// Calculates the sum of unreadCount across all conversations
    /// and updates UIApplication.shared.applicationIconBadgeNumber.
    ///
    /// Note: Badge count requires notification permissions to display.
    /// If user denied permissions, badge won't show (but still updates).
    private func updateBadgeCount() {
        let unreadCount = conversations.reduce(0) { count, conversation in
            count + conversation.unreadCount(for: currentUserId)
        }
        
        // Must update badge on main thread
        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = unreadCount
            print("🔔 Badge count updated: \(unreadCount)")
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

    // MARK: - Deep Link Support (Story 2.10a)

    /// Fetch conversation and participants by ID (for deep linking when not in loaded list)
    ///
    /// Used when user taps notification before conversation list has loaded.
    /// Fetches conversation and its participants from Firestore.
    /// - Returns: Tuple of (conversation, participants)
    func fetchConversationWithParticipants(id: String) async throws -> (Conversation, [User]) {
        do {
            let conversation = try await conversationRepository.getConversation(id: id)
            let participants = try await userRepository.getUsers(ids: conversation.participantIds)
            print("✅ Fetched conversation and \(participants.count) participants for deep link: \(id)")
            return (conversation, participants)
        } catch {
            print("❌ Failed to fetch conversation \(id): \(error.localizedDescription)")
            throw error
        }
    }

    /// Check notification permission status and update UI state (Story 2.10a AC 13)
    ///
    /// Queries iOS notification settings to determine if user has denied permissions.
    /// Updates `notificationPermissionDenied` to show/hide permission banner.
    func checkNotificationPermissionStatus() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        await MainActor.run {
            notificationPermissionDenied = (settings.authorizationStatus == .denied)
            print("🔔 Notification permission status: \(settings.authorizationStatus.rawValue) (denied=\(notificationPermissionDenied))")
        }
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

    // MARK: - Pagination (Story 2.11 - AC #3)

    /// Load more conversations for pagination (load older conversations)
    func loadMoreConversations() async {
        // Prevent concurrent loads
        guard !isLoadingMore && hasMoreConversations else {
            return
        }

        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            // Get last conversation for cursor-based pagination
            let lastConversation = conversations.last

            // Load next page (50 conversations)
            let olderConversations = try await conversationRepository.loadMoreConversations(
                userId: currentUserId,
                lastConversation: lastConversation,
                limit: 50
            )

            // If we got fewer than requested, we've reached the end
            if olderConversations.count < 50 {
                hasMoreConversations = false
            }

            // Append older conversations to existing list
            conversations.append(contentsOf: olderConversations)

            // Load participant users for new conversations
            loadParticipantUsers(from: olderConversations)

            print("📄 [Pagination] Loaded \(olderConversations.count) older conversations. Total: \(conversations.count)")

        } catch {
            print("❌ Failed to load more conversations: \(error.localizedDescription)")
            errorMessage = "Failed to load more conversations: \(error.localizedDescription)"
        }
    }
}

