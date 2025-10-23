import Foundation
import Combine

/// Protocol defining conversation data operations (implemented in Data layer)
protocol ConversationRepositoryProtocol {
    /// Get a single conversation by ID
    /// - Parameter id: The conversation ID
    /// - Returns: The conversation entity
    func getConversation(id: String) async throws -> Conversation
    
    /// Create a new conversation
    /// - Parameter participantIds: Array of user IDs in the conversation
    /// - Returns: The newly created conversation
    func createConversation(participantIds: [String]) async throws -> Conversation
    
    /// Get existing conversation or create new one with duplicate prevention
    /// [Source: docs/architecture/data-models.md#duplicate-prevention]
    /// - Parameter participantIds: Array of user IDs (will be sorted internally for consistent matching)
    /// - Returns: Existing conversation if found, otherwise newly created conversation
    func getOrCreateConversation(participantIds: [String]) async throws -> Conversation
    
    /// Observe conversations in real-time for a user
    /// - Parameter userId: The user ID whose conversations to observe
    /// - Returns: Publisher emitting updated conversation arrays
    func observeConversations(userId: String) -> AnyPublisher<[Conversation], Never>
    
    /// Update unread count for a user in a conversation
    /// - Parameters:
    ///   - conversationId: The conversation ID
    ///   - userId: The user ID
    ///   - count: The new unread count
    func updateUnreadCount(conversationId: String, userId: String, count: Int) async throws
    
    /// Mark conversation as read (set unread count to 0)
    /// - Parameters:
    ///   - conversationId: The conversation ID
    ///   - userId: The user ID
    func markAsRead(conversationId: String, userId: String) async throws
    
    /// Update conversation fields (e.g., lastMessage, lastMessageTimestamp)
    /// - Parameters:
    ///   - id: The conversation ID
    ///   - updates: Dictionary of field names to values
    func updateConversation(id: String, updates: [String: Any]) async throws

    /// Update typing state for current user in conversation
    /// - Parameters:
    ///   - conversationId: The conversation ID
    ///   - userId: The user ID
    ///   - isTyping: True if user is typing, false if stopped
    func updateTypingState(conversationId: String, userId: String, isTyping: Bool) async throws

    /// Load more conversations for pagination (Story 2.11 - AC #3)
    /// - Parameters:
    ///   - userId: The user ID whose conversations to load
    ///   - lastConversation: The last conversation from previous page (for cursor-based pagination)
    ///   - limit: Number of conversations to load (default: 50)
    /// - Returns: Array of older conversations
    func loadMoreConversations(userId: String, lastConversation: Conversation?, limit: Int) async throws -> [Conversation]

    /// Load conversations from local cache (offline-first strategy)
    /// - Parameter userId: The user ID whose conversations to load
    /// - Returns: Array of cached conversations (empty if no cache available)
    func getConversationsFromCache(userId: String) async throws -> [Conversation]
}

