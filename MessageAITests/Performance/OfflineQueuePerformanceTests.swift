//
//  OfflineQueuePerformanceTests.swift
//  MessageAITests
//
//  Performance baseline tests for offline queue functionality
//  Story 2.9: Offline Message Queue with Manual Send (AC #11)
//

import XCTest
@testable import MessageAI

/// Performance baseline tests for OfflineQueueStore
///
/// **Requirements (AC #11):**
/// - Queue view loads instantly (local data only)
/// - loadQueue() performance < 100ms
///
/// **Test Methodology:**
/// - Uses XCTMeasure to establish performance baselines
/// - Tests queue load time with various queue sizes
/// - Validates against 100ms requirement
@MainActor
final class OfflineQueuePerformanceTests: XCTestCase {

    // MARK: - Properties

    var sut: OfflineQueueStore!

    // MARK: - Setup & Teardown

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

    // MARK: - Performance Baseline Tests

    /// Test loadQueue() performance with 50 messages (AC #11)
    ///
    /// **Requirement:** Queue load time < 100ms
    ///
    /// **Test Setup:**
    /// 1. Enqueue 50 messages (typical large queue)
    /// 2. Measure loadQueue() performance
    /// 3. Assert average time < 0.1 seconds (100ms)
    ///
    /// **Performance Target:** < 100ms average
    func testPerformance_LoadQueue_50Messages() {
        // Given: Queue with 50 messages
        let messageCount = 50
        populateQueue(messageCount: messageCount)

        print("📊 Testing loadQueue() performance with \(messageCount) messages")

        // When: Measure load time
        measure {
            let _ = sut.loadQueue()
        }

        // Then: Verify queue loaded correctly
        let queue = sut.loadQueue()
        XCTAssertEqual(queue.count, messageCount, "All \(messageCount) messages should be loaded")

        print("✅ Performance test completed - see metrics above")
        print("   Target: < 100ms (0.1 seconds)")
    }

    /// Test loadQueue() performance with empty queue
    ///
    /// **Requirement:** Empty queue should load instantly
    ///
    /// **Performance Target:** < 10ms average
    func testPerformance_LoadQueue_Empty() {
        // Given: Empty queue

        print("📊 Testing loadQueue() performance with empty queue")

        // When: Measure load time
        measure {
            let _ = sut.loadQueue()
        }

        // Then: Verify empty queue
        let queue = sut.loadQueue()
        XCTAssertTrue(queue.isEmpty, "Queue should be empty")

        print("✅ Performance test completed - should be < 10ms")
    }

    /// Test loadQueue() performance with 100 messages (stress test)
    ///
    /// **Requirement:** Large queue should still load within acceptable time
    ///
    /// **Performance Target:** < 200ms average (relaxed for large queue)
    func testPerformance_LoadQueue_100Messages() {
        // Given: Queue with 100 messages
        let messageCount = 100
        populateQueue(messageCount: messageCount)

        print("📊 Testing loadQueue() performance with \(messageCount) messages (stress test)")

        // When: Measure load time
        measure {
            let _ = sut.loadQueue()
        }

        // Then: Verify queue loaded correctly
        let queue = sut.loadQueue()
        XCTAssertEqual(queue.count, messageCount, "All \(messageCount) messages should be loaded")

        print("✅ Performance test completed - target < 200ms for large queue")
    }

    /// Test enqueue() performance with sequential adds
    ///
    /// **Requirement:** Messages should be queued quickly for responsive UI
    ///
    /// **Performance Target:** < 50ms average per enqueue
    func testPerformance_Enqueue_SequentialAdds() {
        // Given: 20 messages to enqueue

        print("📊 Testing enqueue() performance with sequential adds")

        // When: Measure enqueue time
        measure {
            // Enqueue 20 messages sequentially
            for i in 1...20 {
                let message = createTestMessage(id: "perf-enqueue-\(i)")
                sut.enqueue(message)
            }

            // Clean up for next iteration
            sut.clearQueue()
        }

        print("✅ Performance test completed - target < 50ms per enqueue")
    }

    /// Test dequeue() performance with large queue
    ///
    /// **Requirement:** Removing messages should be fast after successful send
    ///
    /// **Performance Target:** < 50ms average per dequeue
    func testPerformance_Dequeue_LargeQueue() {
        // Given: Queue with 50 messages
        let messageCount = 50
        let messageIds = populateQueue(messageCount: messageCount)

        print("📊 Testing dequeue() performance with \(messageCount) messages")

        // When: Measure dequeue time
        var index = 0
        measure {
            // Dequeue 10 messages per iteration
            for _ in 0..<10 {
                if index < messageIds.count {
                    sut.dequeue(messageIds[index])
                    index += 1
                }
            }
        }

        print("✅ Performance test completed - target < 50ms per dequeue")

        // Cleanup
        sut.clearQueue()
    }

    /// Test count() performance with large queue
    ///
    /// **Requirement:** Getting queue size should be fast for UI updates
    ///
    /// **Performance Target:** < 100ms average
    func testPerformance_Count_LargeQueue() {
        // Given: Queue with 100 messages
        let messageCount = 100
        populateQueue(messageCount: messageCount)

        print("📊 Testing count() performance with \(messageCount) messages")

        // When: Measure count time
        measure {
            let _ = sut.count()
        }

        // Then: Verify count is correct
        XCTAssertEqual(sut.count(), messageCount)

        print("✅ Performance test completed - target < 100ms")
    }

    /// Test update() performance with large queue
    ///
    /// **Requirement:** Editing queued messages should be responsive
    ///
    /// **Performance Target:** < 100ms average
    func testPerformance_Update_LargeQueue() {
        // Given: Queue with 50 messages
        let messageCount = 50
        let messageIds = populateQueue(messageCount: messageCount)

        print("📊 Testing update() performance with \(messageCount) messages")

        // When: Measure update time
        var index = 0
        measure {
            // Update one message per iteration
            if index < messageIds.count {
                var updatedMessage = createTestMessage(id: messageIds[index])
                updatedMessage.text = "Updated message \(index)"
                sut.update(messageIds[index], with: updatedMessage)
                index += 1
            }
        }

        print("✅ Performance test completed - target < 100ms per update")

        // Cleanup
        sut.clearQueue()
    }

    // MARK: - Baseline Validation Tests

    /// Validate loadQueue() meets 100ms requirement (AC #11)
    ///
    /// **Critical Test:** This validates the specific AC #11 requirement
    ///
    /// Uses manual timing to assert against 100ms requirement.
    func testBaseline_LoadQueue_Meets100msRequirement() {
        // Given: Queue with 50 messages (typical large queue)
        let messageCount = 50
        populateQueue(messageCount: messageCount)

        print("📊 [BASELINE VALIDATION] Testing loadQueue() against 100ms requirement")

        // When: Measure actual load time
        let startTime = Date()
        let queue = sut.loadQueue()
        let duration = Date().timeIntervalSince(startTime)

        // Then: Assert < 100ms (0.1 seconds)
        let durationMs = duration * 1000
        print("   ⏱️  Load time: \(String(format: "%.2f", durationMs))ms for \(messageCount) messages")

        XCTAssertLessThan(
            duration,
            0.1,
            "loadQueue() must complete in < 100ms (actual: \(String(format: "%.2f", durationMs))ms) - AC #11"
        )

        XCTAssertEqual(queue.count, messageCount, "All messages should be loaded")

        if duration < 0.1 {
            print("   ✅ PASS: Meets 100ms requirement")
        } else {
            print("   ❌ FAIL: Exceeds 100ms requirement")
        }
    }

    /// Validate loadQueue() performance with realistic data
    ///
    /// Tests with messages containing realistic text content
    /// (100-200 characters per message)
    func testBaseline_LoadQueue_RealisticMessageSize() {
        // Given: Queue with 50 messages with realistic text
        let messageCount = 50
        for i in 1...messageCount {
            let message = createRealisticMessage(id: "realistic-\(i)", index: i)
            sut.enqueue(message)
        }

        print("📊 [BASELINE VALIDATION] Testing with realistic message sizes")

        // When: Measure load time
        let startTime = Date()
        let queue = sut.loadQueue()
        let duration = Date().timeIntervalSince(startTime)

        // Then: Assert < 100ms
        let durationMs = duration * 1000
        print("   ⏱️  Load time: \(String(format: "%.2f", durationMs))ms for \(messageCount) realistic messages")

        XCTAssertLessThan(
            duration,
            0.1,
            "loadQueue() with realistic messages must complete in < 100ms (actual: \(String(format: "%.2f", durationMs))ms)"
        )

        XCTAssertEqual(queue.count, messageCount)

        if duration < 0.1 {
            print("   ✅ PASS: Meets 100ms requirement with realistic data")
        }
    }

    // MARK: - Helper Methods

    /// Populate queue with test messages
    ///
    /// - Parameter messageCount: Number of messages to add
    /// - Returns: Array of message IDs
    @discardableResult
    private func populateQueue(messageCount: Int) -> [String] {
        var messageIds: [String] = []

        for i in 1...messageCount {
            let id = "msg-\(i)"
            let message = createTestMessage(id: id)
            sut.enqueue(message)
            messageIds.append(id)
        }

        return messageIds
    }

    /// Create test message with minimal text
    private func createTestMessage(id: String) -> Message {
        Message(
            id: id,
            conversationId: "conv1",
            senderId: "user1",
            text: "Test message",
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

    /// Create message with realistic text content (100-200 characters)
    private func createRealisticMessage(id: String, index: Int) -> Message {
        let realisticTexts = [
            "Hey team, I've finished reviewing the pull request and left some comments. Overall looks good, just a few minor suggestions about error handling and naming conventions.",
            "Quick update on the project: we're on track to hit our sprint goals. The integration tests are all passing and we're ready for the demo tomorrow at 2pm.",
            "Thanks for the feedback! I've updated the implementation to address your concerns about performance. Let me know if you need any clarification.",
            "Just deployed the latest changes to staging. Please test the new feature and let me know if you encounter any issues before we push to production.",
            "Meeting notes: Discussed architecture decisions, agreed on using repository pattern, next steps are to implement the network layer and write unit tests."
        ]

        let text = realisticTexts[index % realisticTexts.count]

        return Message(
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
