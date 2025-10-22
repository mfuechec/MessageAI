import Foundation

/// Utility for formatting timestamps relative to now
/// Used in conversation list to show "2m ago", "5h ago", etc.
struct RelativeTimestampFormatter {

    /// Format timestamp relative to now: "Now", "Xm ago", "Xh ago", "Yesterday", "MMM d"
    /// - Parameter date: The timestamp to format
    /// - Returns: Formatted relative string
    static func format(_ date: Date) -> String {
        let now = Date()
        let interval = now.timeIntervalSince(date)

        // Handle future timestamps (clock skew)
        if interval < 0 {
            return "Now"
        }

        // Less than 1 minute: "Now"
        if interval < 60 {
            return "Now"
        }

        // Less than 1 hour: "Xm ago"
        if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        }

        // Less than 24 hours: "Xh ago"
        if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        }

        // Less than 48 hours: "Yesterday"
        if interval < 172800 {
            return "Yesterday"
        }

        // Older: "MMM d" format
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}
