import XCTest
@testable import MessageAI

final class MessageTests: XCTestCase {
    
    func testMessageInitialization() {
        // When: Create message with minimal parameters
        let message = Message(
            conversationId: "conv-1",
            senderId: "user-1",
            text: "Hello, world!"
        )
        
        // Then: Default values should be set correctly
        XCTAssertEqual(message.conversationId, "conv-1")
        XCTAssertEqual(message.senderId, "user-1")
        XCTAssertEqual(message.text, "Hello, world!")
        XCTAssertEqual(message.status, .sending)
        XCTAssertFalse(message.isEdited)
        XCTAssertFalse(message.isDeleted)
        XCTAssertTrue(message.attachments.isEmpty)
        XCTAssertEqual(message.editCount, 0)
        XCTAssertNil(message.editHistory)
    }
    
    func testMessageEquality() {
        // Given: Two messages with same ID and properties (using same timestamps)
        let timestamp = Date()
        let message1 = Message(
            id: "msg-1",
            conversationId: "conv-1",
            senderId: "user-1",
            text: "Test",
            timestamp: timestamp,
            statusUpdatedAt: timestamp
        )
        
        let message2 = Message(
            id: "msg-1",
            conversationId: "conv-1",
            senderId: "user-1",
            text: "Test",
            timestamp: timestamp,
            statusUpdatedAt: timestamp
        )
        
        // Then: They should be equal
        XCTAssertEqual(message1, message2)
    }
    
    func testMessageCodable() throws {
        // Given: A message entity
        let message = Message(
            conversationId: "conv-1",
            senderId: "user-1",
            text: "Test message"
        )
        
        // When: Encode and decode
        let encoder = JSONEncoder()
        let data = try encoder.encode(message)
        
        let decoder = JSONDecoder()
        let decodedMessage = try decoder.decode(Message.self, from: data)
        
        // Then: Properties should match
        XCTAssertEqual(message.id, decodedMessage.id)
        XCTAssertEqual(message.text, decodedMessage.text)
        XCTAssertEqual(message.conversationId, decodedMessage.conversationId)
        XCTAssertEqual(message.senderId, decodedMessage.senderId)
    }
    
    func testMessageStatusTransition() {
        // Given: Various message statuses
        // Then: Valid transitions should be allowed
        XCTAssertTrue(MessageStatus.sending.canTransitionTo(.sent))
        XCTAssertTrue(MessageStatus.sent.canTransitionTo(.delivered))
        XCTAssertTrue(MessageStatus.delivered.canTransitionTo(.read))
        
        // And: Invalid backwards transitions should be rejected
        XCTAssertFalse(MessageStatus.read.canTransitionTo(.sending))
        XCTAssertFalse(MessageStatus.delivered.canTransitionTo(.sent))
        XCTAssertFalse(MessageStatus.sent.canTransitionTo(.sending))
    }
    
    func testMessageStatusSortOrder() {
        // Given: Message statuses
        // Then: Sort order should be correct
        XCTAssertEqual(MessageStatus.sending.sortOrder, 0)
        XCTAssertEqual(MessageStatus.failed.sortOrder, 0)
        XCTAssertEqual(MessageStatus.sent.sortOrder, 1)
        XCTAssertEqual(MessageStatus.delivered.sortOrder, 2)
        XCTAssertEqual(MessageStatus.read.sortOrder, 3)
    }
}

