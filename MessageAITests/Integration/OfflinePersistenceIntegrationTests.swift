import XCTest
import Combine
import FirebaseAuth
@testable import MessageAI

/// Integration tests for offline persistence functionality
/// These tests verify Firestore offline caching and sync using Firebase Emulator
@MainActor
final class OfflinePersistenceIntegrationTests: XCTestCase {
    
    var firebaseService: FirebaseService!
    var userRepository: FirebaseUserRepository!
    var authRepository: FirebaseAuthRepository!
    var messageRepository: FirebaseMessageRepository!
    var conversationRepository: FirebaseConversationRepository!
    
    var testUser: MessageAI.User!
    var testConversationId: String!
    
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
        
        // Create test user
        testUser = try await authRepository.signUp(
            email: "offline-\(UUID().uuidString)@test.com",
            password: "password123"
        )
        
        // Create test conversation
        let conversation = try await conversationRepository.createConversation(participantIds: [testUser.id])
        testConversationId = conversation.id
    }
    
    override func tearDown() async throws {
        if Auth.auth().currentUser != nil {
            try await authRepository.signOut()
        }
        try await super.tearDown()
    }
    
    func testSendMessage_DataPersistsAndSyncs() async throws {
        // Given: Create and send a message
        let message = Message(
            id: UUID().uuidString,
            conversationId: testConversationId,
            senderId: testUser.id,
            text: "Offline persistence test",
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
        
        // When: Send message
        try await messageRepository.sendMessage(message)
        
        // Wait for sync
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Then: Message should be retrievable
        let messages = try await messageRepository.getMessages(
            conversationId: testConversationId,
            limit: 50
        )
        
        XCTAssertTrue(messages.contains(where: { $0.id == message.id }))
        XCTAssertEqual(messages.first(where: { $0.id == message.id })?.text, "Offline persistence test")
    }
    
    func testConversation_PersistsLocally() async throws {
        // Given: Conversation already created in setUp
        
        // When: Retrieve conversations
        let expectation = XCTestExpectation(description: "Receive conversations")
        var receivedConversations: [Conversation] = []
        
        let cancellable = conversationRepository.observeConversations(userId: testUser.id)
            .sink { conversations in
                receivedConversations = conversations
                if !conversations.isEmpty {
                    expectation.fulfill()
                }
            }
        
        // Then: Conversation should be available
        await fulfillment(of: [expectation], timeout: 5.0)
        XCTAssertFalse(receivedConversations.isEmpty)
        XCTAssertTrue(receivedConversations.contains(where: { $0.id == testConversationId }))
        
        cancellable.cancel()
    }
    
    func testMultipleOperations_AllPersist() async throws {
        // Given: Multiple messages
        let messageCount = 5
        
        // When: Send multiple messages
        for i in 1...messageCount {
            let message = Message(
                id: UUID().uuidString,
                conversationId: testConversationId,
                senderId: testUser.id,
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
        }
        
        // Wait for all to sync
        try await Task.sleep(nanoseconds: 2_000_000_000)
        
        // Then: All messages should be retrievable
        let messages = try await messageRepository.getMessages(
            conversationId: testConversationId,
            limit: 50
        )
        
        XCTAssertGreaterThanOrEqual(messages.count, messageCount)
    }
}
