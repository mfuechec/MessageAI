import Foundation

/// Core domain entity representing a chat conversation (1-on-1 or group)
struct Conversation: Codable, Equatable, Identifiable {
    let id: String
    var participantIds: [String]
    var lastMessage: String?
    var lastMessageTimestamp: Date?
    var lastMessageSenderId: String?
    var lastMessageId: String?
    var unreadCounts: [String: Int]
    var typingUsers: [String]
    let createdAt: Date
    var isGroup: Bool
    var groupName: String?
    var lastAISummaryAt: Date?
    var hasUnreadPriority: Bool
    var priorityCount: Int
    var activeSchedulingDetected: Bool
    var schedulingDetectedAt: Date?
    var isMuted: Bool
    var mutedUntil: Date?
    var isArchived: Bool
    var archivedAt: Date?
    let schemaVersion: Int
    
    static let maxParticipants = 10
    
    /// Get unread count for specific user
    /// - Parameter userId: The user ID to check
    /// - Returns: Unread count (0 if not found)
    func unreadCount(for userId: String) -> Int {
        unreadCounts[userId] ?? 0
    }
    
    /// Check if conversation can accept more participants
    /// - Returns: True if under max participant limit
    func canAddParticipant() -> Bool {
        participantIds.count < Self.maxParticipants
    }
    
    /// Get display name for conversation
    /// - Parameters:
    ///   - currentUserId: The current user viewing the conversation
    ///   - users: Array of User objects for participants
    /// - Returns: Display name (group name or other participant's name)
    func displayName(for currentUserId: String, users: [User]) -> String {
        if isGroup {
            return groupName ?? participantNames(currentUserId: currentUserId, users: users)
        } else {
            return otherParticipantName(currentUserId: currentUserId, users: users)
        }
    }
    
    private func participantNames(currentUserId: String, users: [User]) -> String {
        // Exclude current user from group display name
        let otherUsers = users.filter { $0.id != currentUserId }
        return otherUsers.map { $0.truncatedDisplayName }.joined(separator: ", ")
    }
    
    private func otherParticipantName(currentUserId: String, users: [User]) -> String {
        users.first { $0.id != currentUserId }?.truncatedDisplayName ?? "Unknown"
    }
    
    init(
        id: String = UUID().uuidString,
        participantIds: [String],
        lastMessage: String? = nil,
        lastMessageTimestamp: Date? = nil,
        lastMessageSenderId: String? = nil,
        lastMessageId: String? = nil,
        unreadCounts: [String: Int] = [:],
        typingUsers: [String] = [],
        createdAt: Date = Date(),
        isGroup: Bool = false,
        groupName: String? = nil,
        lastAISummaryAt: Date? = nil,
        hasUnreadPriority: Bool = false,
        priorityCount: Int = 0,
        activeSchedulingDetected: Bool = false,
        schedulingDetectedAt: Date? = nil,
        isMuted: Bool = false,
        mutedUntil: Date? = nil,
        isArchived: Bool = false,
        archivedAt: Date? = nil,
        schemaVersion: Int = 1
    ) {
        self.id = id
        self.participantIds = participantIds
        self.lastMessage = lastMessage
        self.lastMessageTimestamp = lastMessageTimestamp
        self.lastMessageSenderId = lastMessageSenderId
        self.lastMessageId = lastMessageId
        self.unreadCounts = unreadCounts
        self.typingUsers = typingUsers
        self.createdAt = createdAt
        self.isGroup = isGroup
        self.groupName = groupName
        self.lastAISummaryAt = lastAISummaryAt
        self.hasUnreadPriority = hasUnreadPriority
        self.priorityCount = priorityCount
        self.activeSchedulingDetected = activeSchedulingDetected
        self.schedulingDetectedAt = schedulingDetectedAt
        self.isMuted = isMuted
        self.mutedUntil = mutedUntil
        self.isArchived = isArchived
        self.archivedAt = archivedAt
        self.schemaVersion = schemaVersion
    }
}

