import XCTest
import Combine
@testable import MessageAI

/// Unit tests for ConversationsListViewModel
@MainActor
final class ConversationsListViewModelTests: XCTestCase {
    
    var sut: ConversationsListViewModel!
    var mockConversationRepo: MockConversationRepository!
    var mockUserRepo: MockUserRepository!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockConversationRepo = MockConversationRepository()
        mockUserRepo = MockUserRepository()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        sut = nil
        mockConversationRepo = nil
        mockUserRepo = nil
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
            currentUserId: "user-1"
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
            currentUserId: "user-1"
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
            currentUserId: "user-1"
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
            currentUserId: "user-1"
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
            currentUserId: "user-1"
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
            currentUserId: "user-1"
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
            currentUserId: "user-1"
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
            currentUserId: "user-1"
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
            currentUserId: "user-1"
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
            currentUserId: "user-1"
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
            currentUserId: "user-1"
        )
        
        // Give time for publisher and user loading to complete
        try await Task.sleep(nanoseconds: 300_000_000)
        
        // Then
        XCTAssertTrue(mockUserRepo.getUserCalled)
        // Note: In a real implementation, we'd verify that all participant users were loaded
        // For now, we just verify that getUser was called
    }
}

