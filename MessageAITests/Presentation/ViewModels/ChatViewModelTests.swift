import XCTest
import Combine
@testable import MessageAI

@MainActor
final class ChatViewModelTests: XCTestCase {
    var sut: ChatViewModel!
    var mockMessageRepo: MockMessageRepository!
    var mockConversationRepo: MockConversationRepository!
    var mockUserRepo: MockUserRepository!
    var mockStorageRepo: MockStorageRepository!

    override func setUp() async throws {
        try await super.setUp()

        // Clear failed message store to prevent test pollution
        let store = FailedMessageStore()
        store.clearAll()

        mockMessageRepo = MockMessageRepository()
        mockConversationRepo = MockConversationRepository()
        mockUserRepo = MockUserRepository()
        mockStorageRepo = MockStorageRepository()

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
            userRepository: mockUserRepo,
            storageRepository: mockStorageRepo
        )
        
        // Small delay to allow initialization
        try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
    }
    
    override func tearDown() async throws {
        sut = nil
        mockMessageRepo = nil
        mockConversationRepo = nil
        mockUserRepo = nil
        mockStorageRepo = nil
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
            userRepository: mockUserRepo,
            storageRepository: mockStorageRepo
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
        XCTAssertEqual(sut.messages.count, 1) // Message kept with .failed status
        XCTAssertEqual(sut.messages.first?.status, .failed)
    }
    
    func testSendMessage_Failure_KeepsMessageWithFailedStatus() async throws {
        // Given
        sut.messageText = "Hello"
        mockMessageRepo.shouldFail = true
        
        // When
        await sut.sendMessage()
        
        // Then
        XCTAssertEqual(sut.messages.count, 1) // Message kept with .failed status
        XCTAssertEqual(sut.messages.first?.status, .failed)
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
            userRepository: mockUserRepo,
            storageRepository: mockStorageRepo
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
            userRepository: mockUserRepo,
            storageRepository: mockStorageRepo
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
            userRepository: mockUserRepo,
            storageRepository: mockStorageRepo
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
            userRepository: mockUserRepo,
            storageRepository: mockStorageRepo
        )
        
        // Wait for async participant loading
        try await Task.sleep(nanoseconds: 300_000_000)
        
        // Get sender name for other user
        let senderName = sut.getSenderName(for: "other-user")
        
        // Then: Returns display name
        XCTAssertEqual(senderName, "Alice")
    }
    
    // MARK: - Message Editing Tests
    
    func testStartEdit_SetsEditingState() async throws {
        // Given
        let message = createTestMessage(id: "msg1", text: "Original text", senderId: "user1")
        sut.messages = [message]
        
        // When
        sut.startEdit(message: message)
        
        // Then
        XCTAssertTrue(sut.isEditingMessage)
        XCTAssertEqual(sut.editingMessageId, "msg1")
        XCTAssertEqual(sut.editingMessageText, "Original text")
    }
    
    func testStartEdit_OnlyForOwnMessages() async throws {
        // Given: Message from another user
        let message = createTestMessage(id: "msg1", text: "Other user's text", senderId: "user2")
        sut.messages = [message]
        
        // When
        sut.startEdit(message: message)
        
        // Then: Edit mode NOT activated
        XCTAssertFalse(sut.isEditingMessage)
        XCTAssertNil(sut.editingMessageId)
        XCTAssertEqual(sut.editingMessageText, "")
    }
    
    func testCancelEdit_ClearsEditingState() async throws {
        // Given: Edit mode active
        let message = createTestMessage(id: "msg1", text: "Original text", senderId: "user1")
        sut.messages = [message]
        sut.startEdit(message: message)
        XCTAssertTrue(sut.isEditingMessage)
        
        // When
        sut.cancelEdit()
        
        // Then
        XCTAssertFalse(sut.isEditingMessage)
        XCTAssertNil(sut.editingMessageId)
        XCTAssertEqual(sut.editingMessageText, "")
    }
    
    func testSaveEdit_Success_UpdatesMessage() async throws {
        // Given
        let message = createTestMessage(id: "msg1", text: "Original text", senderId: "user1")
        sut.messages = [message]
        sut.startEdit(message: message)
        sut.editingMessageText = "Edited text"
        
        // When
        await sut.saveEdit()
        
        // Then: Message updated optimistically
        XCTAssertEqual(sut.messages[0].text, "Edited text")
        XCTAssertTrue(sut.messages[0].isEdited)
        
        // Repository called
        XCTAssertTrue(mockMessageRepo.editMessageCalled)
        XCTAssertEqual(mockMessageRepo.capturedEditMessageId, "msg1")
        XCTAssertEqual(mockMessageRepo.capturedEditNewText, "Edited text")
        
        // Edit mode cleared
        XCTAssertFalse(sut.isEditingMessage)
    }
    
    func testSaveEdit_EmptyText_CancelsEdit() async throws {
        // Given
        let message = createTestMessage(id: "msg1", text: "Original text", senderId: "user1")
        sut.messages = [message]
        sut.startEdit(message: message)
        sut.editingMessageText = ""
        
        // When
        await sut.saveEdit()
        
        // Then: Edit cancelled, no repository call
        XCTAssertFalse(mockMessageRepo.editMessageCalled)
        XCTAssertFalse(sut.isEditingMessage)
        XCTAssertEqual(sut.messages[0].text, "Original text") // Unchanged
    }
    
    func testSaveEdit_WhitespaceOnly_CancelsEdit() async throws {
        // Given
        let message = createTestMessage(id: "msg1", text: "Original text", senderId: "user1")
        sut.messages = [message]
        sut.startEdit(message: message)
        sut.editingMessageText = "   \n  \t  "
        
        // When
        await sut.saveEdit()
        
        // Then: Edit cancelled, no repository call
        XCTAssertFalse(mockMessageRepo.editMessageCalled)
        XCTAssertFalse(sut.isEditingMessage)
        XCTAssertEqual(sut.messages[0].text, "Original text") // Unchanged
    }
    
    func testSaveEdit_TrimWhitespace_UsesTrimmedText() async throws {
        // Given
        let message = createTestMessage(id: "msg1", text: "Original", senderId: "user1")
        sut.messages = [message]
        sut.startEdit(message: message)
        sut.editingMessageText = "  Edited text  \n"
        
        // When
        await sut.saveEdit()
        
        // Then: Trimmed text used
        XCTAssertEqual(sut.messages[0].text, "Edited text")
        XCTAssertEqual(mockMessageRepo.capturedEditNewText, "Edited text")
    }
    
    func testSaveEdit_MaxLength_ShowsError() async throws {
        // Given
        let message = createTestMessage(id: "msg1", text: "Original", senderId: "user1")
        sut.messages = [message]
        sut.startEdit(message: message)
        sut.editingMessageText = String(repeating: "a", count: 10001) // Over 10,000 limit
        
        // When
        await sut.saveEdit()
        
        // Then: Error shown, no repository call
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertTrue(sut.errorMessage?.contains("too long") ?? false)
        XCTAssertFalse(mockMessageRepo.editMessageCalled)
        XCTAssertEqual(sut.messages[0].text, "Original") // Unchanged
    }
    
    func testSaveEdit_OptimisticUI_UpdatesImmediately() async throws {
        // Given
        let message = createTestMessage(id: "msg1", text: "Original", senderId: "user1")
        sut.messages = [message]
        sut.startEdit(message: message)
        sut.editingMessageText = "Edited"
        
        // When
        await sut.saveEdit()
        
        // Then: Message updated immediately (before repository completes)
        XCTAssertEqual(sut.messages[0].text, "Edited")
        XCTAssertTrue(sut.messages[0].isEdited)
    }
    
    func testSaveEdit_NetworkFailure_RevertsToOriginal() async throws {
        // Given
        let message = createTestMessage(id: "msg1", text: "Original", senderId: "user1")
        sut.messages = [message]
        sut.startEdit(message: message)
        sut.editingMessageText = "Edited"
        
        // Simulate network failure
        mockMessageRepo.shouldFail = true
        mockMessageRepo.mockError = RepositoryError.networkError(NSError(domain: "test", code: -1))
        
        // When
        await sut.saveEdit()
        
        // Then: Reverted to original
        XCTAssertEqual(sut.messages[0].text, "Original")
        XCTAssertFalse(sut.messages[0].isEdited)
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertTrue(sut.errorMessage?.contains("No internet connection") ?? false)
    }
    
    func testShowEditHistory_OpensModal() async throws {
        // Given
        let message = createTestMessage(id: "msg1", text: "Current text", senderId: "user1")
        
        // When
        sut.showEditHistory(for: message)
        
        // Then
        XCTAssertTrue(sut.showEditHistoryModal)
        XCTAssertNotNil(sut.editHistoryMessage)
        XCTAssertEqual(sut.editHistoryMessage?.id, "msg1")
    }
    
    func testCloseEditHistory_ClosesModal() async throws {
        // Given: Modal open
        let message = createTestMessage(id: "msg1", text: "Current text", senderId: "user1")
        sut.showEditHistory(for: message)
        XCTAssertTrue(sut.showEditHistoryModal)
        
        // When
        sut.closeEditHistory()
        
        // Then
        XCTAssertFalse(sut.showEditHistoryModal)
        XCTAssertNil(sut.editHistoryMessage)
    }
    
    // MARK: - Message Deletion Tests
    
    func testCanDelete_OwnMessage_Within24Hours_ReturnsTrue() async {
        // Given
        let message = Message(
            id: "msg1",
            conversationId: "test-conv",
            senderId: "user1",
            text: "Delete me",
            timestamp: Date().addingTimeInterval(-3600), // 1 hour ago
            status: .sent,
            statusUpdatedAt: Date(),
            attachments: [],
            editHistory: nil,
            editCount: 0,
            isEdited: false,
            isDeleted: false,
            deletedAt: nil,
            deletedBy: nil,
            readBy: ["user1"],
            readCount: 1,
            isPriority: false,
            priorityReason: nil,
            schemaVersion: 1
        )
        
        // When
        let canDelete = sut.canDelete(message: message)
        
        // Then
        XCTAssertTrue(canDelete)
    }
    
    func testCanDelete_OtherUsersMessage_ReturnsFalse() async {
        // Given
        let message = createTestMessage(id: "msg1", text: "Someone else's message", senderId: "user2")
        
        // When
        let canDelete = sut.canDelete(message: message)
        
        // Then
        XCTAssertFalse(canDelete)
    }
    
    func testCanDelete_OwnMessage_After24Hours_ReturnsFalse() async {
        // Given
        let message = Message(
            id: "msg1",
            conversationId: "test-conv",
            senderId: "user1",
            text: "Old message",
            timestamp: Date().addingTimeInterval(-25 * 3600), // 25 hours ago
            status: .sent,
            statusUpdatedAt: Date(),
            attachments: [],
            editHistory: nil,
            editCount: 0,
            isEdited: false,
            isDeleted: false,
            deletedAt: nil,
            deletedBy: nil,
            readBy: ["user1"],
            readCount: 1,
            isPriority: false,
            priorityReason: nil,
            schemaVersion: 1
        )
        
        // When
        let canDelete = sut.canDelete(message: message)
        
        // Then
        XCTAssertFalse(canDelete)
    }
    
    func testCanDelete_AlreadyDeleted_ReturnsFalse() async {
        // Given
        let message = Message(
            id: "msg1",
            conversationId: "test-conv",
            senderId: "user1",
            text: "",
            timestamp: Date(),
            status: .sent,
            statusUpdatedAt: Date(),
            attachments: [],
            editHistory: nil,
            editCount: 0,
            isEdited: false,
            isDeleted: true,
            deletedAt: Date(),
            deletedBy: "user1",
            readBy: ["user1"],
            readCount: 1,
            isPriority: false,
            priorityReason: nil,
            schemaVersion: 1
        )
        
        // When
        let canDelete = sut.canDelete(message: message)
        
        // Then
        XCTAssertFalse(canDelete)
    }
    
    func testShowDeleteConfirmation_ValidMessage_ShowsAlert() async {
        // Given
        let message = createTestMessage(id: "msg1", text: "Delete me", senderId: "user1")
        sut.messages = [message]
        
        // When
        sut.showDeleteConfirmation(for: message)
        
        // Then
        XCTAssertTrue(sut.showDeleteConfirmation)
        XCTAssertEqual(sut.messageToDelete?.id, "msg1")
    }
    
    func testShowDeleteConfirmation_OtherUsersMessage_ShowsError() async {
        // Given
        let message = createTestMessage(id: "msg1", text: "Someone else's message", senderId: "user2")
        
        // When
        sut.showDeleteConfirmation(for: message)
        
        // Then
        XCTAssertFalse(sut.showDeleteConfirmation)
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertTrue(sut.errorMessage?.contains("your own") ?? false)
    }
    
    func testShowDeleteConfirmation_MessageOver24Hours_ShowsError() async {
        // Given
        let message = Message(
            id: "msg1",
            conversationId: "test-conv",
            senderId: "user1",
            text: "Old message",
            timestamp: Date().addingTimeInterval(-25 * 3600), // 25 hours ago
            status: .sent,
            statusUpdatedAt: Date(),
            attachments: [],
            editHistory: nil,
            editCount: 0,
            isEdited: false,
            isDeleted: false,
            deletedAt: nil,
            deletedBy: nil,
            readBy: ["user1"],
            readCount: 1,
            isPriority: false,
            priorityReason: nil,
            schemaVersion: 1
        )
        
        // When
        sut.showDeleteConfirmation(for: message)
        
        // Then
        XCTAssertFalse(sut.showDeleteConfirmation)
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertTrue(sut.errorMessage?.contains("24 hours") ?? false)
    }
    
    func testConfirmDelete_Success_MarksDeleted() async {
        // Given
        let message = createTestMessage(id: "msg1", text: "Delete me", senderId: "user1")
        sut.messages = [message]
        sut.messageToDelete = message
        sut.showDeleteConfirmation = true
        
        mockMessageRepo.deleteMessageCalled = false
        mockMessageRepo.shouldFail = false
        
        // When
        await sut.confirmDelete()
        
        // Then
        XCTAssertTrue(mockMessageRepo.deleteMessageCalled)
        XCTAssertEqual(mockMessageRepo.capturedDeleteMessageId, "msg1")
        XCTAssertFalse(sut.showDeleteConfirmation) // Confirmation cleared
        
        // Optimistic update
        XCTAssertTrue(sut.messages[0].isDeleted)
        XCTAssertEqual(sut.messages[0].text, "") // Text cleared
    }
    
    func testConfirmDelete_OptimisticUI_ShowsPlaceholderImmediately() async {
        // Given
        let message = createTestMessage(id: "msg1", text: "Delete me", senderId: "user1")
        sut.messages = [message]
        sut.messageToDelete = message
        
        // When
        await sut.confirmDelete()
        
        // Then - Message marked deleted immediately (before repository returns)
        XCTAssertTrue(sut.messages[0].isDeleted)
        XCTAssertEqual(sut.messages[0].text, "")
        XCTAssertNotNil(sut.messages[0].deletedAt)
        XCTAssertEqual(sut.messages[0].deletedBy, "user1")
    }
    
    func testConfirmDelete_NetworkFailure_RevertsToOriginal() async {
        // Given
        let message = createTestMessage(id: "msg1", text: "Delete me", senderId: "user1")
        sut.messages = [message]
        sut.messageToDelete = message
        
        mockMessageRepo.shouldFail = true
        mockMessageRepo.mockError = RepositoryError.networkError(NSError(domain: "test", code: -1))
        
        // When
        await sut.confirmDelete()
        
        // Then - Reverted to original
        XCTAssertFalse(sut.messages[0].isDeleted)
        XCTAssertEqual(sut.messages[0].text, "Delete me")
        XCTAssertNotNil(sut.errorMessage)
    }
    
    func testConfirmDelete_LastMessage_UpdatesConversationPreview() async {
        // Given
        let message = createTestMessage(id: "msg1", text: "Delete me", senderId: "user1")
        sut.messages = [message]
        sut.messageToDelete = message
        
        let conversation = Conversation(
            id: "test-conv",
            participantIds: ["user1", "user2"],
            lastMessage: "Delete me",
            lastMessageTimestamp: Date(),
            lastMessageSenderId: "user1",
            lastMessageId: "msg1", // This is the message being deleted
            unreadCounts: [:],
            typingUsers: [],
            createdAt: Date(),
            isGroup: false
        )
        sut.conversation = conversation
        
        mockConversationRepo.updateConversationCalled = false
        
        // When
        await sut.confirmDelete()
        
        // Then
        XCTAssertTrue(mockConversationRepo.updateConversationCalled)
        let updates = mockConversationRepo.capturedUpdates
        XCTAssertEqual(updates?["lastMessage"] as? String, "[Message deleted]")
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
    
    // MARK: - Conversation Tracking Tests (Story 2.10)
    
    func testCurrentlyViewingConversationTracking() async throws {
        // Given: No conversation is being viewed
        XCTAssertNil(ChatViewModel.currentlyViewingConversationId)
        
        // When: onAppear is called
        sut.onAppear()
        
        // Then: Conversation ID should be set
        XCTAssertEqual(ChatViewModel.currentlyViewingConversationId, "test-conv")
        
        // When: onDisappear is called
        sut.onDisappear()
        
        // Then: Conversation ID should be cleared
        XCTAssertNil(ChatViewModel.currentlyViewingConversationId)
    }
    
    func testCurrentlyViewingConversationMultipleChats() async throws {
        // Given: First chat view appears
        sut.onAppear()
        XCTAssertEqual(ChatViewModel.currentlyViewingConversationId, "test-conv")
        
        // When: Second chat view appears (new conversation)
        let sut2 = ChatViewModel(
            conversationId: "test-conv-2",
            currentUserId: "user1",
            messageRepository: mockMessageRepo,
            conversationRepository: mockConversationRepo,
            userRepository: mockUserRepo,
            storageRepository: mockStorageRepo
        )
        sut2.onAppear()
        
        // Then: Should track second conversation
        XCTAssertEqual(ChatViewModel.currentlyViewingConversationId, "test-conv-2")
        
        // When: Second chat disappears
        sut2.onDisappear()
        
        // Then: Should clear (not revert to first)
        XCTAssertNil(ChatViewModel.currentlyViewingConversationId)
        
        // Cleanup
        sut.onDisappear()
    }
    
    // MARK: - Read Receipts Tests (Story 2.5)
    
    func testMarkMessagesAsRead_FiltersOwnMessages() async throws {
        // Given: 5 messages - 2 from current user, 3 from others
        let ownMessage1 = createTestMessage(id: "own1", text: "My message 1", senderId: "user1")
        let ownMessage2 = createTestMessage(id: "own2", text: "My message 2", senderId: "user1")
        let otherMessage1 = Message(id: "other1", conversationId: "test-conv", senderId: "user2", text: "Other 1", readBy: [], readCount: 0)
        let otherMessage2 = Message(id: "other2", conversationId: "test-conv", senderId: "user2", text: "Other 2", readBy: [], readCount: 0)
        let otherMessage3 = Message(id: "other3", conversationId: "test-conv", senderId: "user2", text: "Other 3", readBy: [], readCount: 0)
        
        sut.messages = [ownMessage1, otherMessage1, ownMessage2, otherMessage2, otherMessage3]
        
        // When: markMessagesAsRead is called
        await sut.markMessagesAsRead()
        
        // Then: Only 3 messages should be marked (own messages excluded)
        XCTAssertTrue(mockMessageRepo.markMessagesAsReadCalled)
        XCTAssertEqual(mockMessageRepo.capturedReadMessageIds?.count, 3)
        XCTAssertEqual(Set(mockMessageRepo.capturedReadMessageIds ?? []), Set(["other1", "other2", "other3"]))
    }
    
    func testMarkMessagesAsRead_AlreadyRead() async throws {
        // Given: All messages already read by current user
        let message1 = Message(id: "msg1", conversationId: "test-conv", senderId: "user2", text: "Hello", readBy: ["user1"], readCount: 1)
        let message2 = Message(id: "msg2", conversationId: "test-conv", senderId: "user2", text: "Hi", readBy: ["user1"], readCount: 1)
        
        sut.messages = [message1, message2]
        
        // When: markMessagesAsRead is called
        await sut.markMessagesAsRead()
        
        // Then: Repository should NOT be called (no unread messages)
        XCTAssertFalse(mockMessageRepo.markMessagesAsReadCalled)
    }
    
    func testMarkMessagesAsRead_OptimisticUI() async throws {
        // Given: 2 unread messages from others
        let message1 = Message(id: "msg1", conversationId: "test-conv", senderId: "user2", text: "Hello", status: .delivered, readBy: [], readCount: 0)
        let message2 = Message(id: "msg2", conversationId: "test-conv", senderId: "user2", text: "Hi", status: .delivered, readBy: [], readCount: 0)
        
        sut.messages = [message1, message2]
        
        // When: markMessagesAsRead is called
        await sut.markMessagesAsRead()
        
        // Then: Local messages array should be updated immediately
        XCTAssertTrue(sut.messages[0].readBy.contains("user1"))
        XCTAssertEqual(sut.messages[0].readCount, 1)
        XCTAssertEqual(sut.messages[0].status, .read)
        
        XCTAssertTrue(sut.messages[1].readBy.contains("user1"))
        XCTAssertEqual(sut.messages[1].readCount, 1)
        XCTAssertEqual(sut.messages[1].status, .read)
    }
    
    func testMarkMessagesAsRead_CallsRepository() async throws {
        // Given: 2 unread messages
        let message1 = Message(id: "msg1", conversationId: "test-conv", senderId: "user2", text: "Hello", readBy: [], readCount: 0)
        let message2 = Message(id: "msg2", conversationId: "test-conv", senderId: "user2", text: "Hi", readBy: [], readCount: 0)
        
        sut.messages = [message1, message2]
        
        // When: markMessagesAsRead is called
        await sut.markMessagesAsRead()
        
        // Then: Repository should be called with correct parameters
        XCTAssertTrue(mockMessageRepo.markMessagesAsReadCalled)
        XCTAssertEqual(mockMessageRepo.capturedReadMessageIds?.count, 2)
        XCTAssertEqual(mockMessageRepo.capturedReadUserId, "user1")
        XCTAssertTrue(mockMessageRepo.capturedReadMessageIds?.contains("msg1") ?? false)
        XCTAssertTrue(mockMessageRepo.capturedReadMessageIds?.contains("msg2") ?? false)
    }
    
    func testOnAppear_CallsMarkMessagesAsRead() async throws {
        // Given: 1 unread message
        let message = Message(id: "msg1", conversationId: "test-conv", senderId: "user2", text: "Hello", readBy: [], readCount: 0)
        sut.messages = [message]
        
        // When: onAppear is called
        sut.onAppear()
        
        // Give time for async task to complete
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Then: Messages should be marked as read
        XCTAssertTrue(mockMessageRepo.markMessagesAsReadCalled)
        XCTAssertEqual(mockMessageRepo.capturedReadMessageIds?.count, 1)
    }
    
    func testMarkMessagesAsRead_StatusTransition() async throws {
        // Given: Message with .delivered status
        let message = Message(id: "msg1", conversationId: "test-conv", senderId: "user2", text: "Hello", status: .delivered, readBy: [], readCount: 0)
        sut.messages = [message]
        
        // When: markMessagesAsRead is called
        await sut.markMessagesAsRead()
        
        // Then: Status should upgrade to .read
        XCTAssertEqual(sut.messages[0].status, .read)
    }
    
    func testOnReadReceiptTapped() async throws {
        // Given: A message
        let message = createTestMessage(id: "msg1", text: "Hello", senderId: "user1")
        
        // When: onReadReceiptTapped is called
        sut.onReadReceiptTapped(message)
        
        // Then: readReceiptTapped should be set
        XCTAssertNotNil(sut.readReceiptTapped)
        XCTAssertEqual(sut.readReceiptTapped?.id, "msg1")
    }
    
    // MARK: - Failed Message Retry Tests (Story 2.4)
    
    func testSendMessageFailure_MarksAsFailed() async throws {
        // Given: Repository configured to fail
        mockMessageRepo.shouldFail = true
        mockMessageRepo.mockError = RepositoryError.networkError(NSError(domain: "test", code: -1))
        sut.messageText = "This will fail"
        
        // When: Send message
        await sut.sendMessage()
        
        // Then: Message should be in array with .failed status
        XCTAssertEqual(sut.messages.count, 1)
        XCTAssertEqual(sut.messages.first?.status, .failed)
        XCTAssertEqual(sut.messages.first?.text, "This will fail")
        XCTAssertNotNil(sut.errorMessage)
    }
    
    func testRetryMessage_Success() async throws {
        // Given: A failed message in the array
        let failedMessage = Message(
            id: "msg-failed",
            conversationId: "test-conv",
            senderId: "user1",
            text: "Failed message",
            status: .failed
        )
        sut.messages = [failedMessage]
        
        // Configure repository to succeed
        mockMessageRepo.shouldFail = false
        
        // When: Retry the message
        await sut.retryMessage(failedMessage)
        
        // Then: Message status should be .sent
        XCTAssertEqual(sut.messages.count, 1)
        XCTAssertEqual(sut.messages.first?.status, .sent)
        XCTAssertTrue(mockMessageRepo.sendMessageCalled)
    }
    
    func testRetryMessage_Failure() async throws {
        // Given: A failed message
        let failedMessage = Message(
            id: "msg-failed",
            conversationId: "test-conv",
            senderId: "user1",
            text: "Failed message",
            status: .failed
        )
        sut.messages = [failedMessage]
        
        // Configure repository to fail again
        mockMessageRepo.shouldFail = true
        mockMessageRepo.mockError = RepositoryError.networkError(NSError(domain: "test", code: -1))
        
        // When: Retry the message
        await sut.retryMessage(failedMessage)
        
        // Then: Message status should still be .failed
        XCTAssertEqual(sut.messages.count, 1)
        XCTAssertEqual(sut.messages.first?.status, .failed)
        XCTAssertNotNil(sut.errorMessage)
    }
    
    func testDeleteFailedMessage() async throws {
        // Given: A failed message in the array
        let failedMessage = Message(
            id: "msg-failed",
            conversationId: "test-conv",
            senderId: "user1",
            text: "Failed message",
            status: .failed
        )
        sut.messages = [failedMessage]
        
        // When: Delete the failed message
        sut.deleteFailedMessage(failedMessage)
        
        // Then: Message should be removed from array
        XCTAssertEqual(sut.messages.count, 0)
    }
    
    func testOnFailedMessageTapped() async throws {
        // Given: A failed message
        let failedMessage = Message(
            id: "msg-failed",
            conversationId: "test-conv",
            senderId: "user1",
            text: "Failed message",
            status: .failed
        )
        
        // When: Tap the failed message
        sut.onFailedMessageTapped(failedMessage)
        
        // Then: failedMessageTapped should be set
        XCTAssertNotNil(sut.failedMessageTapped)
        XCTAssertEqual(sut.failedMessageTapped?.id, "msg-failed")
    }
    
    func testMapErrorToUserMessage_NetworkError() async throws {
        // Given: Network error
        mockMessageRepo.shouldFail = true
        mockMessageRepo.mockError = RepositoryError.networkError(NSError(domain: "test", code: -1))
        sut.messageText = "Test"
        
        // When: Send message (fails)
        await sut.sendMessage()
        
        // Then: User-friendly error message
        XCTAssertTrue(sut.errorMessage?.contains("internet") ?? false)
        XCTAssertTrue(sut.errorMessage?.contains("retry") ?? false)
    }
    
    func testMultipleFailedMessages() async throws {
        // Given: Multiple send failures
        mockMessageRepo.shouldFail = true
        mockMessageRepo.mockError = RepositoryError.networkError(NSError(domain: "test", code: -1))
        
        // When: Send 3 messages
        sut.messageText = "Message 1"
        await sut.sendMessage()
        sut.messageText = "Message 2"
        await sut.sendMessage()
        sut.messageText = "Message 3"
        await sut.sendMessage()
        
        // Then: All 3 should be in array with .failed status
        XCTAssertEqual(sut.messages.count, 3)
        XCTAssertTrue(sut.messages.allSatisfy { $0.status == .failed })
    }
}

