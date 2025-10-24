import * as admin from "firebase-admin";
import {
  UserContext,
  RecentMessage,
  ConversationSummary,
  NotificationPreferences,
  DEFAULT_NOTIFICATION_PREFERENCES,
} from "../types/NotificationPreferences";

/**
 * User Context Retrieval for RAG System
 *
 * Story 6.2: RAG System for Full User Context
 */

/**
 * Get user's recent context for AI analysis
 *
 * Retrieves:
 * - User's last 100 messages across all conversations (past 7 days)
 * - Conversations user participates in
 * - Unread counts per conversation
 * - User notification preferences
 *
 * @param userId - User ID
 * @param limit - Max number of recent messages (default: 100)
 * @returns UserContext object
 */
export async function getUserRecentContext(
  userId: string,
  limit: number = 100
): Promise<UserContext> {
  console.log(`[getUserRecentContext] Loading context for user ${userId}`);

  const db = admin.firestore();

  // Check cache first (10-minute TTL)
  const cacheDoc = await db.collection("user_context_cache").doc(userId).get();

  if (cacheDoc.exists) {
    const cacheData = cacheDoc.data();
    if (cacheData && cacheData.expiresAt.toDate() > new Date()) {
      console.log(`[getUserRecentContext] Cache hit for user ${userId}`);
      return cacheData.context as UserContext;
    }
  }

  console.log(`[getUserRecentContext] Cache miss, fetching fresh data`);

  // Fetch user's conversations
  const sevenDaysAgo = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() - 7 * 24 * 60 * 60 * 1000)
  );

  // Query all user's conversations (can't combine array-contains with inequality)
  const conversationsSnapshot = await db.collection("conversations")
    .where("participantIds", "array-contains", userId)
    .get();

  // Filter in code to only include conversations from last 7 days
  const recentConversationDocs = conversationsSnapshot.docs.filter(doc => {
    const convData = doc.data();
    const lastMessageTimestamp = convData.lastMessageTimestamp;

    // Include conversations with recent messages OR no messages yet
    if (!lastMessageTimestamp) {
      return true; // Include new conversations
    }

    return lastMessageTimestamp > sevenDaysAgo;
  });

  const conversationIds = recentConversationDocs.map(doc => doc.id);

  console.log(`[getUserRecentContext] Found ${conversationIds.length} active conversations`);

  // Fetch recent messages from user's conversations
  const recentMessages: RecentMessage[] = [];

  if (conversationIds.length > 0) {
    // Firestore 'in' queries limited to 10 values, so batch if needed
    const batchSize = 10;
    for (let i = 0; i < conversationIds.length; i += batchSize) {
      const batch = conversationIds.slice(i, i + batchSize);

      // Query messages (can't combine 'in' with inequality on different field)
      // Limit to 200 per batch to avoid fetching too many old messages
      const messagesSnapshot = await db.collection("messages")
        .where("conversationId", "in", batch)
        .orderBy("timestamp", "desc")
        .limit(200)
        .get();

      for (const messageDoc of messagesSnapshot.docs) {
        const messageData = messageDoc.data();

        // Filter to last 7 days in code
        if (messageData.timestamp <= sevenDaysAgo) {
          continue;
        }

        // Fetch sender name
        let senderName = "Unknown";
        try {
          const senderDoc = await db.collection("users").doc(messageData.senderId).get();
          senderName = senderDoc.data()?.displayName || "Unknown";
        } catch (error) {
          console.error(`Error fetching sender ${messageData.senderId}:`, error);
        }

        recentMessages.push({
          messageId: messageDoc.id,
          conversationId: messageData.conversationId,
          text: messageData.text || "",
          timestamp: messageData.timestamp.toDate(),
          senderId: messageData.senderId,
          senderName,
        });
      }
    }
  }

  // Sort by timestamp descending and limit
  recentMessages.sort((a, b) => b.timestamp.getTime() - a.timestamp.getTime());
  const limitedMessages = recentMessages.slice(0, limit);

  console.log(`[getUserRecentContext] Found ${limitedMessages.length} recent messages`);

  // Build conversation summaries
  const conversations: ConversationSummary[] = [];

  for (const convDoc of recentConversationDocs) {
    const convData = convDoc.data();

    // Calculate unread count for this user
    const unreadSnapshot = await db.collection("messages")
      .where("conversationId", "==", convDoc.id)
      .get();

    let unreadCount = 0;
    for (const msgDoc of unreadSnapshot.docs) {
      const msgData = msgDoc.data();
      const readBy = msgData.readBy || [];
      if (!readBy.includes(userId)) {
        unreadCount++;
      }
    }

    conversations.push({
      conversationId: convDoc.id,
      participantIds: convData.participantIds || [],
      isGroup: convData.isGroup || false,
      lastMessageTimestamp: convData.lastMessageTimestamp?.toDate() || new Date(),
      unreadCount,
      groupName: convData.groupName || null, // Firestore doesn't allow undefined
    });
  }

  // Load user preferences
  const preferences = await getNotificationPreferences(userId);

  const context: UserContext = {
    userId,
    recentMessages: limitedMessages,
    conversations,
    preferences,
  };

  // Store in cache with 10-minute TTL
  const expiresAt = new Date(Date.now() + 10 * 60 * 1000);
  await db.collection("user_context_cache").doc(userId).set({
    context,
    generatedAt: admin.firestore.FieldValue.serverTimestamp(),
    expiresAt,
  });

  console.log(`[getUserRecentContext] Context cached until ${expiresAt.toISOString()}`);

  return context;
}

/**
 * Get user's notification preferences
 *
 * @param userId - User ID
 * @returns NotificationPreferences
 */
export async function getNotificationPreferences(
  userId: string
): Promise<NotificationPreferences> {
  const db = admin.firestore();

  const prefsDoc = await db.collection("users")
    .doc(userId)
    .collection("ai_notification_preferences")
    .doc("settings")
    .get();

  if (!prefsDoc.exists) {
    console.log(`[getNotificationPreferences] No preferences for user ${userId}, using defaults`);
    return DEFAULT_NOTIFICATION_PREFERENCES;
  }

  const prefsData = prefsDoc.data();
  if (!prefsData) {
    return DEFAULT_NOTIFICATION_PREFERENCES;
  }

  return {
    ...DEFAULT_NOTIFICATION_PREFERENCES,
    ...prefsData,
  } as NotificationPreferences;
}

/**
 * Format user context for LLM prompt
 *
 * @param context - UserContext object
 * @returns Formatted string for LLM
 */
export function formatUserContextForLLM(context: UserContext): string {
  const parts: string[] = [];

  // User ID
  parts.push(`User ID: ${context.userId}`);

  // Recent activity summary
  parts.push(`\nRecent Activity (past 7 days):`);
  parts.push(`- ${context.recentMessages.length} messages across ${context.conversations.length} conversations`);

  // Unread counts
  const totalUnread = context.conversations.reduce((sum, conv) => sum + conv.unreadCount, 0);
  parts.push(`- ${totalUnread} total unread messages`);

  // Active conversations
  if (context.conversations.length > 0) {
    parts.push(`\nActive Conversations:`);
    for (const conv of context.conversations.slice(0, 5)) {
      const convType = conv.isGroup ? `Group: ${conv.groupName || "Unnamed"}` : "Direct";
      parts.push(`- ${convType} (${conv.unreadCount} unread)`);
    }
  }

  // Recent messages sample
  if (context.recentMessages.length > 0) {
    parts.push(`\nRecent Messages (sample):`);
    for (const msg of context.recentMessages.slice(0, 10)) {
      const timestamp = msg.timestamp.toISOString();
      parts.push(`[${timestamp}] ${msg.senderName}: ${msg.text.substring(0, 100)}`);
    }
  }

  // Preferences
  parts.push(`\nUser Preferences:`);
  parts.push(`- AI notifications enabled: ${context.preferences.enabled}`);
  parts.push(`- Quiet hours: ${context.preferences.quietHoursStart} - ${context.preferences.quietHoursEnd} (${context.preferences.timezone})`);
  parts.push(`- Priority keywords: ${context.preferences.priorityKeywords.join(", ")}`);
  parts.push(`- Max analyses per hour: ${context.preferences.maxAnalysesPerHour}`);

  // Semantic context if available
  if (context.semanticContext && context.semanticContext.length > 0) {
    parts.push(`\nRelevant Past Messages (semantic search):`);
    for (const result of context.semanticContext.slice(0, 5)) {
      parts.push(`[Similarity: ${result.similarity.toFixed(2)}] ${result.text.substring(0, 100)}`);
    }
  }

  return parts.join("\n");
}
