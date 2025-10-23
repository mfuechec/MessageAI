//
//  ChatViewModelOfflineQueueTests.swift
//  MessageAITests
//
//  Tests for ChatViewModel offline queue functionality (Story 2.9)
//

import XCTest
import Combine
@testable import MessageAI

@MainActor
final class ChatViewModelOfflineQueueTests: XCTestCase {

    var sut: ChatViewModel!
    var mockMessageRepository: MockMessageRepository!
    var mockConversationRepository: MockConversationRepository!
    var mockUserRepository: MockUserRepository!
    var mockStorageRepository: MockStorageRepository!
    var mockNetworkMonitor: MockNetworkMonitor!
    var offlineQueueStore: OfflineQueueStore!
    var cancellables: Set<AnyCancellable>!

    override func setUp() async throws {
        try await super.setUp()

        mockMessageRepository = MockMessageRepository()
        mockConversationRepository = MockConversationRepository()
        mockUserRepository = MockUserRepository()
        mockStorageRepository = MockStorageRepository()
        mockNetworkMonitor = MockNetworkMonitor()
        offlineQueueStore = OfflineQueueStore()
        offlineQueueStore.clearQueue()  // Clean state
        cancellables = Set<AnyCancellable>()

        sut = ChatViewModel(
            conversationId: "conv1",
            currentUserId: "user1",
            messageRepository: mockMessageRepository,
            conversationRepository: mockConversationRepository,
            userRepository: mockUserRepository,
            storageRepository: mockStorageRepository,
            networkMonitor: mockNetworkMonitor,
            offlineQueueStore: offlineQueueStore
        )
    }

    override func tearDown() async throws {
        offlineQueueStore.clearQueue()
        cancellables = nil
        sut = nil
        mockMessageRepository = nil
        mockConversationRepository = nil
        mockUserRepository = nil
        mockStorageRepository = nil
        mockNetworkMonitor = nil
        offlineQueueStore = nil

        try await super.tearDown()
    }

    // MARK: - Test sendMessage When Offline

    func testSendMessage_Offline_QueuesMessage() async {
        // Given
        mockNetworkMonitor.isConnected = false
        sut.messageText = "Hello offline world"

        // When
        await sut.sendMessage()

        // Then
        XCTAssertEqual(sut.queuedMessages.count, 1, "Message should be queued")
        XCTAssertEqual(sut.queuedMessages.first?.text, "Hello offline world")
        XCTAssertEqual(sut.queuedMessages.first?.status, .queued)
        XCTAssertFalse(mockMessageRepository.sendMessageCalled, "Should not send to Firebase when offline")
    }

    func testSendMessage_Online_SendsImmediately() async {
        // Given
        mockNetworkMonitor.isConnected = true
        sut.messageText = "Hello online world"

        // When
        await sut.sendMessage()

        // Then
        XCTAssertEqual(sut.queuedMessages.count, 0, "Message should not be queued when online")
        XCTAssertTrue(mockMessageRepository.sendMessageCalled, "Should send to Firebase when online")
    }

    // MARK: - Test sendAllQueuedMessages

    func testSendAllQueuedMessages_Sequential() async {
        // Given: Queue 3 messages
        mockNetworkMonitor.isConnected = false
        sut.messageText = "Message 1"
        await sut.sendMessage()
        sut.messageText = "Message 2"
        await sut.sendMessage()
        sut.messageText = "Message 3"
        await sut.sendMessage()

        XCTAssertEqual(sut.queuedMessages.count, 3)

        // When: Go online and send all
        mockNetworkMonitor.isConnected = true
        mockMessageRepository.sendMessageCalled = false  // Reset
        await sut.sendAllQueuedMessages()

        // Then
        XCTAssertEqual(sut.queuedMessages.count, 0, "All messages should be sent and removed from queue")
        XCTAssertEqual(mockMessageRepository.sendMessageCallCount, 3, "Should send 3 messages")
    }

    func testSendAllQueuedMessages_FailureHandling() async {
        // Given: Queue 2 messages, configure mock to fail second one
        mockNetworkMonitor.isConnected = false
        sut.messageText = "Message 1"
        await sut.sendMessage()
        sut.messageText = "Message 2"
        await sut.sendMessage()

        let message2Id = sut.queuedMessages[1].id

        // Configure mock to fail the second message
        mockMessageRepository.shouldFailMessageId = message2Id

        // When: Go online and send all
        mockNetworkMonitor.isConnected = true
        await sut.sendAllQueuedMessages()

        // Then
        XCTAssertEqual(sut.queuedMessages.count, 1, "Failed message should remain in queue")
        XCTAssertEqual(sut.queuedMessages.first?.id, message2Id)
        XCTAssertEqual(sut.queuedMessages.first?.status, .failed)
    }

    func testSendAllQueuedMessages_Success() async {
        // Given
        mockNetworkMonitor.isConnected = false
        sut.messageText = "Queued message"
        await sut.sendMessage()

        // When
        mockNetworkMonitor.isConnected = true
        await sut.sendAllQueuedMessages()

        // Then
        XCTAssertTrue(sut.queuedMessages.isEmpty, "Queue should be empty after successful send")
    }

    // MARK: - Test sendSingleQueuedMessage

    func testSendSingleQueuedMessage_Success() async {
        // Given: Queue a message
        mockNetworkMonitor.isConnected = false
        sut.messageText = "Test message"
        await sut.sendMessage()
        let queuedMessage = sut.queuedMessages.first!

        // When: Go online and send single message
        mockNetworkMonitor.isConnected = true
        await sut.sendSingleQueuedMessage(queuedMessage)

        // Then
        XCTAssertTrue(sut.queuedMessages.isEmpty)
        XCTAssertTrue(mockMessageRepository.sendMessageCalled)
    }

    func testSendSingleQueuedMessage_Failure() async {
        // Given
        mockNetworkMonitor.isConnected = false
        sut.messageText = "Test message"
        await sut.sendMessage()
        let queuedMessage = sut.queuedMessages.first!

        // Configure mock to fail
        mockMessageRepository.shouldFailMessageId = queuedMessage.id

        // When
        mockNetworkMonitor.isConnected = true
        await sut.sendSingleQueuedMessage(queuedMessage)

        // Then
        XCTAssertEqual(sut.queuedMessages.count, 1, "Message should remain in queue")
        XCTAssertEqual(sut.queuedMessages.first?.status, .failed)
    }

    // MARK: - Test deleteQueuedMessage

    func testDeleteQueuedMessage_RemovesFromQueue() {
        // Given: Manually add to queue (simulating persistence)
        let message = createTestMessage(id: "msg1", text: "Test")
        offlineQueueStore.enqueue(message)
        sut.queuedMessages.append(message)

        // When
        sut.deleteQueuedMessage("msg1")

        // Then
        XCTAssertTrue(sut.queuedMessages.isEmpty)
        XCTAssertEqual(offlineQueueStore.count(), 0)
    }

    // MARK: - Test Connectivity Observation

    func testConnectivityRestore_ShowsToast() async {
        // Given: Queue a message while offline
        mockNetworkMonitor.isConnected = false
        sut.messageText = "Test"
        await sut.sendMessage()

        XCTAssertFalse(sut.showConnectivityToast)

        // When: Simulate going online
        mockNetworkMonitor.isConnected = true
        mockNetworkMonitor.simulateConnectivityChange()

        // Wait for async update
        try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1s

        // Then
        XCTAssertTrue(sut.showConnectivityToast, "Toast should appear when connectivity restored with queued messages")
    }

    // MARK: - Network State Transition Tests (Story 2.9 - Race Condition Fix)

    func testOfflineToOnlineTransition_WithQueuedMessages_ShowsToast() async {
        // Given: User is offline with queued messages
        mockNetworkMonitor.isConnected = false
        sut.messageText = "Test message"
        await sut.sendMessage()

        XCTAssertEqual(sut.queuedMessages.count, 1)
        XCTAssertFalse(sut.showConnectivityToast)

        // When: Connection restored
        mockNetworkMonitor.isConnected = true
        mockNetworkMonitor.simulateConnectivityChange()

        // Wait for async update
        try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1s

        // Then: Toast shown
        XCTAssertTrue(sut.showConnectivityToast, "Toast should show when connectivity restored with queued messages")
        XCTAssertFalse(sut.isOffline, "Should be online")
    }

    func testOfflineToOnlineTransition_WithoutQueuedMessages_NoToast() async {
        // Given: User is offline with NO queued messages
        mockNetworkMonitor.isConnected = false
        sut.isOffline = true

        XCTAssertEqual(sut.queuedMessages.count, 0)

        // When: Connection restored
        mockNetworkMonitor.isConnected = true
        mockNetworkMonitor.simulateConnectivityChange()

        // Wait for async update
        try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1s

        // Then: Toast NOT shown
        XCTAssertFalse(sut.showConnectivityToast, "Toast should NOT show without queued messages")
        XCTAssertFalse(sut.isOffline, "Should be online")
    }

    func testOnlineToOfflineTransition_HidesToast() async {
        // Given: User is online with toast showing
        mockNetworkMonitor.isConnected = true
        sut.showConnectivityToast = true

        // When: Connection lost
        mockNetworkMonitor.isConnected = false
        mockNetworkMonitor.simulateConnectivityChange()

        // Wait for async update
        try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1s

        // Then: Toast hidden
        XCTAssertFalse(sut.showConnectivityToast, "Toast should hide when going offline")
        XCTAssertTrue(sut.isOffline, "Should be offline")
    }

    func testRapidNetworkToggles_HandlesGracefully() async {
        // Given: Start online
        mockNetworkMonitor.isConnected = true

        // Queue a message while offline
        mockNetworkMonitor.isConnected = false
        mockNetworkMonitor.simulateConnectivityChange()
        try? await Task.sleep(nanoseconds: 50_000_000)  // 0.05s

        sut.messageText = "Test"
        await sut.sendMessage()

        // When: Rapid toggles - offline→online→offline→online
        mockNetworkMonitor.isConnected = true
        mockNetworkMonitor.simulateConnectivityChange()
        try? await Task.sleep(nanoseconds: 50_000_000)

        mockNetworkMonitor.isConnected = false
        mockNetworkMonitor.simulateConnectivityChange()
        try? await Task.sleep(nanoseconds: 50_000_000)

        mockNetworkMonitor.isConnected = true
        mockNetworkMonitor.simulateConnectivityChange()
        try? await Task.sleep(nanoseconds: 100_000_000)  // Final wait

        // Then: Should handle gracefully without crashes or state corruption
        XCTAssertFalse(sut.isOffline, "Final state should be online")
        XCTAssertTrue(sut.showConnectivityToast, "Toast should show on final offline→online transition")
    }

    func testNetworkStateChange_UpdatesIsOfflineProperty() async {
        // Given: Start online
        mockNetworkMonitor.isConnected = true
        XCTAssertFalse(sut.isOffline)

        // When: Go offline
        mockNetworkMonitor.isConnected = false
        mockNetworkMonitor.simulateConnectivityChange()
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Then: isOffline updated
        XCTAssertTrue(sut.isOffline, "isOffline should be true when offline")

        // When: Go online
        mockNetworkMonitor.isConnected = true
        mockNetworkMonitor.simulateConnectivityChange()
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Then: isOffline updated
        XCTAssertFalse(sut.isOffline, "isOffline should be false when online")
    }

    func testMultipleOfflineOnlineTransitions_ConsistentBehavior() async {
        // Test multiple cycles to ensure no state corruption from race conditions

        // Cycle 1: Offline → queue message → online
        mockNetworkMonitor.isConnected = false
        mockNetworkMonitor.simulateConnectivityChange()
        try? await Task.sleep(nanoseconds: 50_000_000)

        sut.messageText = "Message 1"
        await sut.sendMessage()

        mockNetworkMonitor.isConnected = true
        mockNetworkMonitor.simulateConnectivityChange()
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertTrue(sut.showConnectivityToast, "Toast should show after cycle 1")

        // Cycle 2: Offline → queue another message → online
        mockNetworkMonitor.isConnected = false
        mockNetworkMonitor.simulateConnectivityChange()
        try? await Task.sleep(nanoseconds: 50_000_000)

        sut.messageText = "Message 2"
        await sut.sendMessage()

        mockNetworkMonitor.isConnected = true
        mockNetworkMonitor.simulateConnectivityChange()
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertTrue(sut.showConnectivityToast, "Toast should show after cycle 2")
        XCTAssertFalse(sut.isOffline, "Final state should be online")
    }

    // MARK: - Helper Methods

    private func createTestMessage(id: String, text: String) -> Message {
        Message(
            id: id,
            conversationId: "conv1",
            senderId: "user1",
            text: text,
            timestamp: Date(),
            status: .queued,
            statusUpdatedAt: Date(),
            attachments: [],
            editHistory: nil,
            editCount: 0,
            isEdited: false,
            isDeleted: false,
            deletedAt: nil,
            deletedBy: nil,
            readBy: [],
            readCount: 0,
            isPriority: false,
            priorityReason: nil,
            schemaVersion: 1
        )
    }
}
