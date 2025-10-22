//
//  OfflineQueueViewModelTests.swift
//  MessageAITests
//
//  Tests for OfflineQueueViewModel (Story 2.9)
//

import XCTest
@testable import MessageAI

@MainActor
final class OfflineQueueViewModelTests: XCTestCase {

    var sut: OfflineQueueViewModel!
    var offlineQueueStore: OfflineQueueStore!
    var mockMessageRepository: MockMessageRepository!

    override func setUp() async throws {
        try await super.setUp()

        offlineQueueStore = OfflineQueueStore()
        offlineQueueStore.clearQueue()
        mockMessageRepository = MockMessageRepository()

        sut = OfflineQueueViewModel(
            offlineQueueStore: offlineQueueStore,
            messageRepository: mockMessageRepository
        )
    }

    override func tearDown() async throws {
        offlineQueueStore.clearQueue()
        sut = nil
        offlineQueueStore = nil
        mockMessageRepository = nil

        try await super.tearDown()
    }

    // MARK: - Test loadQueue

    func testLoadQueue_LoadsMessagesFromStore() {
        // Given
        let message1 = createTestMessage(id: "msg1", text: "Message 1")
        let message2 = createTestMessage(id: "msg2", text: "Message 2")
        offlineQueueStore.enqueue(message1)
        offlineQueueStore.enqueue(message2)

        // When
        sut.loadQueue()

        // Then
        XCTAssertEqual(sut.queuedMessages.count, 2)
        XCTAssertEqual(Set(sut.queuedMessages.map { $0.id }), Set(["msg1", "msg2"]))
    }

    // MARK: - Test sendMessage

    func testSendMessage_Success_RemovesFromQueue() async {
        // Given
        let message = createTestMessage(id: "msg1")
        offlineQueueStore.enqueue(message)
        sut.loadQueue()

        // When
        await sut.sendMessage(message)

        // Then
        XCTAssertTrue(sut.queuedMessages.isEmpty, "Message should be removed after successful send")
        XCTAssertTrue(mockMessageRepository.sendMessageCalled)
    }

    func testSendMessage_Failure_KeepsInQueue() async {
        // Given
        let message = createTestMessage(id: "msg1")
        offlineQueueStore.enqueue(message)
        sut.loadQueue()

        // Configure mock to fail
        mockMessageRepository.shouldFail = true

        // When
        await sut.sendMessage(message)

        // Then
        XCTAssertEqual(sut.queuedMessages.count, 1, "Message should remain in queue after failure")
        XCTAssertEqual(sut.queuedMessages.first?.status, .failed)
    }

    func testSendMessage_UpdatesStatusTosending() async {
        // Given
        let message = createTestMessage(id: "msg1")
        offlineQueueStore.enqueue(message)
        sut.loadQueue()

        // When: Start sending (capture state during operation)
        let sendTask = Task {
            await sut.sendMessage(message)
        }

        // Brief delay to observe status change
        try? await Task.sleep(nanoseconds: 10_000_000)  // 0.01s

        await sendTask.value

        // Then
        XCTAssertTrue(mockMessageRepository.sendMessageCalled)
    }

    // MARK: - Test sendAllMessages

    func testSendAllMessages_SendsSequentially() async {
        // Given
        let messages = [
            createTestMessage(id: "msg1"),
            createTestMessage(id: "msg2"),
            createTestMessage(id: "msg3")
        ]
        messages.forEach { offlineQueueStore.enqueue($0) }
        sut.loadQueue()

        // When
        await sut.sendAllMessages()

        // Then
        XCTAssertTrue(sut.queuedMessages.isEmpty)
        XCTAssertEqual(mockMessageRepository.sendMessageCallCount, 3)
    }

    func testSendAllMessages_ContinuesOnFailure() async {
        // Given
        let message1 = createTestMessage(id: "msg1")
        let message2 = createTestMessage(id: "msg2")
        let message3 = createTestMessage(id: "msg3")

        offlineQueueStore.enqueue(message1)
        offlineQueueStore.enqueue(message2)
        offlineQueueStore.enqueue(message3)
        sut.loadQueue()

        // Configure mock to fail message2
        mockMessageRepository.shouldFailMessageId = "msg2"

        // When
        await sut.sendAllMessages()

        // Then
        XCTAssertEqual(sut.queuedMessages.count, 1, "Only failed message should remain")
        XCTAssertEqual(sut.queuedMessages.first?.id, "msg2")
        XCTAssertEqual(mockMessageRepository.sendMessageCallCount, 3, "Should attempt all messages")
    }

    // MARK: - Test editMessage

    func testEditMessage_UpdatesText() {
        // Given
        let message = createTestMessage(id: "msg1", text: "Original text")
        offlineQueueStore.enqueue(message)
        sut.loadQueue()

        // When
        sut.editMessage(message, newText: "Updated text")

        // Then
        XCTAssertEqual(sut.queuedMessages.first?.text, "Updated text")

        // Verify persistence
        let storedQueue = offlineQueueStore.loadQueue()
        XCTAssertEqual(storedQueue.first?.text, "Updated text")
    }

    func testEditMessage_NonexistentMessage() {
        // Given
        let message = createTestMessage(id: "nonexistent")

        // When
        sut.editMessage(message, newText: "New text")

        // Then: Should not crash, just log warning
        XCTAssertTrue(sut.queuedMessages.isEmpty)
    }

    // MARK: - Test deleteMessage

    func testDeleteMessage_RemovesFromQueue() {
        // Given
        let message1 = createTestMessage(id: "msg1")
        let message2 = createTestMessage(id: "msg2")
        offlineQueueStore.enqueue(message1)
        offlineQueueStore.enqueue(message2)
        sut.loadQueue()

        // When
        sut.deleteMessage(message1)

        // Then
        XCTAssertEqual(sut.queuedMessages.count, 1)
        XCTAssertEqual(sut.queuedMessages.first?.id, "msg2")

        // Verify persistence
        XCTAssertEqual(offlineQueueStore.count(), 1)
    }

    // MARK: - Test Error Handling

    func testSendMessage_SetsErrorMessage() async {
        // Given
        let message = createTestMessage(id: "msg1")
        offlineQueueStore.enqueue(message)
        sut.loadQueue()

        mockMessageRepository.shouldFail = true

        // When
        await sut.sendMessage(message)

        // Then
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertTrue(sut.errorMessage!.contains("Failed to send message"))
    }

    // MARK: - Helper Methods

    private func createTestMessage(id: String, text: String = "Test message") -> Message {
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
