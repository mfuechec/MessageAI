import Foundation

/// Protocol defining smart reply operations (implemented in Data layer)
protocol SmartReplyRepositoryProtocol {
    /// Generate AI-powered smart reply suggestions for a message
    /// - Parameters:
    ///   - conversationId: The conversation ID
    ///   - messageId: The message to generate replies for
    ///   - recentMessages: Recent conversation context (last 5-10 messages)
    /// - Returns: SmartReply entity with suggested responses
    func generateSmartReplies(
        conversationId: String,
        messageId: String,
        recentMessages: [Message]
    ) async throws -> SmartReply
}
