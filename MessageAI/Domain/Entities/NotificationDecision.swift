import Foundation

/// Priority level for notification
enum NotificationPriority: String, Codable {
    case high
    case medium
    case low
}

/// AI decision result for whether to send a notification (Epic 6 - Story 6.1)
///
/// Returned from Cloud Function `analyzeForNotification`
struct NotificationDecision: Codable, Equatable {
    /// Whether notification should be sent
    let shouldNotify: Bool

    /// Human-readable reason for the decision
    let reason: String

    /// Generated notification text (nil if should not notify)
    let notificationText: String?

    /// Priority level of the notification
    let priority: NotificationPriority

    /// Timestamp when decision was made
    let timestamp: Date

    /// Optional: Conversation ID this decision is for
    let conversationId: String?

    /// Optional: Message IDs analyzed
    let messageIds: [String]?

    init(
        shouldNotify: Bool,
        reason: String,
        notificationText: String?,
        priority: NotificationPriority,
        timestamp: Date,
        conversationId: String? = nil,
        messageIds: [String]? = nil
    ) {
        self.shouldNotify = shouldNotify
        self.reason = reason
        self.notificationText = notificationText
        self.priority = priority
        self.timestamp = timestamp
        self.conversationId = conversationId
        self.messageIds = messageIds
    }
}
