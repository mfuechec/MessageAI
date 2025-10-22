import XCTest
@testable import MessageAI

@MainActor
final class ChatViewModelPaginationTests: XCTestCase {

    var mockMessageRepo: MockMessageRepository!
    var mockConversationRepo: MockConversationRepository!
    var mockUserRepo: MockUserRepository!
    var mockStorageRepo: MockStorageRepository!
    var mockNetworkMonitor: MockNetworkMonitor!
    var viewModel: ChatViewModel!

    override func setUp() async throws {
        mockMessageRepo = MockMessageRepository()
        mockConversationRepo = MockConversationRepository()
        mockUserRepo = MockUserRepository()
        mockStorageRepo = MockStorageRepository()
        mockNetworkMonitor = MockNetworkMonitor()

        viewModel = ChatViewModel(
            conversationId: "test-conversation",
            currentUserId: "user1",
            messageRepository: mockMessageRepo,
            conversationRepository: mockConversationRepo,
            userRepository: mockUserRepo,
            storageRepository: mockStorageRepo,
            networkMonitor: mockNetworkMonitor
        )

        // Wait for initial setup
        try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds
    }

    // MARK: - Test Load More Messages

    func testLoadMoreMessages_LoadsOlderMessages() async {
        // Given: 100 messages in repository (simulate large conversation)
        var messages: [Message] = []
        for i in 1...100 {
            messages.append(Message(
                id: "msg-\(i)",
                conversationId: "test-conversation",
                senderId: "user2",
                text: "Message \(i)",
                timestamp: Date().addingTimeInterval(TimeInterval(i)),
                status: .sent
            ))
        }
        mockMessageRepo.mockMessages = messages

        // Simulate initial load (first 50 messages)
        viewModel.messages = Array(messages[50..<100])  // Last 50 messages

        // When: Load more messages
        await viewModel.loadMoreMessages()

        // Then: Should have loaded older messages
        XCTAssertEqual(mockMessageRepo.capturedConversationId, "test-conversation")
        XCTAssertEqual(mockMessageRepo.capturedLimit, 50, "Should request 50 messages (page size)")

        // Verify older messages were prepended
        XCTAssertGreaterThan(viewModel.messages.count, 50, "Should have more than initial 50 messages")
    }

    func testLoadMoreMessages_SetsHasMoreFalse_WhenEndReached() async {
        // Given: Only 30 messages exist (less than page size of 50)
        var messages: [Message] = []
        for i in 1...30 {
            messages.append(Message(
                id: "msg-\(i)",
                conversationId: "test-conversation",
                senderId: "user2",
                text: "Message \(i)",
                timestamp: Date().addingTimeInterval(TimeInterval(i)),
                status: .sent
            ))
        }
        mockMessageRepo.mockMessages = messages

        // Simulate initial load
        viewModel.messages = Array(messages[20..<30])  // Last 10 messages
        viewModel.hasMoreMessages = true

        // When: Load more messages
        await viewModel.loadMoreMessages()

        // Then: hasMoreMessages should be false (loaded 20 messages, less than page size of 50)
        XCTAssertFalse(viewModel.hasMoreMessages, "Should set hasMoreMessages to false when fewer than page size returned")
    }

    func testLoadMoreMessages_PreventsConcurrentLoads() async {
        // Given: Multiple messages
        var messages: [Message] = []
        for i in 1...100 {
            messages.append(Message(
                id: "msg-\(i)",
                conversationId: "test-conversation",
                senderId: "user2",
                text: "Message \(i)",
                timestamp: Date().addingTimeInterval(TimeInterval(i)),
                status: .sent
            ))
        }
        mockMessageRepo.mockMessages = messages
        viewModel.messages = Array(messages[50..<100])

        // When: Trigger two concurrent loads
        viewModel.isLoadingMore = true  // Simulate already loading

        let initialCount = viewModel.messages.count

        await viewModel.loadMoreMessages()

        // Then: Second load should be prevented
        XCTAssertEqual(viewModel.messages.count, initialCount, "Should not load when already loading")
    }

    func testLoadMoreMessages_DoesNotLoadWhenNoMoreMessages() async {
        // Given: hasMoreMessages is false
        viewModel.hasMoreMessages = false
        viewModel.messages = [Message(
            id: "msg-1",
            conversationId: "test-conversation",
            senderId: "user2",
            text: "Message 1",
            timestamp: Date(),
            status: .sent
        )]

        let initialCount = viewModel.messages.count

        // When: Try to load more
        await viewModel.loadMoreMessages()

        // Then: Should not load anything
        XCTAssertEqual(viewModel.messages.count, initialCount, "Should not load when hasMoreMessages is false")
    }

    func testLoadMoreMessages_HandlesEmptyMessages() async {
        // Given: No messages loaded yet
        viewModel.messages = []

        // When: Try to load more
        await viewModel.loadMoreMessages()

        // Then: Should set hasMoreMessages to false
        XCTAssertFalse(viewModel.hasMoreMessages, "Should set hasMoreMessages to false when no messages")
        XCTAssertTrue(viewModel.messages.isEmpty, "Messages should remain empty")
    }

    func testLoadMoreMessages_HandlesError() async {
        // Given: Repository will fail
        var messages: [Message] = []
        for i in 1...10 {
            messages.append(Message(
                id: "msg-\(i)",
                conversationId: "test-conversation",
                senderId: "user2",
                text: "Message \(i)",
                timestamp: Date().addingTimeInterval(TimeInterval(i)),
                status: .sent
            ))
        }
        viewModel.messages = messages

        mockMessageRepo.shouldFail = true
        mockMessageRepo.mockError = RepositoryError.networkError(NSError(domain: "test", code: -1))

        // When: Try to load more
        await viewModel.loadMoreMessages()

        // Then: Should set error message
        XCTAssertNotNil(viewModel.errorMessage, "Should set error message on failure")
        XCTAssertFalse(viewModel.isLoadingMore, "isLoadingMore should be false after error")
    }
}
