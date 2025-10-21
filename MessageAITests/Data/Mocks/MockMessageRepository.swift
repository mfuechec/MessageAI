import Foundation
import Combine
@testable import MessageAI

/// Mock implementation of MessageRepositoryProtocol for testing
class MockMessageRepository: MessageRepositoryProtocol {
    // MARK: - Tracking Properties
    
    var sendMessageCalled = false
    var observeMessagesCalled = false
    var getMessagesCalled = false
    var updateMessageStatusCalled = false
    var shouldFail = false
    
    // MARK: - Configurable Properties
    
    var mockMessages: [Message] = []
    var mockError: Error?
    
    // MARK: - Captured Parameters
    
    var capturedMessage: Message?
    var capturedConversationId: String?
    var capturedLimit: Int?
    var capturedMessageId: String?
    var capturedStatus: MessageStatus?
    
    // MARK: - MessageRepositoryProtocol Implementation
    
    func sendMessage(_ message: Message) async throws {
        sendMessageCalled = true
        capturedMessage = message
        
        if shouldFail {
            throw mockError ?? RepositoryError.messageNotFound("Mock error")
        }
        
        // Add message to mock messages for observeMessages to return
        mockMessages.append(message)
    }
    
    func observeMessages(conversationId: String) -> AnyPublisher<[Message], Never> {
        observeMessagesCalled = true
        capturedConversationId = conversationId
        
        return Just(mockMessages).eraseToAnyPublisher()
    }
    
    func getMessages(conversationId: String, limit: Int) async throws -> [Message] {
        getMessagesCalled = true
        capturedConversationId = conversationId
        capturedLimit = limit
        
        if shouldFail {
            throw mockError ?? RepositoryError.messageNotFound("Mock error")
        }
        
        return Array(mockMessages.prefix(limit))
    }
    
    func updateMessageStatus(messageId: String, status: MessageStatus) async throws {
        updateMessageStatusCalled = true
        capturedMessageId = messageId
        capturedStatus = status
        
        if shouldFail {
            throw mockError ?? RepositoryError.messageNotFound("Mock error")
        }
        
        // Update message in mockMessages
        if let index = mockMessages.firstIndex(where: { $0.id == messageId }) {
            var message = mockMessages[index]
            message.status = status
            message.statusUpdatedAt = Date()
            mockMessages[index] = message
        }
    }
    
    func editMessage(id: String, newText: String) async throws {
        // Placeholder for future implementation
        if shouldFail {
            throw mockError ?? RepositoryError.messageNotFound("Mock error")
        }
    }
    
    func deleteMessage(id: String) async throws {
        // Placeholder for future implementation
        if shouldFail {
            throw mockError ?? RepositoryError.messageNotFound("Mock error")
        }
    }
    
    // MARK: - Helper Methods
    
    /// Resets all tracking and configurable properties
    func reset() {
        sendMessageCalled = false
        observeMessagesCalled = false
        getMessagesCalled = false
        updateMessageStatusCalled = false
        shouldFail = false
        mockMessages = []
        mockError = nil
        capturedMessage = nil
        capturedConversationId = nil
        capturedLimit = nil
        capturedMessageId = nil
        capturedStatus = nil
    }
}

