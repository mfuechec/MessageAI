import XCTest
import Combine
@testable import MessageAI

@MainActor
final class ChatViewModelTests: XCTestCase {
    var sut: ChatViewModel!
    var mockMessageRepo: MockMessageRepository!
    var mockConversationRepo: MockConversationRepository!
    var mockUserRepo: MockUserRepository!
    
    override func setUp() async throws {
        try await super.setUp()
        mockMessageRepo = MockMessageRepository()
        mockConversationRepo = MockConversationRepository()
        mockUserRepo = MockUserRepository()
        
        // Set up default mock conversation
        mockConversationRepo.mockConversation = Conversation(
            id: "test-conv",
            participantIds: ["user1", "user2"],
            lastMessage: nil,
            lastMessageTimestamp: nil,
            unreadCounts: [:],
            createdAt: Date(),
            isGroup: false
        )
        
        sut = ChatViewModel(
            conversationId: "test-conv",
            currentUserId: "user1",
            messageRepository: mockMessageRepo,
            conversationRepository: mockConversationRepo,
            userRepository: mockUserRepo
        )
        
        // Small delay to allow initialization
        try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
    }
    
    override func tearDown() async throws {
        sut = nil
        mockMessageRepo = nil
        mockConversationRepo = nil
        mockUserRepo = nil
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInit_StartsObservingMessages() async throws {
        // Then
        XCTAssertTrue(mockMessageRepo.observeMessagesCalled)
        XCTAssertEqual(mockMessageRepo.capturedConversationId, "test-conv")
    }
    
    func testObserveMessages_UpdatesMessagesArray() async throws {
        // Given
        let message1 = createTestMessage(id: "msg1", text: "Hello", senderId: "user2")
        let message2 = createTestMessage(id: "msg2", text: "Hi", senderId: "user1")
        mockMessageRepo.mockMessages = [message1, message2]
        
        // When
        sut = ChatViewModel(
            conversationId: "test-conv",
            currentUserId: "user1",
            messageRepository: mockMessageRepo,
            conversationRepository: mockConversationRepo,
            userRepository: mockUserRepo
        )
        
        // Give time for observation to complete
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Then
        XCTAssertEqual(sut.messages.count, 2)
        XCTAssertEqual(sut.messages[0].id, "msg1")
        XCTAssertEqual(sut.messages[1].id, "msg2")
    }
    
    // MARK: - Send Message Tests
    
    func testSendMessage_Success_AppendsMessageOptimistically() async throws {
        // Given
        sut.messageText = "Hello"
        XCTAssertEqual(sut.messages.count, 0)
        
        // When
        await sut.sendMessage()
        
        // Then
        XCTAssertEqual(sut.messages.count, 1)
        XCTAssertEqual(sut.messages.first?.text, "Hello")
        XCTAssertEqual(sut.messages.first?.senderId, "user1")
    }
    
    func testSendMessage_Success_CallsRepository() async throws {
        // Given
        sut.messageText = "Test message"
        
        // When
        await sut.sendMessage()
        
        // Then
        XCTAssertTrue(mockMessageRepo.sendMessageCalled)
        XCTAssertEqual(mockMessageRepo.capturedMessage?.text, "Test message")
        XCTAssertEqual(mockMessageRepo.capturedMessage?.conversationId, "test-conv")
        XCTAssertEqual(mockMessageRepo.capturedMessage?.senderId, "user1")
    }
    
    func testSendMessage_Success_ClearsMessageText() async throws {
        // Given
        sut.messageText = "Hello"
        
        // When
        await sut.sendMessage()
        
        // Then
        XCTAssertEqual(sut.messageText, "")
    }
    
    func testSendMessage_Success_UpdatesConversation() async throws {
        // Given
        sut.messageText = "Hello"
        
        // When
        await sut.sendMessage()
        
        // Then
        XCTAssertTrue(mockConversationRepo.updateConversationCalled)
        XCTAssertEqual(mockConversationRepo.capturedConversationId, "test-conv")
        XCTAssertNotNil(mockConversationRepo.capturedUpdates?["lastMessage"])
    }
    
    func testSendMessage_EmptyText_DoesNotSend() async throws {
        // Given
        sut.messageText = ""
        
        // When
        await sut.sendMessage()
        
        // Then
        XCTAssertFalse(mockMessageRepo.sendMessageCalled)
        XCTAssertEqual(sut.messages.count, 0)
    }
    
    func testSendMessage_WhitespaceOnly_DoesNotSend() async throws {
        // Given
        sut.messageText = "   "
        
        // When
        await sut.sendMessage()
        
        // Then
        XCTAssertFalse(mockMessageRepo.sendMessageCalled)
        XCTAssertEqual(sut.messages.count, 0)
    }
    
    func testSendMessage_TrimsWhitespace() async throws {
        // Given
        sut.messageText = "  Hello  "
        
        // When
        await sut.sendMessage()
        
        // Then
        XCTAssertTrue(mockMessageRepo.sendMessageCalled)
        XCTAssertEqual(mockMessageRepo.capturedMessage?.text, "Hello")
    }
    
    func testSendMessage_ExceedsMaxLength_ShowsError() async throws {
        // Given
        let longText = String(repeating: "a", count: 10001)
        sut.messageText = longText
        
        // When
        await sut.sendMessage()
        
        // Then
        XCTAssertFalse(mockMessageRepo.sendMessageCalled)
        XCTAssertEqual(sut.errorMessage, "Message too long (max 10,000 characters)")
        XCTAssertEqual(sut.messages.count, 0)
    }
    
    func testSendMessage_MaxLengthExactly_Sends() async throws {
        // Given
        let maxText = String(repeating: "a", count: 10000)
        sut.messageText = maxText
        
        // When
        await sut.sendMessage()
        
        // Then
        XCTAssertTrue(mockMessageRepo.sendMessageCalled)
        XCTAssertEqual(mockMessageRepo.capturedMessage?.text.count, 10000)
    }
    
    func testSendMessage_Failure_ShowsError() async throws {
        // Given
        sut.messageText = "Hello"
        mockMessageRepo.shouldFail = true
        mockMessageRepo.mockError = RepositoryError.messageNotFound("Send failed")
        
        // When
        await sut.sendMessage()
        
        // Then
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertTrue(sut.errorMessage?.contains("Failed to send message") ?? false)
    }
    
    func testSendMessage_Failure_RemovesOptimisticMessage() async throws {
        // Given
        sut.messageText = "Hello"
        mockMessageRepo.shouldFail = true
        
        // When
        await sut.sendMessage()
        
        // Then
        XCTAssertEqual(sut.messages.count, 0) // Optimistic message was removed
    }
    
    func testSendMessage_SetsSendingStatus() async throws {
        // Given
        sut.messageText = "Hello"
        
        // When
        await sut.sendMessage()
        
        // Then
        XCTAssertEqual(mockMessageRepo.capturedMessage?.status, .sending)
    }
    
    // MARK: - Display Helper Tests
    
    func testDisplayName_CurrentUser_ReturnsYou() async throws {
        // Given
        let displayName = sut.displayName(for: "user1")
        
        // Then
        XCTAssertEqual(displayName, "You")
    }
    
    func testDisplayName_OtherUser_ReturnsDisplayName() async throws {
        // Given
        mockUserRepo.mockUser = User(
            id: "user2",
            email: "test@example.com",
            displayName: "John Doe",
            profileImageURL: nil,
            isOnline: true,
            lastSeen: Date(),
            createdAt: Date(),
            fcmToken: nil,
            timezone: nil,
            locale: nil,
            preferredLanguage: nil,
            schemaVersion: 1
        )
        sut.users["user2"] = mockUserRepo.mockUser
        
        // When
        let displayName = sut.displayName(for: "user2")
        
        // Then
        XCTAssertEqual(displayName, "John Doe")
    }
    
    func testDisplayName_UnknownUser_ReturnsUnknown() async throws {
        // Given
        let displayName = sut.displayName(for: "unknown-user")
        
        // Then
        XCTAssertEqual(displayName, "Unknown")
    }
    
    func testFormattedTimestamp_ReturnsRelativeTime() async throws {
        // Given
        let message = createTestMessage(id: "msg1", text: "Hello", senderId: "user1")
        
        // When
        let formattedTime = sut.formattedTimestamp(for: message)
        
        // Then
        XCTAssertFalse(formattedTime.isEmpty)
        // Should return something like "now" or "0 sec ago"
    }
    
    // MARK: - Load Participant Users Tests
    
    func testLoadParticipantUsers_FetchesUserDetails() async throws {
        // Given
        mockUserRepo.mockUser = User(
            id: "user2",
            email: "test@example.com",
            displayName: "Jane Doe",
            profileImageURL: nil,
            isOnline: true,
            lastSeen: Date(),
            createdAt: Date(),
            fcmToken: nil,
            timezone: nil,
            locale: nil,
            preferredLanguage: nil,
            schemaVersion: 1
        )
        
        // When
        sut = ChatViewModel(
            conversationId: "test-conv",
            currentUserId: "user1",
            messageRepository: mockMessageRepo,
            conversationRepository: mockConversationRepo,
            userRepository: mockUserRepo
        )
        
        // Give time for async loading
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Then
        // Story 2.1: Changed to use getUsers(ids:) instead of getUser(id:)
        XCTAssertTrue(mockUserRepo.getUsersCalled)
        // Users should be loaded
        XCTAssertTrue(mockConversationRepo.getConversationCalled)
    }
    
    // MARK: - Error Handling Tests
    
    func testClearError_ClearsErrorMessage() async throws {
        // Given
        sut.errorMessage = "Test error"
        
        // When
        sut.clearError()
        
        // Then
        XCTAssertNil(sut.errorMessage)
    }
    
    // MARK: - Pagination Tests
    
    func testLoadMoreMessages_IsStub() async throws {
        // When
        await sut.loadMoreMessages()
        
        // Then
        // Should not crash - stub implementation
        XCTAssertTrue(true)
    }
    
    // MARK: - Group Conversation Tests (Story 2.1)
    
    func testIsGroupConversation_TwoParticipants_ReturnsFalse() async throws {
        // Given: One-on-one conversation - need to recreate SUT with new conversation
        let oneOnOneConv = Conversation(
            id: "conv-1",
            participantIds: ["user1", "user2"],
            lastMessage: nil,
            lastMessageTimestamp: nil,
            createdAt: Date(),
            isGroup: false
        )
        mockConversationRepo.mockConversation = oneOnOneConv
        mockUserRepo.mockUsers = [
            User(id: "user1", email: "user1@test.com", displayName: "User 1"),
            User(id: "user2", email: "user2@test.com", displayName: "User 2")
        ]
        
        // When: Create new SUT with this conversation
        sut = ChatViewModel(
            conversationId: "conv-1",
            currentUserId: "user1",
            messageRepository: mockMessageRepo,
            conversationRepository: mockConversationRepo,
            userRepository: mockUserRepo
        )
        
        // Wait for async init to complete
        try await Task.sleep(nanoseconds: 200_000_000)
        
        // Then: Is not a group
        XCTAssertFalse(sut.isGroupConversation)
    }
    
    func testIsGroupConversation_ThreeParticipants_ReturnsTrue() async throws {
        // Given: Group conversation - need to recreate SUT with new conversation
        let groupConv = Conversation(
            id: "conv-1",
            participantIds: ["user1", "user2", "user3"],
            lastMessage: nil,
            lastMessageTimestamp: nil,
            createdAt: Date(),
            isGroup: true
        )
        mockConversationRepo.mockConversation = groupConv
        mockUserRepo.mockUsers = [
            User(id: "user1", email: "user1@test.com", displayName: "User 1"),
            User(id: "user2", email: "user2@test.com", displayName: "User 2"),
            User(id: "user3", email: "user3@test.com", displayName: "User 3")
        ]
        
        // When: Create new SUT with this conversation
        sut = ChatViewModel(
            conversationId: "conv-1",
            currentUserId: "user1",
            messageRepository: mockMessageRepo,
            conversationRepository: mockConversationRepo,
            userRepository: mockUserRepo
        )
        
        // Wait for async init to complete
        try await Task.sleep(nanoseconds: 200_000_000)
        
        // Then: Is a group
        XCTAssertTrue(sut.isGroupConversation)
    }
    
    func testGetSenderName_CurrentUser_ReturnsYou() async throws {
        // Given: Current user ID
        let currentUserId = "user1" // Matches setUp
        
        // When: Get sender name for current user
        let senderName = sut.getSenderName(for: currentUserId)
        
        // Then: Returns "You"
        XCTAssertEqual(senderName, "You")
    }
    
    func testGetSenderName_OtherUser_ReturnsDisplayName() async throws {
        // Given: Group conversation with other user - recreate SUT
        let otherUser = User(id: "other-user", email: "other@test.com", displayName: "Alice")
        let currentUser = User(id: "user1", email: "user1@test.com", displayName: "Current")
        mockUserRepo.mockUsers = [currentUser, otherUser]
        
        let groupConv = Conversation(
            id: "conv-1",
            participantIds: ["user1", "other-user"],
            lastMessage: nil,
            lastMessageTimestamp: nil,
            createdAt: Date(),
            isGroup: true
        )
        mockConversationRepo.mockConversation = groupConv
        
        // When: Create new SUT and wait for participants to load
        sut = ChatViewModel(
            conversationId: "conv-1",
            currentUserId: "user1",
            messageRepository: mockMessageRepo,
            conversationRepository: mockConversationRepo,
            userRepository: mockUserRepo
        )
        
        // Wait for async participant loading
        try await Task.sleep(nanoseconds: 300_000_000)
        
        // Get sender name for other user
        let senderName = sut.getSenderName(for: "other-user")
        
        // Then: Returns display name
        XCTAssertEqual(senderName, "Alice")
    }
    
    // MARK: - Helper Methods
    
    private func createTestMessage(id: String, text: String, senderId: String) -> Message {
        return Message(
            id: id,
            conversationId: "test-conv",
            senderId: senderId,
            text: text,
            timestamp: Date(),
            status: .sent,
            statusUpdatedAt: Date(),
            attachments: [],
            editHistory: nil,
            editCount: 0,
            isEdited: false,
            isDeleted: false,
            deletedAt: nil,
            deletedBy: nil,
            readBy: [senderId],
            readCount: 1,
            isPriority: false,
            priorityReason: nil,
            schemaVersion: 1
        )
    }
}

