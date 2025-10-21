import XCTest
import Combine
import FirebaseAuth
@testable import MessageAI

/// Performance baseline tests for critical operations
/// Establishes performance targets for regression detection
@MainActor
final class PerformanceBaselineTests: XCTestCase {
    
    var firebaseService: FirebaseService!
    var userRepository: FirebaseUserRepository!
    var authRepository: FirebaseAuthRepository!
    var messageRepository: FirebaseMessageRepository!
    var conversationRepository: FirebaseConversationRepository!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Configure emulator
        firebaseService = FirebaseService()
        firebaseService.useEmulator()
        firebaseService.configure()
        
        userRepository = FirebaseUserRepository(firebaseService: firebaseService)
        authRepository = FirebaseAuthRepository(firebaseService: firebaseService, userRepository: userRepository)
        messageRepository = FirebaseMessageRepository(firebaseService: firebaseService)
        conversationRepository = FirebaseConversationRepository(firebaseService: firebaseService)
        
        // Clean up any existing auth
        if Auth.auth().currentUser != nil {
            try await authRepository.signOut()
        }
    }
    
    override func tearDown() async throws {
        if Auth.auth().currentUser != nil {
            try await authRepository.signOut()
        }
        try await super.tearDown()
    }
    
    // MARK: - Message Send Performance
    
    func testPerformance_SendMessage() async throws {
        // Given: Authenticated user and conversation
        let user = try await authRepository.signUp(
            email: "perf-\(UUID().uuidString)@test.com",
            password: "password123"
        )
        
        let conversationId = UUID().uuidString
        let message = Message(
            id: UUID().uuidString,
            conversationId: conversationId,
            senderId: user.id,
            text: "Performance test message",
            timestamp: Date(),
            status: .sending,
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
        
        // When: Measure send time
        let start = Date()
        try await messageRepository.sendMessage(message)
        let duration = Date().timeIntervalSince(start)
        
        // Then: Should complete in < 2 seconds
        print("📊 Message send time: \(duration) seconds")
        XCTAssertLessThan(duration, 2.0, "Message send should take < 2 seconds (actual: \(duration)s)")
    }
    
    // MARK: - Conversation Load Performance
    
    func testPerformance_LoadConversations() async throws {
        // Given: Authenticated user with conversations
        let user = try await authRepository.signUp(
            email: "perf-conv-\(UUID().uuidString)@test.com",
            password: "password123"
        )
        
        // Create test conversations
        for _ in 1...5 {
            _ = try await conversationRepository.createConversation(participantIds: [user.id])
        }
        
        // Wait for sync
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // When: Measure load time (using real-time listener)
        let start = Date()
        let expectation = XCTestExpectation(description: "Load conversations")
        var conversationCount = 0
        
        let cancellable = conversationRepository.observeConversations(userId: user.id)
            .sink { conversations in
                conversationCount = conversations.count
                expectation.fulfill()
            }
        
        await fulfillment(of: [expectation], timeout: 2.0)
        let duration = Date().timeIntervalSince(start)
        
        cancellable.cancel()
        
        // Then: Should complete in < 1 second
        print("📊 Conversation load time: \(duration) seconds (loaded \(conversationCount) conversations)")
        XCTAssertLessThan(duration, 1.0, "Loading conversations should take < 1 second (actual: \(duration)s)")
    }
    
    // MARK: - Authentication Performance
    
    func testPerformance_Authentication() async throws {
        // Given: New user credentials
        let email = "perf-auth-\(UUID().uuidString)@test.com"
        let password = "password123"
        
        // When: Measure sign up time
        let start = Date()
        _ = try await authRepository.signUp(email: email, password: password)
        let duration = Date().timeIntervalSince(start)
        
        // Then: Should complete in < 2 seconds
        print("📊 Authentication time: \(duration) seconds")
        XCTAssertLessThan(duration, 2.0, "Authentication should take < 2 seconds (actual: \(duration)s)")
    }
    
    // MARK: - Message Load Performance
    
    func testPerformance_LoadMessages() async throws {
        // Given: Conversation with 50 messages
        let user = try await authRepository.signUp(
            email: "perf-msg-\(UUID().uuidString)@test.com",
            password: "password123"
        )
        
        let conversationId = UUID().uuidString
        
        // Create 50 messages
        for i in 1...50 {
            let message = Message(
                id: UUID().uuidString,
                conversationId: conversationId,
                senderId: user.id,
                text: "Test message \(i)",
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
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // When: Measure load time
        let start = Date()
        let messages = try await messageRepository.getMessages(conversationId: conversationId, limit: 50)
        let duration = Date().timeIntervalSince(start)
        
        // Then: Should complete in < 1 second
        print("📊 Message load time: \(duration) seconds (loaded \(messages.count) messages)")
        XCTAssertLessThan(duration, 1.0, "Loading 50 messages should take < 1 second (actual: \(duration)s)")
    }
}

