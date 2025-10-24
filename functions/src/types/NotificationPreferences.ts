/**
 * Notification Preferences Types
 *
 * Story 6.2: RAG System for Full User Context
 * Story 6.4: Notification Preferences UI (schema defined here)
 */

/**
 * User's AI notification preferences
 * Stored in Firestore: users/{userId}/ai_notification_preferences
 */
export interface NotificationPreferences {
  enabled: boolean;
  pauseThresholdSeconds: number; // Default: 120
  activeConversationThreshold: number; // Default: 20
  quietHoursStart: string; // "22:00"
  quietHoursEnd: string; // "08:00"
  timezone: string; // "America/Los_Angeles"
  priorityKeywords: string[]; // ["urgent", "ASAP", "production down", "blocker"]
  maxAnalysesPerHour: number; // Default: 10
  fallbackStrategy: "simple_rules" | "notify_all" | "suppress_all";
  createdAt?: FirebaseFirestore.Timestamp;
  updatedAt?: FirebaseFirestore.Timestamp;
}

/**
 * Default notification preferences for new users
 */
export const DEFAULT_NOTIFICATION_PREFERENCES: NotificationPreferences = {
  enabled: true,
  pauseThresholdSeconds: 120,
  activeConversationThreshold: 20,
  quietHoursStart: "22:00",
  quietHoursEnd: "08:00",
  timezone: "America/Los_Angeles",
  priorityKeywords: ["urgent", "ASAP", "production down", "blocker", "emergency"],
  maxAnalysesPerHour: 10,
  fallbackStrategy: "simple_rules",
};

/**
 * Notification decision returned by AI analysis
 */
export interface NotificationDecision {
  shouldNotify: boolean;
  reason: string;
  notificationText: string;
  priority: "high" | "medium" | "low";
}

/**
 * Message embedding stored in Firestore
 * Collection: message_embeddings/{messageId}
 */
export interface MessageEmbedding {
  messageId: string;
  conversationId: string;
  embedding: number[]; // 1536 dimensions for text-embedding-ada-002
  timestamp: FirebaseFirestore.Timestamp;
  participantIds: string[];
  messageText: string; // Store for debugging
}

/**
 * User context for RAG system
 */
export interface UserContext {
  userId: string;
  recentMessages: RecentMessage[];
  conversations: ConversationSummary[];
  preferences: NotificationPreferences;
  semanticContext?: SemanticSearchResult[];
}

/**
 * Recent message in user's context
 */
export interface RecentMessage {
  messageId: string;
  conversationId: string;
  text: string;
  timestamp: Date;
  senderId: string;
  senderName: string;
}

/**
 * Conversation summary for context
 */
export interface ConversationSummary {
  conversationId: string;
  participantIds: string[];
  isGroup: boolean;
  lastMessageTimestamp: Date;
  unreadCount: number;
  groupName?: string;
}

/**
 * Semantic search result
 */
export interface SemanticSearchResult {
  messageId: string;
  text: string;
  similarity: number;
  conversationId: string;
  timestamp: Date;
}

/**
 * Result from indexConversationForRAG
 */
export interface IndexingResult {
  embeddedCount: number;
  reusedCount: number;
  totalTime: number;
}
