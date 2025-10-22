import XCTest
import Combine
@testable import MessageAI

/// Unit tests for ConversationsListViewModel
@MainActor
final class ConversationsListViewModelTests: XCTestCase {
    
    var sut: ConversationsListViewModel!
    var mockConversationRepo: MockConversationRepository!
    var mockUserRepo: MockUserRepository!
    var mockNetworkMonitor: MockNetworkMonitor!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockConversationRepo = MockConversationRepository()
        mockUserRepo = MockUserRepository()
        mockNetworkMonitor = MockNetworkMonitor()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        sut = nil
        mockConversationRepo = nil
        mockUserRepo = nil
        mockNetworkMonitor = nil
        cancellables = nil
        super.tearDown()
    }
    
    // MARK: - Observe Conversations Tests
    
    func testObserveConversations_UpdatesConversationsList() async throws {
        // Given
        let timestamp = Date()
        mockConversationRepo.mockConversations = [
            Conversation(
                id: "conv-1",
                participantIds: ["user-1", "user-2"],
                lastMessage: "Hello",
                lastMessageTimestamp: timestamp,
                createdAt: timestamp.addingTimeInterval(-3600),
                isGroup: false
            )
        ]
        
        // When
        sut = ConversationsListViewModel(
            conversationRepository: mockConversationRepo,
            userRepository: mockUserRepo,
            currentUserId: "user-1",
            networkMonitor: mockNetworkMonitor
        )
        
        // Give time for publisher to emit
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Then
        XCTAssertTrue(mockConversationRepo.observeConversationsCalled)
        XCTAssertEqual(mockConversationRepo.capturedUserId, "user-1")
        XCTAssertEqual(sut.conversations.count, 1)
        XCTAssertEqual(sut.conversations.first?.id, "conv-1")
    }
    
    func testObserveConversations_HandlesEmptyList() async throws {
        // Given
        mockConversationRepo.mockConversations = []
        
        // When
        sut = ConversationsListViewModel(
            conversationRepository: mockConversationRepo,
            userRepository: mockUserRepo,
            currentUserId: "user-1",
            networkMonitor: mockNetworkMonitor
        )
        
        // Give time for publisher to emit
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Then
        XCTAssertTrue(mockConversationRepo.observeConversationsCalled)
        XCTAssertEqual(sut.conversations.count, 0)
    }
    
    // MARK: - Sort Conversations Tests
    
    func testSortConversations_SortsByMostRecentFirst() async throws {
        // Given
        let now = Date()
        let oneHourAgo = now.addingTimeInterval(-3600)
        let twoDaysAgo = now.addingTimeInterval(-172800)
        
        mockConversationRepo.mockConversations = [
            Conversation(
                id: "conv-1",
                participantIds: ["user-1", "user-2"],
                lastMessage: "Old message",
                lastMessageTimestamp: twoDaysAgo,
                createdAt: twoDaysAgo,
                isGroup: false
            ),
            Conversation(
                id: "conv-2",
                participantIds: ["user-1", "user-3"],
                lastMessage: "Recent message",
                lastMessageTimestamp: now,
                createdAt: now.addingTimeInterval(-7200),
                isGroup: false
            ),
            Conversation(
                id: "conv-3",
                participantIds: ["user-1", "user-4"],
                lastMessage: "Middle message",
                lastMessageTimestamp: oneHourAgo,
                createdAt: oneHourAgo,
                isGroup: false
            )
        ]
        
        // When
        sut = ConversationsListViewModel(
            conversationRepository: mockConversationRepo,
            userRepository: mockUserRepo,
            currentUserId: "user-1",
            networkMonitor: mockNetworkMonitor
        )
        
        // Give time for publisher to emit
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Then
        XCTAssertEqual(sut.conversations.count, 3)
        XCTAssertEqual(sut.conversations[0].id, "conv-2") // Most recent
        XCTAssertEqual(sut.conversations[1].id, "conv-3") // Middle
        XCTAssertEqual(sut.conversations[2].id, "conv-1") // Oldest
    }
    
    func testSortConversations_FallsBackToCreatedAtWhenNoLastMessage() async throws {
        // Given
        let now = Date()
        let yesterday = now.addingTimeInterval(-86400)
        
        mockConversationRepo.mockConversations = [
            Conversation(
                id: "conv-1",
                participantIds: ["user-1", "user-2"],
                lastMessage: nil,
                lastMessageTimestamp: nil,
                createdAt: yesterday,
                isGroup: false
            ),
            Conversation(
                id: "conv-2",
                participantIds: ["user-1", "user-3"],
                lastMessage: nil,
                lastMessageTimestamp: nil,
                createdAt: now,
                isGroup: false
            )
        ]
        
        // When
        sut = ConversationsListViewModel(
            conversationRepository: mockConversationRepo,
            userRepository: mockUserRepo,
            currentUserId: "user-1",
            networkMonitor: mockNetworkMonitor
        )
        
        // Give time for publisher to emit
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Then
        XCTAssertEqual(sut.conversations.count, 2)
        XCTAssertEqual(sut.conversations[0].id, "conv-2") // Created today
        XCTAssertEqual(sut.conversations[1].id, "conv-1") // Created yesterday
    }
    
    // MARK: - Unread Count Tests
    
    func testUnreadCount_ReturnsCorrectCount() async throws {
        // Given
        let timestamp = Date()
        let conversation = Conversation(
            id: "conv-1",
            participantIds: ["user-1", "user-2"],
            lastMessage: "Hello",
            lastMessageTimestamp: timestamp,
            unreadCounts: ["user-1": 5, "user-2": 0],
            createdAt: timestamp,
            isGroup: false
        )
        
        mockConversationRepo.mockConversations = [conversation]
        
        // When
        sut = ConversationsListViewModel(
            conversationRepository: mockConversationRepo,
            userRepository: mockUserRepo,
            currentUserId: "user-1",
            networkMonitor: mockNetworkMonitor
        )
        
        // Give time for publisher to emit
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Then
        XCTAssertEqual(sut.unreadCount(for: conversation), 5)
    }
    
    func testUnreadCount_ReturnsZeroWhenNoUnreadMessages() async throws {
        // Given
        let timestamp = Date()
        let conversation = Conversation(
            id: "conv-1",
            participantIds: ["user-1", "user-2"],
            lastMessage: "Hello",
            lastMessageTimestamp: timestamp,
            unreadCounts: ["user-1": 0, "user-2": 2],
            createdAt: timestamp,
            isGroup: false
        )
        
        mockConversationRepo.mockConversations = [conversation]
        
        // When
        sut = ConversationsListViewModel(
            conversationRepository: mockConversationRepo,
            userRepository: mockUserRepo,
            currentUserId: "user-1",
            networkMonitor: mockNetworkMonitor
        )
        
        // Give time for publisher to emit
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Then
        XCTAssertEqual(sut.unreadCount(for: conversation), 0)
    }
    
    // MARK: - Display Name Tests
    
    func testDisplayName_ForOneOnOneConversation() async throws {
        // Given
        let timestamp = Date()
        let conversation = Conversation(
            id: "conv-1",
            participantIds: ["user-1", "user-2"],
            lastMessage: "Hello",
            lastMessageTimestamp: timestamp,
            createdAt: timestamp,
            isGroup: false
        )
        
        mockConversationRepo.mockConversations = [conversation]
        mockUserRepo.mockUser = User(
            id: "user-2",
            email: "jane@example.com",
            displayName: "Jane Doe"
        )
        
        // When
        sut = ConversationsListViewModel(
            conversationRepository: mockConversationRepo,
            userRepository: mockUserRepo,
            currentUserId: "user-1",
            networkMonitor: mockNetworkMonitor
        )
        
        // Give time for publisher and user loading to complete
        try await Task.sleep(nanoseconds: 200_000_000)
        
        // Then
        let displayName = sut.displayName(for: conversation)
        XCTAssertEqual(displayName, "Jane Doe")
    }
    
    func testDisplayName_ForGroupConversation() async throws {
        // Given
        let timestamp = Date()
        let conversation = Conversation(
            id: "conv-1",
            participantIds: ["user-1", "user-2", "user-3"],
            lastMessage: "Hello everyone",
            lastMessageTimestamp: timestamp,
            createdAt: timestamp,
            isGroup: true,
            groupName: "Team Chat"
        )
        
        mockConversationRepo.mockConversations = [conversation]
        
        // When
        sut = ConversationsListViewModel(
            conversationRepository: mockConversationRepo,
            userRepository: mockUserRepo,
            currentUserId: "user-1",
            networkMonitor: mockNetworkMonitor
        )
        
        // Give time for publisher to emit
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Then
        let displayName = sut.displayName(for: conversation)
        XCTAssertEqual(displayName, "Team Chat")
    }
    
    // MARK: - Formatted Timestamp Tests
    
    func testFormattedTimestamp_ReturnsRelativeTime() async throws {
        // Given
        let timestamp = Date()
        let conversation = Conversation(
            id: "conv-1",
            participantIds: ["user-1", "user-2"],
            lastMessage: "Hello",
            lastMessageTimestamp: timestamp,
            createdAt: timestamp,
            isGroup: false
        )
        
        mockConversationRepo.mockConversations = [conversation]
        
        // When
        sut = ConversationsListViewModel(
            conversationRepository: mockConversationRepo,
            userRepository: mockUserRepo,
            currentUserId: "user-1",
            networkMonitor: mockNetworkMonitor
        )
        
        // Give time for publisher to emit
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Then
        let formattedTime = sut.formattedTimestamp(for: conversation)
        // RelativeDateTimeFormatter returns localized strings like "now", "1 min ago", etc.
        XCTAssertFalse(formattedTime.isEmpty)
    }
    
    func testFormattedTimestamp_FallsBackToCreatedAtWhenNoLastMessage() async throws {
        // Given
        let createdAt = Date().addingTimeInterval(-3600) // 1 hour ago
        let conversation = Conversation(
            id: "conv-1",
            participantIds: ["user-1", "user-2"],
            lastMessage: nil,
            lastMessageTimestamp: nil,
            createdAt: createdAt,
            isGroup: false
        )
        
        mockConversationRepo.mockConversations = [conversation]
        
        // When
        sut = ConversationsListViewModel(
            conversationRepository: mockConversationRepo,
            userRepository: mockUserRepo,
            currentUserId: "user-1",
            networkMonitor: mockNetworkMonitor
        )
        
        // Give time for publisher to emit
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Then
        let formattedTime = sut.formattedTimestamp(for: conversation)
        XCTAssertFalse(formattedTime.isEmpty)
        // RelativeDateTimeFormatter should show something like "1 hr ago"
    }
    
    // MARK: - Load Participant Users Tests
    
    func testLoadParticipantUsers_FetchesUserDetails() async throws {
        // Given
        let timestamp = Date()
        let conversation = Conversation(
            id: "conv-1",
            participantIds: ["user-1", "user-2", "user-3"],
            lastMessage: "Hello",
            lastMessageTimestamp: timestamp,
            createdAt: timestamp,
            isGroup: false
        )
        
        mockConversationRepo.mockConversations = [conversation]
        mockUserRepo.mockUser = User(
            id: "user-2",
            email: "jane@example.com",
            displayName: "Jane Doe"
        )
        
        // When
        sut = ConversationsListViewModel(
            conversationRepository: mockConversationRepo,
            userRepository: mockUserRepo,
            currentUserId: "user-1",
            networkMonitor: mockNetworkMonitor
        )
        
        // Give time for publisher and user loading to complete
        try await Task.sleep(nanoseconds: 300_000_000)
        
        // Then
        XCTAssertTrue(mockUserRepo.getUserCalled)
        // Note: In a real implementation, we'd verify that all participant users were loaded
        // For now, we just verify that getUser was called
    }
    
    // MARK: - Network Monitoring Tests
    
    func testNetworkMonitor_UpdatesOfflineState() async throws {
        // Given
        let mockNetworkMonitor = MockNetworkMonitor()
        mockConversationRepo.mockConversations = []
        
        sut = ConversationsListViewModel(
            conversationRepository: mockConversationRepo,
            userRepository: mockUserRepo,
            currentUserId: "user-1",
            networkMonitor: mockNetworkMonitor
        )
        
        // Initial state: online
        XCTAssertFalse(sut.isOffline)
        
        // When: Network goes offline
        mockNetworkMonitor.simulateOffline()
        
        // Give time for Combine publisher to propagate
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Then: ViewModel reflects offline state
        XCTAssertTrue(sut.isOffline)
        
        // When: Network returns online
        mockNetworkMonitor.simulateOnline()
        
        // Give time for Combine publisher to propagate
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Then: ViewModel reflects online state
        XCTAssertFalse(sut.isOffline)
    }
    
    func testNetworkMonitor_StartsOnline() async throws {
        // Given
        let mockNetworkMonitor = MockNetworkMonitor()
        mockConversationRepo.mockConversations = []
        
        // When
        sut = ConversationsListViewModel(
            conversationRepository: mockConversationRepo,
            userRepository: mockUserRepo,
            currentUserId: "user-1",
            networkMonitor: mockNetworkMonitor
        )
        
        // Give time for initialization
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Then: Default state is online (not offline)
        XCTAssertFalse(sut.isOffline)
    }
    
    // MARK: - Badge Count Tests (Story 2.10)
    
    func testBadgeCountUpdatesSingleConversation() async throws {
        // Given: Mock repository returns conversation with unread count
        let conversation = Conversation(
            id: "conv-1",
            participantIds: ["user-1", "user-2"],
            lastMessage: "Test message",
            lastMessageTimestamp: Date(),
            unreadCounts: ["user-1": 3],
            createdAt: Date(),
            isGroup: false
        )
        mockConversationRepo.mockConversations = [conversation]
        
        // When: ViewModel loads conversations
        sut = ConversationsListViewModel(
            conversationRepository: mockConversationRepo,
            userRepository: mockUserRepo,
            currentUserId: "user-1"
        )
        
        // Give time for observation to trigger
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Then: Conversations should be loaded
        XCTAssertEqual(sut.conversations.count, 1)
        XCTAssertEqual(sut.conversations[0].unreadCount(for: "user-1"), 3)
        
        // Note: UIApplication.applicationIconBadgeNumber is set in updateBadgeCount()
        // but cannot be verified in unit tests (requires UI testing or manual verification)
    }
    
    func testBadgeCountUpdatesMultipleConversations() async throws {
        // Given: Multiple conversations with different unread counts
        let conv1 = Conversation(
            id: "conv-1",
            participantIds: ["user-1", "user-2"],
            lastMessage: "Message 1",
            lastMessageTimestamp: Date(),
            unreadCounts: ["user-1": 2],
            createdAt: Date(),
            isGroup: false
        )
        let conv2 = Conversation(
            id: "conv-2",
            participantIds: ["user-1", "user-3"],
            lastMessage: "Message 2",
            lastMessageTimestamp: Date(),
            unreadCounts: ["user-1": 5],
            createdAt: Date(),
            isGroup: false
        )
        let conv3 = Conversation(
            id: "conv-3",
            participantIds: ["user-1", "user-4"],
            lastMessage: "Message 3",
            lastMessageTimestamp: Date(),
            unreadCounts: ["user-1": 1],
            createdAt: Date(),
            isGroup: false
        )
        mockConversationRepo.mockConversations = [conv1, conv2, conv3]
        
        // When: ViewModel loads conversations
        sut = ConversationsListViewModel(
            conversationRepository: mockConversationRepo,
            userRepository: mockUserRepo,
            currentUserId: "user-1"
        )
        
        // Give time for observation to trigger
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Then: All conversations loaded
        XCTAssertEqual(sut.conversations.count, 3)
        
        // Verify each conversation's unread count
        let totalUnread = sut.conversations.reduce(0) { $0 + $1.unreadCount(for: "user-1") }
        XCTAssertEqual(totalUnread, 8) // 2 + 5 + 1
        
        // Note: Badge count = 8 would be set in UIApplication
    }
    
    func testBadgeCountZeroWhenAllRead() async throws {
        // Given: Conversations with zero unread counts
        let conv1 = Conversation(
            id: "conv-1",
            participantIds: ["user-1", "user-2"],
            lastMessage: "Read message",
            lastMessageTimestamp: Date(),
            unreadCounts: ["user-1": 0],
            createdAt: Date(),
            isGroup: false
        )
        let conv2 = Conversation(
            id: "conv-2",
            participantIds: ["user-1", "user-3"],
            lastMessage: "Another read message",
            lastMessageTimestamp: Date(),
            unreadCounts: ["user-1": 0],
            createdAt: Date(),
            isGroup: false
        )
        mockConversationRepo.mockConversations = [conv1, conv2]
        
        // When: ViewModel loads conversations
        sut = ConversationsListViewModel(
            conversationRepository: mockConversationRepo,
            userRepository: mockUserRepo,
            currentUserId: "user-1"
        )
        
        // Give time for observation to trigger
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Then: All messages are read
        let totalUnread = sut.conversations.reduce(0) { $0 + $1.unreadCount(for: "user-1") }
        XCTAssertEqual(totalUnread, 0)
        
        // Note: Badge count = 0 would be set in UIApplication (clears badge)
    }

    // MARK: - Deep Link Fallback Tests (Story 2.10a)

    func testFetchConversationWithParticipants_Success() async throws {
        // Given
        let conversationId = "test-conv-123"
        let user1 = User(id: "user-1", email: "user1@test.com", displayName: "User 1", isOnline: true, lastSeen: Date(), createdAt: Date())
        let user2 = User(id: "user-2", email: "user2@test.com", displayName: "User 2", isOnline: false, lastSeen: Date(), createdAt: Date())

        let expectedConversation = Conversation(
            id: conversationId,
            participantIds: ["user-1", "user-2"],
            lastMessage: "Test message",
            lastMessageTimestamp: Date(),
            lastMessageSenderId: "user-2",
            lastMessageId: nil,
            unreadCounts: [:],
            typingUsers: [],
            createdAt: Date(),
            isGroup: false,
            groupName: nil,
            lastAISummaryAt: nil,
            hasUnreadPriority: false,
            priorityCount: 0,
            activeSchedulingDetected: false
        )

        mockConversationRepo.mockConversations = [expectedConversation]
        mockUserRepo.mockUsers = [user1, user2]

        // When
        let (conversation, participants) = try await sut.fetchConversationWithParticipants(id: conversationId)

        // Then
        XCTAssertEqual(conversation.id, conversationId, "Should return correct conversation")
        XCTAssertEqual(participants.count, 2, "Should return all participants")
        XCTAssertTrue(mockConversationRepo.getConversationCalled, "Should call getConversation")
    }

    func testFetchConversationWithParticipants_ConversationNotFound() async throws {
        // Given
        let conversationId = "non-existent"
        mockConversationRepo.shouldFail = true
        mockConversationRepo.mockError = RepositoryError.conversationNotFound(conversationId)

        // When/Then
        do {
            _ = try await sut.fetchConversationWithParticipants(id: conversationId)
            XCTFail("Should throw conversationNotFound error")
        } catch {
            // Expected error
            XCTAssertTrue(mockConversationRepo.getConversationCalled, "Should attempt to fetch conversation")
        }
    }

    func testFetchConversationWithParticipants_NetworkError() async throws {
        // Given
        let conversationId = "test-conv-456"
        mockConversationRepo.shouldFail = true
        mockConversationRepo.mockError = NSError(domain: "Network", code: -1009, userInfo: nil)

        // When/Then
        do {
            _ = try await sut.fetchConversationWithParticipants(id: conversationId)
            XCTFail("Should throw network error")
        } catch {
            // Expected error
            XCTAssertTrue(mockConversationRepo.getConversationCalled, "Should attempt to fetch conversation")
        }
    }
}

