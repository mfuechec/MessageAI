import Foundation

/// Core domain entity representing an authenticated user
struct User: Codable, Equatable, Identifiable {
    let id: String
    let email: String
    var displayName: String
    var profileImageURL: String?
    var isOnline: Bool
    var lastSeen: Date
    let createdAt: Date
    var fcmToken: String?
    var timezone: String?
    var locale: String?
    var preferredLanguage: String?
    let schemaVersion: Int
    
    /// Computed property for display initials (e.g., "John Doe" → "JD")
    var displayInitials: String {
        let words = displayName.split(separator: " ")
        if words.count >= 2 {
            return String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
        } else {
            return String(displayName.prefix(2)).uppercased()
        }
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
        timezone: String? = nil,
        locale: String? = nil,
        preferredLanguage: String? = nil,
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
        self.timezone = timezone
        self.locale = locale
        self.preferredLanguage = preferredLanguage
        self.schemaVersion = schemaVersion
    }
}

