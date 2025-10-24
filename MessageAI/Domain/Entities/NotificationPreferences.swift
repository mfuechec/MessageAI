import Foundation

/// Fallback strategy for when AI analysis is unavailable
enum FallbackStrategy: String, Codable {
    case simpleRules = "simple_rules"   // Use keyword/mention detection
    case notifyAll = "notify_all"       // Send all notifications
    case suppressAll = "suppress_all"   // Suppress all notifications
}

/// User preferences for smart AI-powered notifications (Epic 6 - Story 6.4)
///
/// Stored in Firestore: users/{userId}/ai_notification_preferences/preferences
///
/// Controls when and how AI analyzes conversations for notification decisions
struct NotificationPreferences: Codable, Equatable {
    let userId: String
    var enabled: Bool
    var pauseThresholdSeconds: Int          // 60-300 seconds
    var activeConversationThreshold: Int    // 10-50 messages
    var quietHoursStart: String             // "22:00"
    var quietHoursEnd: String               // "08:00"
    var timezone: String                    // TimeZone identifier
    var priorityKeywords: [String]          // User-customizable keywords
    var maxAnalysesPerHour: Int             // 5-20, cost control
    var fallbackStrategy: FallbackStrategy
    var createdAt: Date
    var updatedAt: Date

    /// Default notification preferences for new users
    static var `default`: NotificationPreferences {
        NotificationPreferences(
            userId: "",
            enabled: true,
            pauseThresholdSeconds: 120,
            activeConversationThreshold: 20,
            quietHoursStart: "22:00",
            quietHoursEnd: "08:00",
            timezone: TimeZone.current.identifier,
            priorityKeywords: ["urgent", "ASAP", "production down", "blocker", "help"],
            maxAnalysesPerHour: 10,
            fallbackStrategy: .simpleRules,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    /// Check if current time is within quiet hours
    var isInQuietHours: Bool {
        guard let userTimezone = TimeZone(identifier: timezone) else {
            return false
        }

        var calendar = Calendar.current
        calendar.timeZone = userTimezone

        let now = Date()
        let components = calendar.dateComponents([.hour, .minute], from: now)

        guard let currentHour = components.hour,
              let currentMinute = components.minute else {
            return false
        }

        let currentTimeInMinutes = currentHour * 60 + currentMinute

        // Parse quiet hours start/end (format: "HH:mm")
        let startParts = quietHoursStart.split(separator: ":")
        let endParts = quietHoursEnd.split(separator: ":")

        guard startParts.count == 2, endParts.count == 2,
              let startHour = Int(startParts[0]),
              let startMinute = Int(startParts[1]),
              let endHour = Int(endParts[0]),
              let endMinute = Int(endParts[1]) else {
            return false
        }

        let startTimeInMinutes = startHour * 60 + startMinute
        let endTimeInMinutes = endHour * 60 + endMinute

        // Handle overnight quiet hours (e.g., 22:00 to 08:00)
        if startTimeInMinutes > endTimeInMinutes {
            return currentTimeInMinutes >= startTimeInMinutes ||
                   currentTimeInMinutes < endTimeInMinutes
        } else {
            return currentTimeInMinutes >= startTimeInMinutes &&
                   currentTimeInMinutes < endTimeInMinutes
        }
    }

    init(
        userId: String,
        enabled: Bool,
        pauseThresholdSeconds: Int,
        activeConversationThreshold: Int,
        quietHoursStart: String,
        quietHoursEnd: String,
        timezone: String,
        priorityKeywords: [String],
        maxAnalysesPerHour: Int,
        fallbackStrategy: FallbackStrategy,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.userId = userId
        self.enabled = enabled
        self.pauseThresholdSeconds = pauseThresholdSeconds
        self.activeConversationThreshold = activeConversationThreshold
        self.quietHoursStart = quietHoursStart
        self.quietHoursEnd = quietHoursEnd
        self.timezone = timezone
        self.priorityKeywords = priorityKeywords
        self.maxAnalysesPerHour = maxAnalysesPerHour
        self.fallbackStrategy = fallbackStrategy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
