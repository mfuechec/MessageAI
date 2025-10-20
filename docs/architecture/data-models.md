# Data Models

Core domain entities representing the business objects shared between iOS app and Firebase backend. These models are defined as pure Swift structs conforming to `Codable`, `Equatable`, and `Identifiable` protocols. All models include schema versioning for future migration support.

## User

**Purpose:** Represents an authenticated user of the MessageAI application. Stores profile information, online presence, and metadata for display in conversations.

**Key Attributes:**
- `id: String` - Unique identifier (matches Firebase Auth UID)
- `email: String` - User's email address (from Firebase Auth)
- `displayName: String` - User's chosen display name (default: email prefix)
- `profileImageURL: String?` - Optional URL to profile picture in Firebase Storage
- `isOnline: Bool` - Current online/offline status
- `lastSeen: Date` - Timestamp of last app activity
- `createdAt: Date` - Account creation timestamp
- `fcmToken: String?` - Firebase Cloud Messaging device token for push notifications
- `timezone: String?` - IANA timezone identifier (e.g., "America/New_York") for scheduling features
- `locale: String?` - Locale identifier (e.g., "en-US") for formatting
- `preferredLanguage: String?` - ISO 639-1 language code for AI summaries
- `schemaVersion: Int` - Model version for data migration (current: 1)

**Swift Interface:**

```swift
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
    let schemaVersion: Int = 1
    
    // Computed property for display
    var displayInitials: String {
        displayName.prefix(2).uppercased()
    }
}
```

**Relationships:**
- One User → Many Conversations (as participant)
- One User → Many Messages (as sender)
- One User → Many ActionItems (as assignee)

---

## Message

**Purpose:** Represents a single message in a conversation. Supports text, image attachments, and tracks delivery/read status. Includes edit history (capped at 10) and AI-generated metadata.

**Key Attributes:**
- `id: String` - Unique message identifier (UUID)
- `conversationId: String` - Parent conversation reference
- `senderId: String` - User ID of sender
- `text: String` - Message content (empty for image-only messages)
- `timestamp: Date` - Message creation time (Firebase server timestamp)
- `status: MessageStatus` - Enum: sending, sent, delivered, read, failed
- `statusUpdatedAt: Date` - Timestamp of last status change (prevents race conditions)
- `attachments: [MessageAttachment]` - Array of images or files
- `editHistory: [MessageEdit]?` - Optional array of previous versions (MAX 10)
- `editCount: Int` - Total number of edits (continues incrementing after 10)
- `isEdited: Bool` - Flag indicating message has been edited
- `isDeleted: Bool` - Flag for unsent messages (shows placeholder)
- `deletedAt: Date?` - When message was deleted
- `deletedBy: String?` - User ID who deleted message
- `readBy: [String]` - Array of user IDs who have read (for 1-on-1 and small groups)
- `readCount: Int` - Count of readers (for large groups, instead of full array)
- `isPriority: Bool` - AI-detected priority flag
- `priorityReason: String?` - AI explanation for priority status
- `schemaVersion: Int` - Model version for data migration (current: 1)

**Swift Interface:**

```swift
enum MessageStatus: String, Codable {
    case sending
    case sent
    case delivered
    case read
    case failed
    
    var sortOrder: Int {
        switch self {
        case .sending: return 0
        case .failed: return 0
        case .sent: return 1
        case .delivered: return 2
        case .read: return 3
        }
    }
    
    func canTransitionTo(_ newStatus: MessageStatus) -> Bool {
        return newStatus.sortOrder >= self.sortOrder
    }
}

struct MessageAttachment: Codable, Equatable {
    let id: String
    let type: AttachmentType
    let url: String
    let thumbnailURL: String?
    let sizeBytes: Int64
    
    enum AttachmentType: String, Codable {
        case image
        case video  // Future
        case file   // Future
    }
}

struct MessageEdit: Codable, Equatable {
    let text: String
    let editedAt: Date
}

struct Message: Codable, Equatable, Identifiable {
    let id: String
    let conversationId: String
    let senderId: String
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
    let schemaVersion: Int = 1
    
    static let maxEditHistory = 10
}
```

**Relationships:**
- Many Messages → One Conversation
- One Message → One User (sender)
- One Message → One Decision (optional, if marked as decision)

---

## Conversation

**Purpose:** Represents a chat conversation between 2+ users. Tracks participants, unread counts, typing status, and last message metadata for conversation list display. Includes AI metadata for Insights dashboard queries.

**Key Attributes:**
- `id: String` - Unique conversation identifier (UUID)
- `participantIds: [String]` - Array of user IDs in conversation (MAX 10)
- `lastMessage: String?` - Preview text of most recent message
- `lastMessageTimestamp: Date?` - Timestamp of last message
- `lastMessageSenderId: String?` - Who sent the last message
- `lastMessageId: String?` - ID of last message (for AI cache validation)
- `unreadCounts: [String: Int]` - Dictionary of userId → unread count
- `typingUsers: [String]` - Array of user IDs currently typing
- `createdAt: Date` - Conversation creation timestamp
- `isGroup: Bool` - True if 3+ participants
- `groupName: String?` - Optional custom group name
- `lastAISummaryAt: Date?` - When conversation was last summarized
- `hasUnreadPriority: Bool` - True if unread priority messages exist
- `priorityCount: Int` - Count of priority messages requiring attention
- `activeSchedulingDetected: Bool` - AI detected scheduling discussion
- `schedulingDetectedAt: Date?` - When scheduling was detected
- `isMuted: Bool` - User muted notifications for this conversation
- `mutedUntil: Date?` - Optional time-based mute expiration
- `isArchived: Bool` - Soft delete (recoverable for 30 days)
- `archivedAt: Date?` - When conversation was archived
- `schemaVersion: Int` - Model version for data migration (current: 1)

**Swift Interface:**

```swift
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
    let schemaVersion: Int = 1
    
    static let maxParticipants = 10
    
    // Computed properties
    func unreadCount(for userId: String) -> Int {
        unreadCounts[userId] ?? 0
    }
    
    func canAddParticipant() -> Bool {
        participantIds.count < Self.maxParticipants
    }
    
    func displayName(for currentUserId: String, users: [User]) -> String {
        if isGroup {
            return groupName ?? participantNames(users: users)
        } else {
            return otherParticipantName(currentUserId: currentUserId, users: users)
        }
    }
    
    private func participantNames(users: [User]) -> String {
        users.map { $0.displayName }.joined(separator: ", ")
    }
    
    private func otherParticipantName(currentUserId: String, users: [User]) -> String {
        users.first { $0.id != currentUserId }?.displayName ?? "Unknown"
    }
}
```

**Relationships:**
- One Conversation → Many Messages
- One Conversation → Many Users (participants)
- One Conversation → Many ActionItems (extracted from messages)
- One Conversation → Many Decisions (made in conversation)

---

## ActionItem

**Purpose:** AI-extracted or manually-tagged task from conversation. Displayed in Insights dashboard. Linked to source message for context.

**Key Attributes:**
- `id: String` - Unique identifier
- `conversationId: String` - Source conversation
- `sourceMessageId: String` - Original message containing action item
- `task: String` - Description of what needs to be done
- `assignee: String?` - Optional user ID of person assigned
- `dueDate: Date?` - Optional detected or manual deadline
- `isCompleted: Bool` - Completion status
- `completedAt: Date?` - When marked complete
- `createdAt: Date` - When action item was extracted/created
- `createdBy: CreationSource` - Enum: aiExtracted, manualTag
- `schemaVersion: Int` - Model version for data migration (current: 1)

**Swift Interface:**

```swift
enum CreationSource: String, Codable {
    case aiExtracted
    case manualTag
}

struct ActionItem: Codable, Equatable, Identifiable {
    let id: String
    let conversationId: String
    let sourceMessageId: String
    var task: String
    var assignee: String?
    var dueDate: Date?
    var isCompleted: Bool
    var completedAt: Date?
    let createdAt: Date
    let createdBy: CreationSource
    let schemaVersion: Int = 1
}
```

**Relationships:**
- One ActionItem → One Message (source)
- One ActionItem → One Conversation
- One ActionItem → One User (assignee)

---

## Decision

**Purpose:** Important decision made in conversation. Tracked for future reference. Displayed in Insights dashboard with searchable text.

**Key Attributes:**
- `id: String` - Unique identifier
- `conversationId: String` - Source conversation
- `sourceMessageId: String` - Message where decision was made
- `summary: String` - Brief description of decision
- `context: String?` - Optional additional context
- `participants: [String]` - User IDs involved in decision
- `tags: [String]` - Optional tags (e.g., "technical", "product")
- `createdAt: Date` - Decision timestamp
- `createdBy: CreationSource` - AI-detected or manually tagged
- `schemaVersion: Int` - Model version for data migration (current: 1)

**Swift Interface:**

```swift
struct Decision: Codable, Equatable, Identifiable {
    let id: String
    let conversationId: String
    let sourceMessageId: String
    var summary: String
    var context: String?
    var participants: [String]
    var tags: [String]
    let createdAt: Date
    let createdBy: CreationSource
    let schemaVersion: Int = 1
}
```

**Relationships:**
- One Decision → One Message (source)
- One Decision → One Conversation
- Many Decisions → Many Users (participants)

---

## AICacheEntry

**Purpose:** Caches AI-generated results (summaries, action items, search results) to minimize redundant LLM calls. Includes expiration and simplified invalidation logic using latest message ID.

**Key Attributes:**
- `id: String` - Unique cache key (hash of feature type + conversation + message range)
- `featureType: AIFeatureType` - Enum: summary, actionItems, search, priority
- `conversationId: String` - Related conversation
- `messageRange: String` - Description of messages (e.g., "latest_100", "msg_1_to_50")
- `messageCount: Int` - Number of messages in cached result
- `latestMessageId: String` - ID of newest message included in cache
- `result: String` - Serialized JSON of AI output
- `createdAt: Date` - Cache entry creation time
- `expiresAt: Date` - Cache expiration (24 hours default)
- `schemaVersion: Int` - Model version for data migration (current: 1)

**Swift Interface:**

```swift
enum AIFeatureType: String, Codable {
    case summary
    case actionItems
    case search
    case priority
    case scheduling
}

struct AICacheEntry: Codable, Equatable, Identifiable {
    let id: String
    let featureType: AIFeatureType
    let conversationId: String
    let messageRange: String
    let messageCount: Int
    let latestMessageId: String
    var result: String  // JSON string to decode based on featureType
    let createdAt: Date
    var expiresAt: Date
    let schemaVersion: Int = 1
    
    var isExpired: Bool {
        Date() > expiresAt
    }
    
    func isValid(for conversation: Conversation) -> Bool {
        // Cache valid if not expired and latest message matches
        return !isExpired && latestMessageId == conversation.lastMessageId
    }
}
```

**Relationships:**
- One AICacheEntry → One Conversation
- Cache entries are ephemeral (automatically purged when expired)

---
