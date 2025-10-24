import Foundation

/// Protocol defining notification analysis operations (Epic 6 - Story 6.1)
///
/// Calls Cloud Function to analyze conversation for notification decision
protocol NotificationAnalysisRepositoryProtocol {
    /// Analyze a conversation to determine if notification should be sent
    ///
    /// Calls the `analyzeForNotification` Cloud Function with conversation context
    ///
    /// - Parameters:
    ///   - conversationId: The conversation to analyze
    ///   - userId: The user who would receive the notification
    /// - Returns: Decision result with reasoning and notification text
    /// - Throws: RepositoryError if analysis fails
    func analyzeConversationForNotification(
        conversationId: String,
        userId: String
    ) async throws -> NotificationDecision
}
