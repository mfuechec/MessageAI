import Foundation

/// Entry in notification decision history (Epic 6 - Story 6.5)
struct NotificationHistoryEntry: Identifiable {
    let id: String
    let conversationId: String
    let conversationName: String
    let messageId: String
    let notificationText: String
    let aiReasoning: String
    let timestamp: Date
    let decision: NotificationDecision
    var userFeedback: String?  // "helpful" or "not_helpful"
}

/// Protocol defining notification history operations (Epic 6 - Story 6.5)
///
/// Provides access to notification decision history and feedback submission
protocol NotificationHistoryRepositoryProtocol {
    /// Fetch recent notification decisions for a user
    ///
    /// - Parameters:
    ///   - userId: The user whose history to fetch
    ///   - limit: Maximum number of entries to return (default: 20)
    /// - Returns: Array of notification history entries
    /// - Throws: RepositoryError if fetch fails
    func getRecentDecisions(userId: String, limit: Int) async throws -> [NotificationHistoryEntry]

    /// Submit feedback for a notification decision
    ///
    /// - Parameters:
    ///   - userId: The user submitting feedback
    ///   - conversationId: The conversation the notification was about
    ///   - messageId: The message that triggered the notification
    ///   - feedback: "helpful" or "not_helpful"
    /// - Throws: RepositoryError if submission fails
    func submitFeedback(
        userId: String,
        conversationId: String,
        messageId: String,
        feedback: String
    ) async throws
}
