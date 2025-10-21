import XCTest
import Combine
@testable import MessageAI

/// Integration tests for FirebaseMessageRepository using Firebase Emulator
@MainActor
final class FirebaseMessageRepositoryTests: XCTestCase {
    
    var sut: FirebaseMessageRepository!
    var firebaseService: FirebaseService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() async throws {
        try await super.setUp()
        cancellables = Set<AnyCancellable>()
        
        // Configure Firebase with emulator
        firebaseService = FirebaseService()
        firebaseService.useEmulator()
        firebaseService.configure()
        
        sut = FirebaseMessageRepository(firebaseService: firebaseService)
    }
    
    override func tearDown() async throws {
        cancellables = nil
        sut = nil
        try await super.tearDown()
    }
    
    // MARK: - Send Message Tests
    
    func testSendMessage_Success() async throws {
        // Given
        let message = Message(
            id: UUID().uuidString,
            conversationId: "test-conversation",
            senderId: "user-1",
            text: "Test message",
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
            readBy: [],
            readCount: 0,
            isPriority: false,
            priorityReason: nil
        )
        
        // When
        try await sut.sendMessage(message)
        
        // Then: Verify message can be retrieved
        let messages = try await sut.getMessages(conversationId: message.conversationId, limit: 50)
        XCTAssertTrue(messages.contains(where: { $0.id == message.id }))
    }
    
    func testGetMessages_ReturnsMessagesForConversation() async throws {
        // Given
        let conversationId = UUID().uuidString
        let message1 = Message(
            id: UUID().uuidString,
            conversationId: conversationId,
            senderId: "user-1",
            text: "First message",
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
            readBy: [],
            readCount: 0,
            isPriority: false,
            priorityReason: nil
        )
        
        try await sut.sendMessage(message1)
        
        // When
        let messages = try await sut.getMessages(conversationId: conversationId, limit: 50)
        
        // Then
        XCTAssertFalse(messages.isEmpty)
        XCTAssertTrue(messages.contains(where: { $0.id == message1.id }))
    }
    
    func testGetMessages_WithLimit_RespectsLimit() async throws {
        // Given
        let conversationId = UUID().uuidString
        
        // Send multiple messages
        for i in 1...5 {
            let message = Message(
                id: UUID().uuidString,
                conversationId: conversationId,
                senderId: "user-1",
                text: "Message \(i)",
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
                readBy: [],
                readCount: 0,
                isPriority: false,
                priorityReason: nil
            )
            try await sut.sendMessage(message)
        }
        
        // When
        let messages = try await sut.getMessages(conversationId: conversationId, limit: 3)
        
        // Then
        XCTAssertLessThanOrEqual(messages.count, 3)
    }
    
    // MARK: - Observe Messages Tests
    
    func testObserveMessages_ReceivesRealTimeUpdates() async throws {
        // Given
        let conversationId = UUID().uuidString
        let expectation = XCTestExpectation(description: "Receive message update")
        var receivedMessages: [Message] = []
        
        let cancellable = sut.observeMessages(conversationId: conversationId)
            .sink { messages in
                receivedMessages = messages
                if !messages.isEmpty {
                    expectation.fulfill()
                }
            }
        
        // Wait for listener to set up
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // When
        let message = Message(
            id: UUID().uuidString,
            conversationId: conversationId,
            senderId: "user-1",
            text: "Real-time message",
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
            readBy: [],
            readCount: 0,
            isPriority: false,
            priorityReason: nil
        )
        try await sut.sendMessage(message)
        
        // Then
        await fulfillment(of: [expectation], timeout: 5.0)
        XCTAssertFalse(receivedMessages.isEmpty)
        XCTAssertTrue(receivedMessages.contains(where: { $0.id == message.id }))
        
        cancellable.cancel()
    }
}
