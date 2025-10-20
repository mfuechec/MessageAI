# Database Schema

MessageAI uses Cloud Firestore with the following collection structure. Security rules enforce user-level access control.

## Firestore Collections

```
firestore/
├── users/
│   └── {userId}/                          # Document per user
│       ├── id: string
│       ├── email: string
│       ├── displayName: string
│       ├── profileImageURL?: string
│       ├── isOnline: boolean
│       ├── lastSeen: timestamp
│       ├── createdAt: timestamp
│       ├── fcmToken?: string
│       ├── timezone?: string
│       ├── locale?: string
│       ├── preferredLanguage?: string
│       └── schemaVersion: number
│
├── conversations/
│   └── {conversationId}/                  # Document per conversation
│       ├── id: string
│       ├── participantIds: string[]
│       ├── lastMessage?: string
│       ├── lastMessageTimestamp?: timestamp
│       ├── lastMessageSenderId?: string
│       ├── lastMessageId?: string
│       ├── unreadCounts: map<userId, number>
│       ├── typingUsers: string[]
│       ├── createdAt: timestamp
│       ├── isGroup: boolean
│       ├── groupName?: string
│       ├── lastAISummaryAt?: timestamp
│       ├── hasUnreadPriority: boolean
│       ├── priorityCount: number
│       ├── activeSchedulingDetected: boolean
│       ├── schedulingDetectedAt?: timestamp
│       ├── isMuted: boolean
│       ├── mutedUntil?: timestamp
│       ├── isArchived: boolean
│       ├── archivedAt?: timestamp
│       └── schemaVersion: number
│
├── messages/
│   └── {messageId}/                       # Document per message
│       ├── id: string
│       ├── conversationId: string         # [INDEXED]
│       ├── senderId: string
│       ├── text: string
│       ├── timestamp: timestamp           # [INDEXED]
│       ├── status: string (enum)
│       ├── statusUpdatedAt: timestamp
│       ├── attachments: array
│       ├── editHistory?: array
│       ├── editCount: number
│       ├── isEdited: boolean
│       ├── isDeleted: boolean
│       ├── deletedAt?: timestamp
│       ├── deletedBy?: string
│       ├── readBy: string[]
│       ├── readCount: number
│       ├── isPriority: boolean            # [INDEXED]
│       ├── priorityReason?: string
│       └── schemaVersion: number
│
├── actionItems/
│   └── {actionItemId}/                    # Document per action item
│       ├── id: string
│       ├── conversationId: string         # [INDEXED]
│       ├── sourceMessageId: string
│       ├── task: string
│       ├── assignee?: string              # [INDEXED]
│       ├── dueDate?: timestamp
│       ├── isCompleted: boolean           # [INDEXED]
│       ├── completedAt?: timestamp
│       ├── createdAt: timestamp           # [INDEXED]
│       ├── createdBy: string (enum)
│       └── schemaVersion: number
│
├── decisions/
│   └── {decisionId}/                      # Document per decision
│       ├── id: string
│       ├── conversationId: string         # [INDEXED]
│       ├── sourceMessageId: string
│       ├── summary: string
│       ├── context?: string
│       ├── participants: string[]
│       ├── tags: string[]
│       ├── createdAt: timestamp           # [INDEXED]
│       ├── createdBy: string (enum)
│       └── schemaVersion: number
│
└── ai_cache/
    └── {cacheId}/                         # Document per cache entry
        ├── id: string
        ├── featureType: string (enum)     # [INDEXED]
        ├── conversationId: string         # [INDEXED]
        ├── messageRange: string
        ├── messageCount: number
        ├── latestMessageId: string
        ├── result: string (JSON)
        ├── createdAt: timestamp
        ├── expiresAt: timestamp           # [INDEXED - TTL]
        └── schemaVersion: number
```

## Composite Indexes

Required composite indexes for complex queries (defined in `firestore.indexes.json`):

```json
{
  "indexes": [
    {
      "collectionGroup": "messages",
      "fields": [
        { "fieldPath": "conversationId", "order": "ASCENDING" },
        { "fieldPath": "timestamp", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "messages",
      "fields": [
        { "fieldPath": "conversationId", "order": "ASCENDING" },
        { "fieldPath": "isPriority", "order": "ASCENDING" },
        { "fieldPath": "timestamp", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "actionItems",
      "fields": [
        { "fieldPath": "assignee", "order": "ASCENDING" },
        { "fieldPath": "isCompleted", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "actionItems",
      "fields": [
        { "fieldPath": "conversationId", "order": "ASCENDING" },
        { "fieldPath": "isCompleted", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "decisions",
      "fields": [
        { "fieldPath": "conversationId", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "ai_cache",
      "fields": [
        { "fieldPath": "conversationId", "order": "ASCENDING" },
        { "fieldPath": "featureType", "order": "ASCENDING" },
        { "fieldPath": "expiresAt", "order": "ASCENDING" }
      ]
    }
  ]
}
```

## Firestore Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper functions
    function isAuthenticated() {
      return request.auth != null;
    }
    
    function isUser(userId) {
      return isAuthenticated() && request.auth.uid == userId;
    }
    
    function isParticipant(conversationData) {
      return isAuthenticated() && 
             request.auth.uid in conversationData.participantIds;
    }
    
    // Users collection
    match /users/{userId} {
      allow read: if isAuthenticated();
      allow create: if isUser(userId);
      allow update: if isUser(userId);
      allow delete: if false;  // No user deletion from client
    }
    
    // Conversations collection
    match /conversations/{conversationId} {
      allow read: if isParticipant(resource.data);
      allow create: if isAuthenticated() && 
                       request.auth.uid in request.resource.data.participantIds &&
                       request.resource.data.participantIds.size() <= 10;
      allow update: if isParticipant(resource.data);
      allow delete: if false;  // Use isArchived instead
    }
    
    // Messages collection
    match /messages/{messageId} {
      allow read: if isAuthenticated() && 
                     isParticipant(get(/databases/$(database)/documents/conversations/$(resource.data.conversationId)).data);
      allow create: if isAuthenticated() && 
                       request.resource.data.senderId == request.auth.uid;
      allow update: if isAuthenticated() && 
                       resource.data.senderId == request.auth.uid;
      allow delete: if false;  // Use isDeleted flag instead
    }
    
    // Action items collection
    match /actionItems/{itemId} {
      allow read: if isAuthenticated() && 
                     isParticipant(get(/databases/$(database)/documents/conversations/$(resource.data.conversationId)).data);
      allow create, update: if isAuthenticated();
      allow delete: if isAuthenticated();
    }
    
    // Decisions collection  
    match /decisions/{decisionId} {
      allow read: if isAuthenticated() && 
                     isParticipant(get(/databases/$(database)/documents/conversations/$(resource.data.conversationId)).data);
      allow create, update: if isAuthenticated();
      allow delete: if isAuthenticated();
    }
    
    // AI cache collection (managed by Cloud Functions)
    match /ai_cache/{cacheId} {
      allow read: if isAuthenticated();
      allow write: if false;  // Only Cloud Functions write to cache
    }
  }
}
```

## Offline Persistence Configuration

```swift
// Enable offline persistence (iOS AppDelegate)
let settings = FirestoreSettings()
settings.isPersistenceEnabled = true
settings.cacheSizeBytes = FirestoreCacheSizeUnlimited
Firestore.firestore().settings = settings
```

---
