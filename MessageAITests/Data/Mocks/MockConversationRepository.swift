import Foundation
import Combine
@testable import MessageAI

/// Mock implementation of ConversationRepositoryProtocol for testing
class MockConversationRepository: ConversationRepositoryProtocol {
    
    // MARK: - Tracking Booleans
    
    var observeConversationsCalled = false
    var getConversationCalled = false
    var createConversationCalled = false
    var getOrCreateConversationCalled = false
    var updateUnreadCountCalled = false
    var markAsReadCalled = false
    var updateConversationCalled = false
    var updateTypingStateCalled = false
    var loadMoreConversationsCalled = false
    var getConversationsFromCacheCalled = false

    // MARK: - Configurable Return Values
    
    var mockConversations: [Conversation] = []
    var mockConversation: Conversation?
    var mockError: Error?
    var shouldFail = false
    
    // MARK: - Captured Parameters
    
    var capturedUserId: String?
    var capturedConversationId: String?
    var capturedParticipantIds: [String]?
    var capturedUnreadCount: Int?
    var capturedUpdates: [String: Any]?
    var capturedTypingUserId: String?
    var capturedIsTyping: Bool?
    var capturedLastConversation: Conversation?
    var capturedLimit: Int?

    // MARK: - ConversationRepositoryProtocol Implementation
    
    func getConversation(id: String) async throws -> Conversation {
        getConversationCalled = true
        capturedConversationId = id
        
        if shouldFail, let error = mockError {
            throw error
        }
        
        if let conversation = mockConversations.first(where: { $0.id == id }) {
            return conversation
        }
        
        if let conversation = mockConversation {
            return conversation
        }
        
        throw RepositoryError.conversationNotFound("Conversation not found")
    }
    
    func createConversation(participantIds: [String]) async throws -> Conversation {
        createConversationCalled = true
        capturedParticipantIds = participantIds
        
        if shouldFail, let error = mockError {
            throw error
        }
        
        if let conversation = mockConversation {
            return conversation
        }
        
        throw RepositoryError.conversationNotFound("Mock conversation not configured")
    }
    
    func getOrCreateConversation(participantIds: [String]) async throws -> Conversation {
        getOrCreateConversationCalled = true
        capturedParticipantIds = participantIds
        
        if shouldFail, let error = mockError {
            throw error
        }
        
        if let conversation = mockConversation {
            return conversation
        }
        
        throw RepositoryError.conversationNotFound("Mock conversation not configured")
    }
    
    func observeConversations(userId: String) -> AnyPublisher<[Conversation], Never> {
        observeConversationsCalled = true
        capturedUserId = userId
        
        return Just(mockConversations).eraseToAnyPublisher()
    }
    
    func updateUnreadCount(conversationId: String, userId: String, count: Int) async throws {
        updateUnreadCountCalled = true
        capturedConversationId = conversationId
        capturedUserId = userId
        capturedUnreadCount = count
        
        if shouldFail, let error = mockError {
            throw error
        }
    }
    
    func markAsRead(conversationId: String, userId: String) async throws {
        markAsReadCalled = true
        capturedConversationId = conversationId
        capturedUserId = userId
        
        if shouldFail, let error = mockError {
            throw error
        }
    }
    
    func updateConversation(id: String, updates: [String: Any]) async throws {
        updateConversationCalled = true
        capturedConversationId = id
        capturedUpdates = updates

        if shouldFail, let error = mockError {
            throw error
        }
    }

    func updateTypingState(conversationId: String, userId: String, isTyping: Bool) async throws {
        updateTypingStateCalled = true
        capturedConversationId = conversationId
        capturedTypingUserId = userId
        capturedIsTyping = isTyping

        if shouldFail, let error = mockError {
            throw error
        }
    }

    func loadMoreConversations(userId: String, lastConversation: Conversation?, limit: Int) async throws -> [Conversation] {
        loadMoreConversationsCalled = true
        capturedUserId = userId
        capturedLastConversation = lastConversation
        capturedLimit = limit

        if shouldFail, let error = mockError {
            throw error
        }

        return mockConversations
    }

    func getConversationsFromCache(userId: String) async throws -> [Conversation] {
        getConversationsFromCacheCalled = true
        capturedUserId = userId

        if shouldFail, let error = mockError {
            throw error
        }

        return mockConversations
    }

    // MARK: - Reset

    func reset() {
        observeConversationsCalled = false
        getConversationCalled = false
        createConversationCalled = false
        getOrCreateConversationCalled = false
        updateUnreadCountCalled = false
        markAsReadCalled = false
        updateConversationCalled = false
        updateTypingStateCalled = false
        loadMoreConversationsCalled = false
        getConversationsFromCacheCalled = false

        mockConversations = []
        mockConversation = nil
        mockError = nil
        shouldFail = false

        capturedUserId = nil
        capturedConversationId = nil
        capturedParticipantIds = nil
        capturedUnreadCount = nil
        capturedUpdates = nil
        capturedTypingUserId = nil
        capturedIsTyping = nil
        capturedLastConversation = nil
        capturedLimit = nil
    }
}

