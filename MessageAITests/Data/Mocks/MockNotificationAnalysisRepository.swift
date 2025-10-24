import Foundation
@testable import MessageAI

/// Mock implementation of NotificationAnalysisRepositoryProtocol for testing
class MockNotificationAnalysisRepository: NotificationAnalysisRepositoryProtocol {

    // MARK: - Tracking Booleans

    var analyzeConversationForNotificationCalled = false

    // MARK: - Configurable Return Values

    var mockDecision: NotificationDecision?
    var mockError: Error?
    var shouldFail = false

    // MARK: - Captured Parameters

    var capturedConversationId: String?
    var capturedUserId: String?

    // MARK: - NotificationAnalysisRepositoryProtocol

    func analyzeConversationForNotification(
        conversationId: String,
        userId: String
    ) async throws -> NotificationDecision {
        analyzeConversationForNotificationCalled = true
        capturedConversationId = conversationId
        capturedUserId = userId

        if shouldFail {
            throw mockError ?? NSError(domain: "MockError", code: -1, userInfo: nil)
        }

        return mockDecision ?? NotificationDecision(
            shouldNotify: false,
            reason: "Mock decision - no notification needed",
            notificationText: nil,
            priority: .low,
            timestamp: Date(),
            conversationId: conversationId,
            messageIds: nil
        )
    }
}
