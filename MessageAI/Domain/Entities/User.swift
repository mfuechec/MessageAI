import Foundation

/// User presence status for visual indicators
enum PresenceStatus {
    case online       // Green: Currently online
    case recentlyOffline  // Yellow: Offline within last 15 minutes
    case offline      // Gray: Offline more than 15 minutes
    
    var color: (red: Double, green: Double, blue: Double) {
        switch self {
        case .online:
            return (0.0, 0.8, 0.0) // Green
        case .recentlyOffline:
            return (1.0, 0.75, 0.0) // Orange/Yellow
        case .offline:
            return (0.6, 0.6, 0.6) // Gray
        }
    }
}

/// Core domain entity representing an authenticated user
struct User: Codable, Equatable, Identifiable, Hashable {
    let id: String
    let email: String
    var displayName: String
    var profileImageURL: String?
    var isOnline: Bool
    var lastSeen: Date
    let createdAt: Date
    var fcmToken: String?
    var fcmTokenUpdatedAt: Date?
    var currentConversationId: String?  // For notification suppression (Story 2.10 QA Fix)
    var timezone: String?
    var locale: String?
    var preferredLanguage: String?
    var googleCalendarConnected: Bool
    var googleCalendarRefreshToken: String?  // Encrypted OAuth refresh token
    var googleCalendarEmail: String?  // Email used for Google Calendar
    var googleCalendarConnectedAt: Date?
    let schemaVersion: Int
    
    /// Computed property for truncated display name (max 15 chars)
    var truncatedDisplayName: String {
        if displayName.count > 15 {
            return String(displayName.prefix(15)) + "..."
        }
        return displayName
    }
    
    /// Computed property for display initials (e.g., "John Doe" → "JD")
    var displayInitials: String {
        let words = displayName.split(separator: " ")
        if words.count >= 2 {
            return String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
        } else {
            return String(displayName.prefix(2)).uppercased()
        }
    }
    
    /// Computed property for presence status with 3 states:
    /// - Online: isOnline = true
    /// - Recently offline: offline but within last 15 minutes
    /// - Offline: offline for more than 15 minutes
    var presenceStatus: PresenceStatus {
        if isOnline {
            return .online
        }
        
        let fifteenMinutesAgo = Date().addingTimeInterval(-15 * 60)
        if lastSeen > fifteenMinutesAgo {
            return .recentlyOffline
        }
        
        return .offline
    }
    
    init(
        id: String,
        email: String,
        displayName: String,
        profileImageURL: String? = nil,
        isOnline: Bool = false,
        lastSeen: Date = Date(),
        createdAt: Date = Date(),
        fcmToken: String? = nil,
        fcmTokenUpdatedAt: Date? = nil,
        currentConversationId: String? = nil,
        timezone: String? = nil,
        locale: String? = nil,
        preferredLanguage: String? = nil,
        googleCalendarConnected: Bool = false,
        googleCalendarRefreshToken: String? = nil,
        googleCalendarEmail: String? = nil,
        googleCalendarConnectedAt: Date? = nil,
        schemaVersion: Int = 1
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.profileImageURL = profileImageURL
        self.isOnline = isOnline
        self.lastSeen = lastSeen
        self.createdAt = createdAt
        self.fcmToken = fcmToken
        self.fcmTokenUpdatedAt = fcmTokenUpdatedAt
        self.currentConversationId = currentConversationId
        self.timezone = timezone
        self.locale = locale
        self.preferredLanguage = preferredLanguage
        self.googleCalendarConnected = googleCalendarConnected
        self.googleCalendarRefreshToken = googleCalendarRefreshToken
        self.googleCalendarEmail = googleCalendarEmail
        self.googleCalendarConnectedAt = googleCalendarConnectedAt
        self.schemaVersion = schemaVersion
    }

    // MARK: - Decodable

    /// Custom decoder to handle backward compatibility with old Firestore documents
    /// Provides default values for fields that didn't exist in earlier schema versions
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Required fields
        id = try container.decode(String.self, forKey: .id)
        email = try container.decode(String.self, forKey: .email)
        displayName = try container.decode(String.self, forKey: .displayName)
        isOnline = try container.decode(Bool.self, forKey: .isOnline)
        lastSeen = try container.decode(Date.self, forKey: .lastSeen)
        createdAt = try container.decode(Date.self, forKey: .createdAt)

        // Optional fields
        profileImageURL = try container.decodeIfPresent(String.self, forKey: .profileImageURL)
        fcmToken = try container.decodeIfPresent(String.self, forKey: .fcmToken)
        fcmTokenUpdatedAt = try container.decodeIfPresent(Date.self, forKey: .fcmTokenUpdatedAt)
        currentConversationId = try container.decodeIfPresent(String.self, forKey: .currentConversationId)
        timezone = try container.decodeIfPresent(String.self, forKey: .timezone)
        locale = try container.decodeIfPresent(String.self, forKey: .locale)
        preferredLanguage = try container.decodeIfPresent(String.self, forKey: .preferredLanguage)
        googleCalendarRefreshToken = try container.decodeIfPresent(String.self, forKey: .googleCalendarRefreshToken)
        googleCalendarEmail = try container.decodeIfPresent(String.self, forKey: .googleCalendarEmail)
        googleCalendarConnectedAt = try container.decodeIfPresent(Date.self, forKey: .googleCalendarConnectedAt)

        // Fields with defaults (backward compatibility)
        googleCalendarConnected = try container.decodeIfPresent(Bool.self, forKey: .googleCalendarConnected) ?? false
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
    }
}

