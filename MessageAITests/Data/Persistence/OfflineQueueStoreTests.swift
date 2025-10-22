//
//  OfflineQueueStoreTests.swift
//  MessageAITests
//
//  Tests for OfflineQueueStore (Story 2.9)
//

import XCTest
@testable import MessageAI

@MainActor
final class OfflineQueueStoreTests: XCTestCase {

    var sut: OfflineQueueStore!

    override func setUp() {
        super.setUp()
        sut = OfflineQueueStore()
        sut.clearQueue()  // Ensure clean state
    }

    override func tearDown() {
        sut.clearQueue()
        sut = nil
        super.tearDown()
    }

    // MARK: - Test Enqueue

    func testEnqueue_AddsMessageToQueue() {
        // Given
        let message = createTestMessage(id: "msg1")

        // When
        sut.enqueue(message)

        // Then
        let queue = sut.loadQueue()
        XCTAssertEqual(queue.count, 1)
        XCTAssertEqual(queue.first?.id, "msg1")
    }

    func testEnqueue_DuplicatePrevention() {
        // Given
        let message = createTestMessage(id: "msg1")

        // When
        sut.enqueue(message)
        sut.enqueue(message)  // Try to enqueue same message again

        // Then
        let queue = sut.loadQueue()
        XCTAssertEqual(queue.count, 1, "Duplicate message should not be added")
    }

    func testEnqueue_MultipleMessages() {
        // Given
        let message1 = createTestMessage(id: "msg1")
        let message2 = createTestMessage(id: "msg2")
        let message3 = createTestMessage(id: "msg3")

        // When
        sut.enqueue(message1)
        sut.enqueue(message2)
        sut.enqueue(message3)

        // Then
        let queue = sut.loadQueue()
        XCTAssertEqual(queue.count, 3)
        XCTAssertEqual(queue[0].id, "msg1")
        XCTAssertEqual(queue[1].id, "msg2")
        XCTAssertEqual(queue[2].id, "msg3")
    }

    // MARK: - Test Dequeue

    func testDequeue_RemovesMessageFromQueue() {
        // Given
        let message1 = createTestMessage(id: "msg1")
        let message2 = createTestMessage(id: "msg2")
        sut.enqueue(message1)
        sut.enqueue(message2)

        // When
        sut.dequeue("msg1")

        // Then
        let queue = sut.loadQueue()
        XCTAssertEqual(queue.count, 1)
        XCTAssertEqual(queue.first?.id, "msg2")
    }

    func testDequeue_NonexistentMessage() {
        // Given
        let message = createTestMessage(id: "msg1")
        sut.enqueue(message)

        // When
        sut.dequeue("nonexistent")

        // Then
        let queue = sut.loadQueue()
        XCTAssertEqual(queue.count, 1, "Queue should remain unchanged")
        XCTAssertEqual(queue.first?.id, "msg1")
    }

    // MARK: - Test LoadQueue

    func testLoadQueue_EmptyQueue() {
        // Given: Clean queue

        // When
        let queue = sut.loadQueue()

        // Then
        XCTAssertTrue(queue.isEmpty)
    }

    func testLoadQueue_ReturnsAllMessages() {
        // Given
        let messages = [
            createTestMessage(id: "msg1"),
            createTestMessage(id: "msg2"),
            createTestMessage(id: "msg3")
        ]
        messages.forEach { sut.enqueue($0) }

        // When
        let queue = sut.loadQueue()

        // Then
        XCTAssertEqual(queue.count, 3)
        XCTAssertEqual(Set(queue.map { $0.id }), Set(["msg1", "msg2", "msg3"]))
    }

    // MARK: - Test ClearQueue

    func testClearQueue_RemovesAllMessages() {
        // Given
        sut.enqueue(createTestMessage(id: "msg1"))
        sut.enqueue(createTestMessage(id: "msg2"))

        // When
        sut.clearQueue()

        // Then
        let queue = sut.loadQueue()
        XCTAssertTrue(queue.isEmpty)
    }

    // MARK: - Test Count

    func testCount_ReturnsCorrectCount() {
        // Given
        XCTAssertEqual(sut.count(), 0)

        // When
        sut.enqueue(createTestMessage(id: "msg1"))
        XCTAssertEqual(sut.count(), 1)

        sut.enqueue(createTestMessage(id: "msg2"))
        XCTAssertEqual(sut.count(), 2)

        sut.dequeue("msg1")
        XCTAssertEqual(sut.count(), 1)

        sut.clearQueue()
        XCTAssertEqual(sut.count(), 0)
    }

    // MARK: - Test Update

    func testUpdate_UpdatesExistingMessage() {
        // Given
        var message = createTestMessage(id: "msg1", text: "Original text")
        sut.enqueue(message)

        // When
        message.text = "Updated text"
        sut.update("msg1", with: message)

        // Then
        let queue = sut.loadQueue()
        XCTAssertEqual(queue.count, 1)
        XCTAssertEqual(queue.first?.text, "Updated text")
    }

    func testUpdate_NonexistentMessage() {
        // Given
        let message = createTestMessage(id: "msg1")

        // When
        sut.update("nonexistent", with: message)

        // Then
        let queue = sut.loadQueue()
        XCTAssertTrue(queue.isEmpty, "No message should be added via update")
    }

    // MARK: - Test Persistence

    func testPersistence_AcrossInstances() {
        // Given
        let message1 = createTestMessage(id: "msg1")
        let message2 = createTestMessage(id: "msg2")
        sut.enqueue(message1)
        sut.enqueue(message2)

        // When
        let newStore = OfflineQueueStore()
        let queue = newStore.loadQueue()

        // Then
        XCTAssertEqual(queue.count, 2)
        XCTAssertEqual(Set(queue.map { $0.id }), Set(["msg1", "msg2"]))

        // Cleanup
        newStore.clearQueue()
    }

    // MARK: - Test Performance

    func testEnqueue_LargeQueue() {
        // Given: Measure performance of enqueuing 100 messages
        let messages = (0..<100).map { createTestMessage(id: "msg\($0)") }

        // When
        measure {
            messages.forEach { sut.enqueue($0) }
        }

        // Then: Should complete in < 500ms (measured in performance test)
        XCTAssertEqual(sut.count(), 100)

        // Cleanup for next test
        sut.clearQueue()
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
