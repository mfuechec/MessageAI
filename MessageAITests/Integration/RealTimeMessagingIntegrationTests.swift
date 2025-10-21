import XCTest
import Combine
import FirebaseAuth
@testable import MessageAI

/// Integration tests for real-time messaging functionality
/// These tests verify end-to-end message flow using Firebase Emulator
@MainActor
final class RealTimeMessagingIntegrationTests: XCTestCase {
    
    var firebaseService: FirebaseService!
    var userRepository: FirebaseUserRepository!
    var authRepository: FirebaseAuthRepository!
    var messageRepository: FirebaseMessageRepository!
    var conversationRepository: FirebaseConversationRepository!
    
    var userA: MessageAI.User!
    var userB: MessageAI.User!
    var conversationId: String!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Skip all tests if emulator not running
        // To run these tests: ./scripts/start-emulator.sh
        try XCTSkipIf(true, "Requires Firebase Emulator - start with ./scripts/start-emulator.sh")
        
        // Configure emulator
        firebaseService = FirebaseService()
        firebaseService.useEmulator()
        firebaseService.configure()
        
        // Initialize repositories
        userRepository = FirebaseUserRepository(firebaseService: firebaseService)
        authRepository = FirebaseAuthRepository(firebaseService: firebaseService, userRepository: userRepository)
        messageRepository = FirebaseMessageRepository(firebaseService: firebaseService)
        conversationRepository = FirebaseConversationRepository(firebaseService: firebaseService)
        
        // Clean up any existing auth
        if Auth.auth().currentUser != nil {
            try await authRepository.signOut()
        }
        
        // Create two test users
        userA = try await authRepository.signUp(
            email: "userA-\(UUID().uuidString)@test.com",
            password: "password123"
        )
        try await authRepository.signOut()
        
        userB = try await authRepository.signUp(
            email: "userB-\(UUID().uuidString)@test.com",
            password: "password123"
        )
        
        // Create conversation between them
        let conversation = try await conversationRepository.createConversation(participantIds: [userA.id, userB.id])
        conversationId = conversation.id
    }
    
    override func tearDown() async throws {
        // Clean up emulator data
        if Auth.auth().currentUser != nil {
            try await authRepository.signOut()
        }
        try await super.tearDown()
    }
    
    func testSendMessage_UserAToUserB_UserBReceivesRealTime() async throws {
        // Given
        let expectation = XCTestExpectation(description: "User B receives message")
        var receivedMessages: [Message] = []
        
        // User B observes messages
        let cancellable = messageRepository.observeMessages(
            conversationId: conversationId
        )
        .sink { messages in
            receivedMessages = messages
            if !messages.isEmpty {
                expectation.fulfill()
            }
        }
        
        // Wait for listener to set up
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // When: User A sends message
        let message = Message(
            id: UUID().uuidString,
            conversationId: conversationId,
            senderId: userA.id,
            text: "Hello from User A!",
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
        
        try await messageRepository.sendMessage(message)
        
        // Then: User B receives message in real-time
        await fulfillment(of: [expectation], timeout: 5.0)
        
        XCTAssertEqual(receivedMessages.count, 1)
        XCTAssertEqual(receivedMessages.first?.text, "Hello from User A!")
        XCTAssertEqual(receivedMessages.first?.senderId, userA.id)
        
        cancellable.cancel()
    }
    
    func testMultipleMessages_RealTimeOrdering() async throws {
        // Given
        let expectation = XCTestExpectation(description: "Receive multiple messages")
        var receivedMessages: [Message] = []
        
        let cancellable = messageRepository.observeMessages(conversationId: conversationId)
            .sink { messages in
                receivedMessages = messages
                if messages.count >= 3 {
                    expectation.fulfill()
                }
            }
        
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // When: Send 3 messages
        for i in 1...3 {
            let message = Message(
                id: UUID().uuidString,
                conversationId: conversationId,
                senderId: userA.id,
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
            try await messageRepository.sendMessage(message)
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds between messages
        }
        
        // Then
        await fulfillment(of: [expectation], timeout: 5.0)
        XCTAssertEqual(receivedMessages.count, 3)
        
        // Verify ordering (should be oldest first)
        XCTAssertEqual(receivedMessages[0].text, "Message 1")
        XCTAssertEqual(receivedMessages[1].text, "Message 2")
        XCTAssertEqual(receivedMessages[2].text, "Message 3")
        
        cancellable.cancel()
    }
    
    // MARK: - Duplicate Conversation Prevention Tests (Story 2.0)
    
    func testGetOrCreateConversation_RaceCondition() async throws {
        throw XCTSkip("Requires Firebase Emulator - Story 1.10")
        
        // Given: User A and User B both exist
        // And: No conversation exists between them
        // When: User A calls getOrCreateConversation([A, B]) simultaneously with
        //       User B calls getOrCreateConversation([B, A])
        // Then: Both calls should return the same conversation ID
        // And: Only ONE conversation should exist in Firestore (no duplicate)
        // And: Conversation participantIds should be sorted consistently
        //
        // Implementation Notes:
        // - Use Task.detached to simulate simultaneous calls
        // - Query Firestore to verify only one conversation exists
        // - Verify both returned conversations have same ID
    }
}
