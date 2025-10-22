import Foundation
import Combine
@testable import MessageAI

/// Mock implementation of MessageRepositoryProtocol for testing
class MockMessageRepository: MessageRepositoryProtocol {
    // MARK: - Tracking Properties

    var sendMessageCalled = false
    var sendMessageCallCount = 0  // Story 2.9: Track multiple sends
    var observeMessagesCalled = false
    var getMessagesCalled = false
    var updateMessageStatusCalled = false
    var editMessageCalled = false
    var deleteMessageCalled = false
    var markMessagesAsReadCalled = false
    var shouldFail = false
    var shouldFailMessageId: String?  // Story 2.9: Fail specific message

    // MARK: - Configurable Properties

    var mockMessages: [Message] = []
    var mockError: Error?
    
    // MARK: - Captured Parameters
    
    var capturedMessage: Message?
    var capturedConversationId: String?
    var capturedLimit: Int?
    var capturedMessageId: String?
    var capturedStatus: MessageStatus?
    var capturedEditMessageId: String?
    var capturedEditNewText: String?
    var capturedDeleteMessageId: String?
    var capturedReadMessageIds: [String]?
    var capturedReadUserId: String?
    
    // MARK: - MessageRepositoryProtocol Implementation
    
    func sendMessage(_ message: Message) async throws {
        sendMessageCalled = true
        sendMessageCallCount += 1
        capturedMessage = message

        // Story 2.9: Conditional failure based on message ID
        if let failId = shouldFailMessageId, message.id == failId {
            throw mockError ?? RepositoryError.messageNotFound("Mock send failure for message \(failId)")
        }

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
        editMessageCalled = true
        capturedEditMessageId = id
        capturedEditNewText = newText
        
        if shouldFail {
            throw mockError ?? RepositoryError.messageNotFound("Mock error")
        }
        
        // Update message in mockMessages for testing
        if let index = mockMessages.firstIndex(where: { $0.id == id }) {
            var updatedMessage = mockMessages[index]
            updatedMessage.text = newText
            updatedMessage.isEdited = true
            updatedMessage.editCount += 1
            mockMessages[index] = updatedMessage
        }
    }
    
    func deleteMessage(id: String) async throws {
        deleteMessageCalled = true
        capturedDeleteMessageId = id
        
        if shouldFail {
            throw mockError ?? RepositoryError.messageNotFound("Mock error")
        }
        
        // Mark message as deleted in mockMessages for testing
        if let index = mockMessages.firstIndex(where: { $0.id == id }) {
            var deletedMessage = mockMessages[index]
            deletedMessage.isDeleted = true
            deletedMessage.deletedAt = Date()
            deletedMessage.text = ""
            mockMessages[index] = deletedMessage
        }
    }
    
    func markMessagesAsRead(messageIds: [String], userId: String) async throws {
        markMessagesAsReadCalled = true
        capturedReadMessageIds = messageIds
        capturedReadUserId = userId
        
        if shouldFail {
            throw mockError ?? RepositoryError.messageNotFound("Mock error")
        }
        
        // Update messages in mockMessages for testing
        for messageId in messageIds {
            if let index = mockMessages.firstIndex(where: { $0.id == messageId }) {
                var message = mockMessages[index]
                if !message.readBy.contains(userId) {
                    message.readBy.append(userId)
                    message.readCount += 1
                }
                message.status = .read
                message.statusUpdatedAt = Date()
                mockMessages[index] = message
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Resets all tracking and configurable properties
    func reset() {
        sendMessageCalled = false
        sendMessageCallCount = 0
        observeMessagesCalled = false
        getMessagesCalled = false
        updateMessageStatusCalled = false
        editMessageCalled = false
        deleteMessageCalled = false
        markMessagesAsReadCalled = false
        shouldFail = false
        shouldFailMessageId = nil
        mockMessages = []
        mockError = nil
        capturedMessage = nil
        capturedConversationId = nil
        capturedLimit = nil
        capturedMessageId = nil
        capturedStatus = nil
        capturedEditMessageId = nil
        capturedEditNewText = nil
        capturedDeleteMessageId = nil
        capturedReadMessageIds = nil
        capturedReadUserId = nil
    }
}

