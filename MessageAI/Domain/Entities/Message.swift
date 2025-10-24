import Foundation

/// Core domain entity representing a chat message
struct Message: Codable, Equatable, Identifiable {
    let id: String
    let conversationId: String
    let senderId: String
    var senderName: String?  // Denormalized for performance (Epic 6 Optimization)
    var text: String
    let timestamp: Date
    var status: MessageStatus
    var statusUpdatedAt: Date
    var attachments: [MessageAttachment]
    var editHistory: [MessageEdit]?
    var editCount: Int
    var isEdited: Bool
    var isDeleted: Bool
    var deletedAt: Date?
    var deletedBy: String?
    var readBy: [String]
    var readCount: Int
    var isPriority: Bool
    var priorityReason: String?
    let schemaVersion: Int
    
    static let maxEditHistory = 10
    
    init(
        id: String = UUID().uuidString,
        conversationId: String,
        senderId: String,
        senderName: String? = nil,
        text: String,
        timestamp: Date = Date(),
        status: MessageStatus = .sending,
        statusUpdatedAt: Date = Date(),
        attachments: [MessageAttachment] = [],
        editHistory: [MessageEdit]? = nil,
        editCount: Int = 0,
        isEdited: Bool = false,
        isDeleted: Bool = false,
        deletedAt: Date? = nil,
        deletedBy: String? = nil,
        readBy: [String] = [],
        readCount: Int = 0,
        isPriority: Bool = false,
        priorityReason: String? = nil,
        schemaVersion: Int = 1
    ) {
        self.id = id
        self.conversationId = conversationId
        self.senderId = senderId
        self.senderName = senderName
        self.text = text
        self.timestamp = timestamp
        self.status = status
        self.statusUpdatedAt = statusUpdatedAt
        self.attachments = attachments
        self.editHistory = editHistory
        self.editCount = editCount
        self.isEdited = isEdited
        self.isDeleted = isDeleted
        self.deletedAt = deletedAt
        self.deletedBy = deletedBy
        self.readBy = readBy
        self.readCount = readCount
        self.isPriority = isPriority
        self.priorityReason = priorityReason
        self.schemaVersion = schemaVersion
    }
}

