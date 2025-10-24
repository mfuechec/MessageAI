import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import * as crypto from "crypto";
import {analyzeWithGPT4} from "./services/openai-service";
import {getUserRecentContext, formatUserContextForLLM} from "./helpers/user-context";
import {indexRecentMessages} from "./helpers/indexConversationForRAG";
import {findRelevantMessages} from "./helpers/semantic-search";
import {
  NOTIFICATION_ANALYSIS_SYSTEM_PROMPT,
  buildNotificationAnalysisUserPrompt,
  formatMessagesForPrompt,
  validateNotificationDecision,
} from "./prompts/notification-analysis-prompt";
import {fallbackNotificationDecision} from "./helpers/fallback-notification-logic";
import {NotificationDecision} from "./types/NotificationPreferences";

/**
 * Cloud Function: Analyze conversation for notification decision
 *
 * Story 6.3: AI Notification Analysis Cloud Function
 *
 * Uses GPT-4 with RAG context to intelligently decide if user should be notified
 *
 * @param data - { conversationId: string, userId: string }
 * @param context - Firebase Auth context
 * @returns NotificationDecision
 */
export const analyzeForNotification = functions
  .runWith({
    timeoutSeconds: 60,
    memory: "1GB",
  })
  .https.onCall(async (data, context) => {
    const startTime = Date.now();

    // ========================================
    // 1. AUTHENTICATION & VALIDATION
    // ========================================
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated"
      );
    }

    const requestingUserId = context.auth.uid;

    // Validate input
    if (!data.conversationId || typeof data.conversationId !== "string") {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "conversationId must be a non-empty string"
      );
    }

    if (!data.userId || typeof data.userId !== "string") {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "userId must be a non-empty string"
      );
    }

    // Verify requesting user matches userId (or is admin)
    if (requestingUserId !== data.userId) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "You can only analyze notifications for yourself"
      );
    }

    const conversationId = data.conversationId;
    const userId = data.userId;

    console.log(`[analyzeForNotification] Starting analysis for user ${userId}, conversation ${conversationId}`);

    const db = admin.firestore();

    // Verify conversation exists
    const conversationDoc = await db.collection("conversations").doc(conversationId).get();
    if (!conversationDoc.exists) {
      throw new functions.https.HttpsError(
        "not-found",
        `Conversation ${conversationId} not found`
      );
    }

    // Verify user is participant
    const conversationData = conversationDoc.data();
    const participantIds = conversationData?.participantIds || [];

    if (!participantIds.includes(userId)) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "User not a participant in conversation"
      );
    }

    // ========================================
    // 2. FETCH RECENT MESSAGES
    // ========================================
    const fifteenMinutesAgo = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() - 15 * 60 * 1000)
    );

    const messagesSnapshot = await db.collection("messages")
      .where("conversationId", "==", conversationId)
      .where("timestamp", ">", fifteenMinutesAgo)
      .orderBy("timestamp", "desc")
      .limit(30)
      .get();

    // Filter to unread messages for this user
    const unreadMessages = messagesSnapshot.docs.filter(doc => {
      const msgData = doc.data();
      const readBy = msgData.readBy || [];
      return !readBy.includes(userId);
    });

    if (unreadMessages.length === 0) {
      console.log(`[analyzeForNotification] No unread messages for user ${userId}`);
      return {
        shouldNotify: false,
        reason: "No unread messages",
        notificationText: "",
        priority: "low",
      };
    }

    console.log(`[analyzeForNotification] Found ${unreadMessages.length} unread messages`);

    // ========================================
    // 3. CHECK CACHE
    // ========================================
    const unreadMessageIds = unreadMessages.map(doc => doc.id).sort();
    const cacheKey = generateNotificationCacheKey(conversationId, unreadMessageIds);

    const cachedDecision = await checkNotificationCache(cacheKey);
    if (cachedDecision) {
      console.log(`[analyzeForNotification] Cache hit, returning cached decision`);
      return cachedDecision;
    }

    console.log(`[analyzeForNotification] Cache miss, proceeding with analysis`);

    // ========================================
    // 4. LOAD USER CONTEXT (RAG)
    // ========================================
    let userContext;
    try {
      console.log(`[analyzeForNotification] Calling getUserRecentContext for user ${userId}`);
      userContext = await getUserRecentContext(userId);
      console.log(`[analyzeForNotification] ✅ Loaded user context successfully`);
      console.log(`[analyzeForNotification]    - Recent messages: ${userContext.recentMessages.length}`);
      console.log(`[analyzeForNotification]    - Conversations: ${userContext.conversations.length}`);
      console.log(`[analyzeForNotification]    - Preferences enabled: ${userContext.preferences.enabled}`);
    } catch (error: any) {
      console.error("[analyzeForNotification] ❌ Error loading user context:", error);
      console.error("[analyzeForNotification]    Error type:", error.constructor.name);
      console.error("[analyzeForNotification]    Error message:", error.message);
      console.error("[analyzeForNotification]    Error code:", error.code);
      // Continue without context
      userContext = null;
    }

    // Check if notifications enabled
    if (userContext && !userContext.preferences.enabled) {
      console.log(`[analyzeForNotification] Notifications disabled for user`);
      return {
        shouldNotify: false,
        reason: "Notifications disabled",
        notificationText: "",
        priority: "low",
      };
    }

    // ========================================
    // 5. INDEX MESSAGES FOR RAG (LAZY)
    // ========================================
    try {
      const indexingResult = await indexRecentMessages(conversationId, 30);
      console.log(`[analyzeForNotification] Indexed ${indexingResult.embeddedCount} messages`);
    } catch (error) {
      console.error("[analyzeForNotification] Error indexing messages:", error);
      // Continue without embeddings
    }

    // ========================================
    // 6. SEMANTIC SEARCH FOR CONTEXT
    // ========================================
    if (userContext) {
      try {
        // Use first unread message as query
        const firstUnreadText = unreadMessages[0].data().text || "";
        const semanticResults = await findRelevantMessages(userId, firstUnreadText, 5);

        userContext.semanticContext = semanticResults;
        console.log(`[analyzeForNotification] Found ${semanticResults.length} semantically similar messages`);
      } catch (error) {
        console.error("[analyzeForNotification] Error in semantic search:", error);
        // Continue without semantic context
      }
    }

    // ========================================
    // 7. FORMAT MESSAGES FOR LLM
    // ========================================
    const messagesForLLM = await Promise.all(
      unreadMessages.map(async (doc) => {
        const msgData = doc.data();

        // Fetch sender name
        let senderName = "Unknown";
        try {
          const senderDoc = await db.collection("users").doc(msgData.senderId).get();
          senderName = senderDoc.data()?.displayName || "Unknown";
        } catch (error) {
          console.error(`Error fetching sender ${msgData.senderId}:`, error);
        }

        return {
          text: msgData.text || "",
          senderId: msgData.senderId,
          senderName,
          timestamp: msgData.timestamp.toDate(),
        };
      })
    );

    const formattedMessages = formatMessagesForPrompt(messagesForLLM);

    // ========================================
    // 8. LOAD USER PROFILE (Story 6.5)
    // ========================================
    let userProfile: {
      preferredNotificationRate: "high" | "medium" | "low";
      learnedKeywords: string[];
      suppressedTopics: string[];
      accuracy?: number;
    } | undefined;

    try {
      const profileDoc = await db.collection("users")
        .doc(userId)
        .collection("ai_notification_profile")
        .doc("profile")
        .get();

      if (profileDoc.exists) {
        const profileData = profileDoc.data();
        if (profileData) {
          userProfile = {
            preferredNotificationRate: profileData.preferredNotificationRate || "medium",
            learnedKeywords: profileData.learnedKeywords || [],
            suppressedTopics: profileData.suppressedTopics || [],
            accuracy: profileData.accuracy,
          };
          console.log(`[analyzeForNotification] Loaded user profile: ${userProfile.preferredNotificationRate} rate`);
        }
      } else {
        console.log(`[analyzeForNotification] No user profile found - using defaults`);
      }
    } catch (error) {
      console.error("[analyzeForNotification] Error loading user profile:", error);
      // Continue without profile
    }

    // ========================================
    // 9. CALL GPT-4 FOR ANALYSIS
    // ========================================
    let decision: NotificationDecision;

    try {
      console.log(`[analyzeForNotification] 🤖 Starting GPT-4 analysis`);

      if (!userContext) {
        console.error("[analyzeForNotification] ❌ CRITICAL: userContext is null");
        throw new Error("No user context available");
      }

      console.log(`[analyzeForNotification] ✅ User context exists, formatting for LLM`);

      const userContextFormatted = formatUserContextForLLM(userContext);

      const userPrompt = buildNotificationAnalysisUserPrompt(
        userContextFormatted,
        formattedMessages,
        userContext.preferences,
        userProfile  // Story 6.5: Include learned profile
      );

      console.log(`[analyzeForNotification] ✅ Prompts built, calling GPT-4...`);
      console.log(`[analyzeForNotification]    System prompt length: ${NOTIFICATION_ANALYSIS_SYSTEM_PROMPT.length}`);
      console.log(`[analyzeForNotification]    User prompt length: ${userPrompt.length}`);

      const llmResponse = await analyzeWithGPT4(
        NOTIFICATION_ANALYSIS_SYSTEM_PROMPT,
        userPrompt
      );

      console.log(`[analyzeForNotification] ✅ GPT-4 responded, validating...`);

      // Validate response
      if (!validateNotificationDecision(llmResponse)) {
        console.error("[analyzeForNotification] ❌ Invalid GPT-4 response format:", JSON.stringify(llmResponse));
        throw new Error("Invalid response from GPT-4");
      }

      decision = llmResponse as NotificationDecision;

      console.log(`[analyzeForNotification] ✅ GPT-4 DECISION: ${decision.shouldNotify} (priority: ${decision.priority})`);
      console.log(`[analyzeForNotification]    Reason: ${decision.reason}`);
    } catch (error: any) {
      console.error("[analyzeForNotification] ❌❌❌ ERROR IN GPT-4 ANALYSIS:");
      console.error("[analyzeForNotification]    Error type:", error.constructor.name);
      console.error("[analyzeForNotification]    Error message:", error.message);
      console.error("[analyzeForNotification]    Stack trace:", error.stack);

      // Apply fallback heuristics
      console.log(`[analyzeForNotification] ⚠️ FALLING BACK TO HEURISTICS`);

      // Fetch user name
      let userName = "Unknown";
      try {
        const userDoc = await db.collection("users").doc(userId).get();
        userName = userDoc.data()?.displayName || "Unknown";
      } catch (err) {
        console.error("Error fetching user name:", err);
      }

      decision = fallbackNotificationDecision(
        messagesForLLM,
        userId,
        userName,
        userContext?.preferences || {
          enabled: true,
          pauseThresholdSeconds: 120,
          activeConversationThreshold: 20,
          quietHoursStart: "22:00",
          quietHoursEnd: "08:00",
          timezone: "America/Los_Angeles",
          priorityKeywords: ["urgent", "ASAP"],
          maxAnalysesPerHour: 10,
          fallbackStrategy: "simple_rules",
        }
      );
    }

    // ========================================
    // 10. STORE IN CACHE
    // ========================================
    await storeNotificationCache(cacheKey, decision, conversationId, unreadMessageIds);

    // ========================================
    // 11. LOG DECISION
    // ========================================
    await logNotificationDecision(userId, conversationId, decision, unreadMessages);

    // ========================================
    // 12. SEND FCM NOTIFICATION (Story 6.6)
    // ========================================
    if (decision.shouldNotify) {
      try {
        await sendFCMNotification(userId, conversationId, decision, unreadMessages, db);
      } catch (error) {
        console.error("[analyzeForNotification] Error sending FCM notification:", error);
        // Don't fail the request if notification sending fails
      }
    }

    // ========================================
    // 13. RETURN DECISION
    // ========================================
    const totalTime = Date.now() - startTime;
    console.log(`[analyzeForNotification] Completed in ${totalTime}ms`);

    return decision;
  });

/**
 * Generate cache key for notification decision
 *
 * @param conversationId - Conversation ID
 * @param unreadMessageIds - Sorted array of unread message IDs
 * @returns Cache key string
 */
function generateNotificationCacheKey(
  conversationId: string,
  unreadMessageIds: string[]
): string {
  const hash = crypto
    .createHash("sha256")
    .update(unreadMessageIds.join(","))
    .digest("hex")
    .substring(0, 16);

  return `notification_${conversationId}_${hash}`;
}

/**
 * Check notification cache
 *
 * @param cacheKey - Cache key
 * @returns Cached decision or null
 */
async function checkNotificationCache(
  cacheKey: string
): Promise<NotificationDecision | null> {
  const db = admin.firestore();

  const cacheDoc = await db.collection("ai_notification_cache").doc(cacheKey).get();

  if (!cacheDoc.exists) {
    return null;
  }

  const cacheData = cacheDoc.data();
  if (!cacheData) {
    return null;
  }

  // Check expiration (1 hour)
  const expiresAt = cacheData.expiresAt.toDate();
  if (expiresAt < new Date()) {
    console.log(`[Cache] Expired: ${cacheKey}`);
    // Delete expired cache
    await db.collection("ai_notification_cache").doc(cacheKey).delete();
    return null;
  }

  return cacheData.decision as NotificationDecision;
}

/**
 * Store notification decision in cache
 *
 * @param cacheKey - Cache key
 * @param decision - NotificationDecision
 * @param conversationId - Conversation ID
 * @param unreadMessageIds - Array of unread message IDs
 */
async function storeNotificationCache(
  cacheKey: string,
  decision: NotificationDecision,
  conversationId: string,
  unreadMessageIds: string[]
): Promise<void> {
  const db = admin.firestore();

  const expiresAt = new Date(Date.now() + 60 * 60 * 1000); // 1 hour

  await db.collection("ai_notification_cache").doc(cacheKey).set({
    decision,
    conversationId,
    unreadMessageIds,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    expiresAt,
  });

  console.log(`[Cache] Stored: ${cacheKey}, expires: ${expiresAt.toISOString()}`);
}

/**
 * Log notification decision to Firestore
 *
 * Story 6.5: Analytics Logging (AC 26-28)
 *
 * @param userId - User ID
 * @param conversationId - Conversation ID
 * @param decision - Notification decision
 * @param unreadMessages - Unread messages
 */
async function logNotificationDecision(
  userId: string,
  conversationId: string,
  decision: NotificationDecision,
  unreadMessages: admin.firestore.QueryDocumentSnapshot[]
): Promise<void> {
  const db = admin.firestore();

  const logData = {
    userId,
    conversationId,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    decision: decision.shouldNotify,
    priority: decision.priority,
    aiReasoning: decision.reason,
    notificationText: decision.notificationText || "",
    wasDelivered: false, // Will be updated when FCM confirms delivery
    userFeedback: null,
    messageCount: unreadMessages.length,
  };

  await db.collection("notification_decisions").add(logData);
  console.log(`[analyzeForNotification] Logged decision for user ${userId}`);
}

/**
 * Send FCM notification to user
 *
 * Story 6.6: Push Notification Delivery (AC 1-8)
 *
 * @param userId - User ID
 * @param conversationId - Conversation ID
 * @param decision - Notification decision
 * @param unreadMessages - Unread messages
 * @param db - Firestore database instance
 */
async function sendFCMNotification(
  userId: string,
  conversationId: string,
  decision: NotificationDecision,
  unreadMessages: admin.firestore.QueryDocumentSnapshot[],
  db: admin.firestore.Firestore
): Promise<void> {
  console.log(`[sendFCMNotification] Preparing to send notification to user ${userId}`);

  // ========================================
  // 1. CHECK ACTIVE CONVERSATION SUPPRESSION
  // ========================================
  const activityDoc = await db.collection("user_activity").doc(userId).get();
  if (activityDoc.exists) {
    const activityData = activityDoc.data();
    const activeConversationId = activityData?.activeConversationId;
    const activityTimestamp = activityData?.timestamp;

    // Check if activity is recent (within 2 minutes)
    if (activityTimestamp) {
      const twoMinutesAgo = new Date(Date.now() - 2 * 60 * 1000);
      const activityDate = activityTimestamp.toDate();

      if (activityDate > twoMinutesAgo && activeConversationId === conversationId) {
        console.log(`[sendFCMNotification] User actively viewing conversation, suppressing notification`);
        return;
      }
    }
  }

  // ========================================
  // 2. CHECK RATE LIMITING
  // ========================================
  const rateLimitDoc = await db.collection("rate_limits").doc(userId).get();
  if (rateLimitDoc.exists) {
    const rateLimitData = rateLimitDoc.data();
    const count = rateLimitData?.count || 0;
    const resetAt = rateLimitData?.resetAt;

    // Check if rate limit window is still valid
    if (resetAt && resetAt.toDate() > new Date()) {
      // Fetch user preferences for max analyses per hour
      const userPrefsDoc = await db.collection("users")
        .doc(userId)
        .collection("ai_notification_preferences")
        .doc("default")
        .get();

      const maxPerHour = userPrefsDoc.data()?.maxAnalysesPerHour || 10;

      if (count >= maxPerHour) {
        console.log(`[sendFCMNotification] Rate limit exceeded (${count}/${maxPerHour}), suppressing notification`);
        return;
      }
    }
  }

  // Update rate limit counter
  const oneHourFromNow = admin.firestore.Timestamp.fromDate(new Date(Date.now() + 60 * 60 * 1000));
  await db.collection("rate_limits").doc(userId).set({
    count: admin.firestore.FieldValue.increment(1),
    resetAt: oneHourFromNow,
  }, { merge: true });

  // ========================================
  // 3. LOAD USER FCM TOKEN
  // ========================================
  const userDoc = await db.collection("users").doc(userId).get();
  if (!userDoc.exists) {
    console.error(`[sendFCMNotification] User ${userId} not found`);
    return;
  }

  const userData = userDoc.data();
  const fcmToken = userData?.fcmToken;

  if (!fcmToken) {
    console.warn(`[sendFCMNotification] No FCM token for user ${userId}`);
    return;
  }

  // ========================================
  // 4. GET CONVERSATION INFO
  // ========================================
  const conversationDoc = await db.collection("conversations").doc(conversationId).get();
  const conversationData = conversationDoc.data();
  const isGroup = conversationData?.isGroup || false;
  const groupName = conversationData?.groupName || "Group";

  // Get sender info from first unread message
  const firstMessage = unreadMessages[0].data();
  const senderId = firstMessage.senderId;

  let senderName = "Someone";
  try {
    const senderDoc = await db.collection("users").doc(senderId).get();
    senderName = senderDoc.data()?.displayName || "Someone";
  } catch (error) {
    console.error(`Error fetching sender ${senderId}:`, error);
  }

  // ========================================
  // 5. BUILD NOTIFICATION PAYLOAD
  // ========================================
  const title = isGroup ? `${senderName} in ${groupName}` : senderName;
  const body = decision.notificationText || firstMessage.text || "New message";

  // Determine notification presentation options based on priority
  let sound: string | undefined;
  let badge: number | undefined;

  if (decision.priority === "high") {
    sound = "default";
    badge = 1;
  } else if (decision.priority === "medium") {
    sound = undefined; // Silent
    badge = 1;
  } else {
    // Low priority - badge only
    sound = undefined;
    badge = 1;
  }

  const payload: admin.messaging.Message = {
    token: fcmToken,
    notification: decision.priority === "low" ? undefined : {
      title,
      body,
    },
    data: {
      conversationId,
      messageId: unreadMessages[0].id,
      priority: decision.priority,
      type: "smart_notification",
    },
    apns: {
      payload: {
        aps: {
          sound: sound || undefined,
          badge: badge || undefined,
          category: "SMART_NOTIFICATION_CATEGORY", // For interactive actions
          threadId: conversationId, // Group notifications by conversation
        },
      },
    },
  };

  // ========================================
  // 6. SEND NOTIFICATION
  // ========================================
  try {
    const response = await admin.messaging().send(payload);
    console.log(`[sendFCMNotification] Successfully sent notification: ${response}`);

    // Update log to mark as delivered
    const decisionsSnapshot = await db.collection("notification_decisions")
      .where("userId", "==", userId)
      .where("conversationId", "==", conversationId)
      .orderBy("timestamp", "desc")
      .limit(1)
      .get();

    if (!decisionsSnapshot.empty) {
      await decisionsSnapshot.docs[0].ref.update({
        wasDelivered: true,
      });
    }

  } catch (error: any) {
    console.error(`[sendFCMNotification] Error sending notification:`, error);

    // Handle invalid token error
    if (error.code === "messaging/invalid-registration-token" ||
        error.code === "messaging/registration-token-not-registered") {
      console.log(`[sendFCMNotification] Removing invalid FCM token for user ${userId}`);
      await db.collection("users").doc(userId).update({
        fcmToken: admin.firestore.FieldValue.delete(),
      });
    }

    throw error;
  }
}
