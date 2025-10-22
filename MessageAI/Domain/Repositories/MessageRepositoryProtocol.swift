import Foundation
import Combine

/// Protocol defining message data operations (implemented in Data layer)
protocol MessageRepositoryProtocol {
    /// Send a new message to Firestore
    /// - Parameter message: The message to send
    func sendMessage(_ message: Message) async throws
    
    /// Observe messages in real-time for a conversation
    /// - Parameter conversationId: The conversation ID to observe
    /// - Returns: Publisher emitting updated message arrays
    func observeMessages(conversationId: String) -> AnyPublisher<[Message], Never>
    
    /// Get messages with pagination support
    /// - Parameters:
    ///   - conversationId: The conversation ID
    ///   - limit: Maximum number of messages to fetch
    /// - Returns: Array of messages
    func getMessages(conversationId: String, limit: Int) async throws -> [Message]
    
    /// Update message delivery/read status
    /// - Parameters:
    ///   - messageId: The message ID to update
    ///   - status: The new status
    func updateMessageStatus(messageId: String, status: MessageStatus) async throws
    
    /// Edit an existing message
    /// - Parameters:
    ///   - id: The message ID to edit
    ///   - newText: The new message text
    func editMessage(id: String, newText: String) async throws
    
    /// Soft delete a message (sets isDeleted flag)
    /// - Parameter id: The message ID to delete
    func deleteMessage(id: String) async throws
    
    /// Mark messages as read by a specific user
    /// - Parameters:
    ///   - messageIds: Array of message IDs to mark as read
    ///   - userId: The user ID marking messages as read
    func markMessagesAsRead(messageIds: [String], userId: String) async throws
}

