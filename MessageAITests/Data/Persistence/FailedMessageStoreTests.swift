//
//  FailedMessageStoreTests.swift
//  MessageAITests
//
//  Unit tests for FailedMessageStore (local persistence for failed messages)
//

import XCTest
@testable import MessageAI

@MainActor
final class FailedMessageStoreTests: XCTestCase {
    
    var sut: FailedMessageStore!
    
    override func setUp() async throws {
        sut = FailedMessageStore()
        sut.clearAll() // Start with clean slate
    }
    
    override func tearDown() async throws {
        sut.clearAll() // Clean up after tests
        sut = nil
    }
    
    // MARK: - Test Save
    
    func testSaveFailedMessage() {
        // Given: A failed message
        let message = Message(
            id: "msg-1",
            conversationId: "conv-1",
            senderId: "user-1",
            text: "Test message",
            status: .failed
        )
        
        // When: Save to store
        sut.save(message)
        
        // Then: Message is stored
        let loaded = sut.loadAll()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.id, "msg-1")
        XCTAssertEqual(loaded.first?.text, "Test message")
        XCTAssertEqual(loaded.first?.status, .failed)
    }
    
    func testSaveMultipleFailedMessages() {
        // Given: Multiple failed messages
        let message1 = Message(id: "msg-1", conversationId: "conv-1", senderId: "user-1", text: "Message 1", status: .failed)
        let message2 = Message(id: "msg-2", conversationId: "conv-1", senderId: "user-1", text: "Message 2", status: .failed)
        let message3 = Message(id: "msg-3", conversationId: "conv-2", senderId: "user-1", text: "Message 3", status: .failed)
        
        // When: Save all messages
        sut.save(message1)
        sut.save(message2)
        sut.save(message3)
        
        // Then: All messages are stored
        let loaded = sut.loadAll()
        XCTAssertEqual(loaded.count, 3)
        XCTAssertTrue(loaded.contains { $0.id == "msg-1" })
        XCTAssertTrue(loaded.contains { $0.id == "msg-2" })
        XCTAssertTrue(loaded.contains { $0.id == "msg-3" })
    }
    
    func testUpdateExistingFailedMessage() {
        // Given: A failed message that's already saved
        let message = Message(id: "msg-1", conversationId: "conv-1", senderId: "user-1", text: "Original text", status: .failed)
        sut.save(message)
        
        // When: Save same message ID with updated text
        var updatedMessage = message
        updatedMessage.text = "Updated text"
        sut.save(updatedMessage)
        
        // Then: Only 1 message exists with updated text
        let loaded = sut.loadAll()
        XCTAssertEqual(loaded.count, 1, "Should only have 1 message (updated, not duplicated)")
        XCTAssertEqual(loaded.first?.id, "msg-1")
        XCTAssertEqual(loaded.first?.text, "Updated text")
    }
    
    // MARK: - Test Load
    
    func testLoadFailedMessages() {
        // Given: 3 saved messages
        sut.save(Message(id: "msg-1", conversationId: "conv-1", senderId: "user-1", text: "Test 1", status: .failed))
        sut.save(Message(id: "msg-2", conversationId: "conv-1", senderId: "user-1", text: "Test 2", status: .failed))
        sut.save(Message(id: "msg-3", conversationId: "conv-1", senderId: "user-1", text: "Test 3", status: .failed))
        
        // When: Load all messages
        let loaded = sut.loadAll()
        
        // Then: All 3 messages are returned
        XCTAssertEqual(loaded.count, 3)
        XCTAssertEqual(Set(loaded.map { $0.id }), Set(["msg-1", "msg-2", "msg-3"]))
    }
    
    func testLoadEmptyStore() {
        // Given: Empty store (no messages saved)
        
        // When: Load all messages
        let loaded = sut.loadAll()
        
        // Then: Returns empty array
        XCTAssertEqual(loaded.count, 0)
    }
    
    // MARK: - Test Remove
    
    func testRemoveFailedMessage() {
        // Given: 2 saved messages
        sut.save(Message(id: "msg-1", conversationId: "conv-1", senderId: "user-1", text: "Test 1", status: .failed))
        sut.save(Message(id: "msg-2", conversationId: "conv-1", senderId: "user-1", text: "Test 2", status: .failed))
        
        // When: Remove one message by ID
        sut.remove("msg-1")
        
        // Then: Only 1 message remains
        let loaded = sut.loadAll()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.id, "msg-2")
    }
    
    func testRemoveNonExistentMessage() {
        // Given: 1 saved message
        sut.save(Message(id: "msg-1", conversationId: "conv-1", senderId: "user-1", text: "Test", status: .failed))
        
        // When: Remove message that doesn't exist
        sut.remove("msg-999")
        
        // Then: Original message still exists
        let loaded = sut.loadAll()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.id, "msg-1")
    }
    
    // MARK: - Test Clear
    
    func testClearAll() {
        // Given: 5 saved messages
        for i in 1...5 {
            sut.save(Message(id: "msg-\(i)", conversationId: "conv-1", senderId: "user-1", text: "Test \(i)", status: .failed))
        }
        
        // When: Clear all messages
        sut.clearAll()
        
        // Then: Store is empty
        let loaded = sut.loadAll()
        XCTAssertEqual(loaded.count, 0)
    }
    
    // MARK: - Test Persistence

    func testPersistenceAcrossAppRestarts() async throws {
        // Given: A failed message saved to UserDefaults
        let message = Message(id: "msg-1", conversationId: "conv-1", senderId: "user-1", text: "Persistent message", status: .failed)
        sut.save(message)

        // When: Create new FailedMessageStore instance (simulates app restart)
        let newStore = FailedMessageStore()

        // Then: Message still exists
        let loaded = newStore.loadAll()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.id, "msg-1")
        XCTAssertEqual(loaded.first?.text, "Persistent message")
    }
}

