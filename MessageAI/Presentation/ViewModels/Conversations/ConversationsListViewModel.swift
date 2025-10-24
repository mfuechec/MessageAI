import Foundation
import Combine
import UIKit
import UserNotifications

/// In-app smart notification to display
struct InAppSmartNotification: Identifiable, Equatable {
    let id = UUID()
    let conversationId: String
    let conversationName: String
    let notificationText: String
    let priority: NotificationPriority
    let aiReasoning: String
    let timestamp: Date

    static func == (lhs: InAppSmartNotification, rhs: InAppSmartNotification) -> Bool {
        lhs.id == rhs.id
    }
}

/// ViewModel for managing conversations list display and real-time updates
@MainActor
class ConversationsListViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var conversations: [Conversation] = []
    @Published var users: [String: User] = [:] // userId -> User mapping (single source of truth)
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var isOffline: Bool = false {
        didSet {
            print("🚨 [ConversationsListViewModel] isOffline changed: \(oldValue) -> \(isOffline)")
        }
    }
    @Published var notificationPermissionDenied: Bool = false // Story 2.10a AC 11

    // Story 2.11 - AC #3: Pagination state
    @Published var isLoadingMore: Bool = false
    @Published var hasMoreConversations: Bool = true

    // Epic 6: Smart in-app notifications
    @Published var smartNotification: InAppSmartNotification? = nil
    @Published var currentlyViewingConversationId: String? = nil

    // MARK: - Private Properties

    private let conversationRepository: ConversationRepositoryProtocol
    private let userRepository: UserRepositoryProtocol
    private let notificationAnalysisRepository: NotificationAnalysisRepositoryProtocol
    private let currentUserId: String
    private let networkMonitor: any NetworkMonitorProtocol
    private var cancellables = Set<AnyCancellable>()
    private var lastMessageIds: [String: String] = [:] // conversationId -> lastMessageId
    
    #if DEBUG
    private var notificationSimulator: NotificationSimulator?
    #endif
    
    // MARK: - Initialization
    
    init(
        conversationRepository: ConversationRepositoryProtocol,
        userRepository: UserRepositoryProtocol,
        notificationAnalysisRepository: NotificationAnalysisRepositoryProtocol,
        currentUserId: String,
        networkMonitor: any NetworkMonitorProtocol = NetworkMonitor(),
        messageRepository: MessageRepositoryProtocol? = nil
    ) {
        self.conversationRepository = conversationRepository
        self.userRepository = userRepository
        self.notificationAnalysisRepository = notificationAnalysisRepository
        self.currentUserId = currentUserId
        self.networkMonitor = networkMonitor

        // Load from cache first (offline-first strategy)
        loadCachedConversations()

        // Then observe real-time updates
        observeConversations()
        observeNetworkStatus()

        #if DEBUG
        // DISABLED: Old notification simulator (replaced by smart in-app notifications)
        // Now using AI-powered smart notification banners instead
        // if let messageRepo = messageRepository {
        //     notificationSimulator = NotificationSimulator(
        //         conversationRepository: conversationRepository,
        //         messageRepository: messageRepo,
        //         userRepository: userRepository,
        //         currentUserId: currentUserId
        //     )
        //     notificationSimulator?.start()
        //     print("🔔 Notification simulator enabled (messages will trigger notifications)")
        // }
        print("🔔 Smart in-app notifications enabled (AI-powered)")
        #endif
    }
    
    // MARK: - Real-Time Observations

    /// Load conversations from local cache for instant display (offline-first)
    ///
    /// Called immediately on init to show cached data instantly, even when offline.
    /// The real-time listener will then update with live data when network is available.
    private func loadCachedConversations() {
        Task {
            do {
                let cachedConversations = try await conversationRepository.getConversationsFromCache(userId: currentUserId)

                await MainActor.run {
                    if !cachedConversations.isEmpty {
                        print("💾 [ConversationsListViewModel] Loaded \(cachedConversations.count) conversations from cache")
                        self.setConversations(cachedConversations, source: "loadCachedConversations")
                        self.updateBadgeCount()
                        self.loadParticipantUsers(from: cachedConversations)
                    } else {
                        print("💾 [ConversationsListViewModel] No cached conversations available")
                    }
                }
            } catch {
                print("⚠️ [ConversationsListViewModel] Failed to load cached conversations: \(error.localizedDescription)")
                // Not a critical error - real-time listener will populate data
            }
        }
    }

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
                // Also detect new messages for smart in-app notifications
                for newConv in sortedConversations {
                    if let oldConv = self.conversations.first(where: { $0.id == newConv.id }),
                       oldConv != newConv {
                        print("📝 [ConversationsListViewModel] Conversation \(newConv.id) changed: '\(oldConv.lastMessage ?? "nil")' → '\(newConv.lastMessage ?? "nil")'")

                        // Check if there's a new message (lastMessageId changed)
                        if let newMessageId = newConv.lastMessageId,
                           newMessageId != self.lastMessageIds[newConv.id],
                           let senderId = newConv.lastMessageSenderId {

                            // Update tracking
                            self.lastMessageIds[newConv.id] = newMessageId

                            // DEBUG: Allow notifications for own messages (for testing on single device)
                            #if DEBUG
                            print("🔍 [Smart Notification] New message detected from \(senderId == self.currentUserId ? "SELF" : "OTHER")")
                            let shouldAnalyze = true  // DEBUG: Always analyze (even own messages)
                            #else
                            let shouldAnalyze = (senderId != self.currentUserId)  // PRODUCTION: Only others' messages
                            #endif

                            // Trigger smart notification analysis (Epic 6)
                            if shouldAnalyze {
                                self.analyzeForInAppNotification(conversation: newConv)
                            }
                        }
                    } else if self.conversations.first(where: { $0.id == newConv.id }) == nil {
                        // Brand new conversation - track its message ID
                        if let messageId = newConv.lastMessageId {
                            self.lastMessageIds[newConv.id] = messageId
                        }
                    }
                }

                // Use centralized method to set conversations (ensures deduplication)
                print("📥 [observeConversations] Setting \(sortedConversations.count) conversations")
                self.setConversations(sortedConversations, source: "observeConversations")
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

    /// CRITICAL: Single source of truth for setting conversations
    /// Always deduplicates and logs source for debugging
    private func setConversations(_ newConversations: [Conversation], source: String) {
        // Log all conversation IDs being set
        let ids = newConversations.map { $0.id }
        print("🔍 [\(source)] Setting \(newConversations.count) conversations: \(ids)")

        // Detect duplicates BEFORE deduplication
        let uniqueIds = Set(ids)
        if uniqueIds.count != ids.count {
            let duplicateCount = ids.count - uniqueIds.count
            print("⚠️ [\(source)] FOUND \(duplicateCount) DUPLICATE(S) in input array!")

            // Find which IDs are duplicated
            var seenIds = Set<String>()
            var duplicateIds = Set<String>()
            for id in ids {
                if seenIds.contains(id) {
                    duplicateIds.insert(id)
                }
                seenIds.insert(id)
            }
            print("⚠️ [\(source)] Duplicate IDs: \(Array(duplicateIds))")
        }

        // ALWAYS deduplicate using Dictionary (last occurrence wins)
        var uniqueConversations: [String: Conversation] = [:]
        for conv in newConversations {
            uniqueConversations[conv.id] = conv
        }

        // Sort by timestamp
        let deduplicated = Array(uniqueConversations.values).sorted { conv1, conv2 in
            let timestamp1 = conv1.lastMessageTimestamp ?? conv1.createdAt
            let timestamp2 = conv2.lastMessageTimestamp ?? conv2.createdAt
            return timestamp1 > timestamp2
        }

        print("✅ [\(source)] After deduplication: \(deduplicated.count) unique conversations")

        // Set the array
        self.conversations = deduplicated
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
    /// For one-on-one conversations, excludes the current user (returns only the other participant)
    /// For group conversations, returns all participants
    func getParticipants(for conversation: Conversation) -> [User] {
        let allParticipants = conversation.participantIds.compactMap { users[$0] }

        // For one-on-one conversations, filter out current user (we only want to show the OTHER participant)
        if !conversation.isGroup {
            return allParticipants.filter { $0.id != currentUserId }
        }

        // For group conversations, return all participants
        return allParticipants
    }
    
    private func observeNetworkStatus() {
        print("🚨 [ConversationsListViewModel] Setting up network status observer")
        networkMonitor.isEffectivelyConnectedPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                print("🚨 [ConversationsListViewModel] Received network status update: isConnected=\(isConnected)")
                print("🚨 [ConversationsListViewModel] Setting isOffline to \(!isConnected)")
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

            // Merge with existing conversations (using centralized method for deduplication)
            let mergedConversations = conversations + olderConversations
            setConversations(mergedConversations, source: "loadMoreConversations")

            // Load participant users for new conversations
            loadParticipantUsers(from: olderConversations)

            print("📄 [Pagination] Loaded \(olderConversations.count) older conversations. Total: \(conversations.count)")

        } catch {
            print("❌ Failed to load more conversations: \(error.localizedDescription)")
            errorMessage = "Failed to load more conversations: \(error.localizedDescription)"
        }
    }

    // MARK: - Smart In-App Notifications (Epic 6)

    /// Analyze conversation for smart in-app notification
    ///
    /// Calls AI analysis to determine if user should be notified about new message.
    /// Only shows notification if:
    /// - AI decides shouldNotify = true
    /// - User is NOT currently viewing this conversation
    /// - Priority is medium or high
    private func analyzeForInAppNotification(conversation: Conversation) {
        // Don't show notification if user is currently viewing this conversation
        if currentlyViewingConversationId == conversation.id {
            print("🔕 [Smart Notification] Suppressing - user viewing conversation \(conversation.id)")
            return
        }

        print("🤖 [Smart Notification] Analyzing conversation \(conversation.id) for in-app notification...")

        Task {
            do {
                let decision = try await notificationAnalysisRepository.analyzeConversationForNotification(
                    conversationId: conversation.id,
                    userId: currentUserId
                )

                await MainActor.run {
                    if decision.shouldNotify {
                        print("✅ [Smart Notification] AI says NOTIFY - Priority: \(decision.priority)")
                        print("   Reason: \(decision.reason)")

                        // Get conversation display name
                        let participants = getParticipants(for: conversation)
                        let displayName = conversation.displayName(for: currentUserId, users: participants)

                        // Create in-app notification
                        let notification = InAppSmartNotification(
                            conversationId: conversation.id,
                            conversationName: displayName,
                            notificationText: decision.notificationText ?? conversation.lastMessage ?? "New message",
                            priority: decision.priority,
                            aiReasoning: decision.reason,
                            timestamp: Date()
                        )

                        // Show notification (will trigger UI update)
                        self.smartNotification = notification

                        // Auto-dismiss after 5 seconds
                        Task {
                            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                            await MainActor.run {
                                if self.smartNotification?.id == notification.id {
                                    self.smartNotification = nil
                                }
                            }
                        }
                    } else {
                        print("🔕 [Smart Notification] AI says DON'T NOTIFY")
                        print("   Reason: \(decision.reason)")
                    }
                }
            } catch {
                print("❌ [Smart Notification] Analysis failed: \(error.localizedDescription)")
            }
        }
    }

    /// Dismiss current smart notification
    func dismissSmartNotification() {
        smartNotification = nil
    }
}

