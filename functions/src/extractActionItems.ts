import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import {verifyConversationParticipant} from "./utils/security";
import {generateCacheKey, lookupCache, storeInCache} from "./utils/cache";

/**
 * Cloud Function: Extract Action Items
 *
 * Extracts action items from a conversation using AI.
 * In Story 3.1, this returns placeholder data. Real OpenAI integration in Story 3.5.
 *
 * Input: { conversationId: string, messageIds?: string[] }
 * Output: { success: boolean, actionItems: ActionItem[], cached: boolean, timestamp: string }
 */
export const extractActionItems = functions
  .runWith({
    timeoutSeconds: 60,
    memory: "512MB",
  })
  .https.onCall(async (data, context) => {
    try {
      // ========================================
      // 1. AUTHENTICATION CHECK
      // ========================================
      if (!context.auth) {
        throw new functions.https.HttpsError(
          "unauthenticated",
          "User must be authenticated"
        );
      }

      const userId = context.auth.uid;

      // ========================================
      // 2. INPUT VALIDATION
      // ========================================
      if (!data.conversationId || typeof data.conversationId !== "string") {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "conversationId must be a non-empty string"
        );
      }

      if (data.messageIds && !Array.isArray(data.messageIds)) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "messageIds must be an array"
        );
      }

      const conversationId = data.conversationId;
      const messageIds = data.messageIds as string[] | undefined;

      console.log(
        `[extractActionItems] User ${userId} requesting action items for conversation ${conversationId}`,
        messageIds ? `with ${messageIds.length} specific messages` : "for all messages"
      );

      // ========================================
      // 3. SECURITY CHECK (Participant Verification)
      // ========================================
      await verifyConversationParticipant(userId, conversationId);

      // ========================================
      // 4. FETCH MESSAGES FROM FIRESTORE
      // ========================================
      let messagesQuery = admin.firestore()
        .collection("messages")
        .where("conversationId", "==", conversationId)
        .where("isDeleted", "==", false)
        .orderBy("timestamp", "desc")
        .limit(100);

      const messagesSnapshot = await messagesQuery.get();

      if (messagesSnapshot.empty) {
        throw new functions.https.HttpsError(
          "not-found",
          "No messages found in this conversation"
        );
      }

      const messages = messagesSnapshot.docs.map((doc) => ({
        id: doc.id,
        ...doc.data(),
      }));

      console.log(`[extractActionItems] Found ${messages.length} messages`);

      // Get latest message ID for cache key
      const latestMessageId = messages[0].id as string;

      // ========================================
      // 5. CACHE LOOKUP
      // ========================================
      const cacheKey = generateCacheKey("actionItems", conversationId, latestMessageId);
      const cachedResult = await lookupCache(cacheKey);

      if (cachedResult) {
        console.log(`[extractActionItems] Returning cached action items`);
        return {
          success: true,
          actionItems: cachedResult.actionItems,
          cached: true,
          timestamp: new Date().toISOString(),
        };
      }

      // ========================================
      // 6. AI API CALL (PLACEHOLDER for Story 3.1)
      // ========================================
      // In Story 3.5, this will use OpenAI Function Calling for structured output

      // Fetch user names for placeholder assignees
      const sampleUsers = await admin.firestore()
        .collection("users")
        .limit(3)
        .get();

      const userIds = sampleUsers.docs.map((doc) => doc.id);
      const userNames = sampleUsers.docs.map(
        (doc) => doc.data().displayName || "Unknown User"
      );

      // MOCK RESPONSE - Replace with actual OpenAI Function Calling in Story 3.5
      const mockActionItems = [
        {
          task: "Placeholder action item 1: Review infrastructure setup",
          assignee: userNames[0] || "Unassigned",
          assigneeId: userIds[0] || null,
          deadline: null,
          sourceMessageId: messages[0]?.id || "msg-1",
          priority: "medium",
        },
        {
          task: "Placeholder action item 2: Test Cloud Functions integration",
          assignee: userNames[1] || "Unassigned",
          assigneeId: userIds[1] || null,
          deadline: null,
          sourceMessageId: messages[1]?.id || "msg-2",
          priority: "high",
        },
        {
          task: "Placeholder action item 3: Prepare for Story 3.5 implementation",
          assignee: "Unassigned",
          assigneeId: null,
          deadline: null,
          sourceMessageId: messages[2]?.id || "msg-3",
          priority: "low",
        },
      ];

      console.log(`[extractActionItems] Generated ${mockActionItems.length} placeholder action items`);

      // ========================================
      // 7. STORE RESULT IN CACHE
      // ========================================
      const resultToCache = {
        actionItems: mockActionItems,
      };

      await storeInCache(
        cacheKey,
        resultToCache,
        "actionItems",
        conversationId,
        messages.length,
        24 // 24 hours expiration
      );

      // ========================================
      // 8. RETURN STRUCTURED RESPONSE
      // ========================================
      return {
        success: true,
        actionItems: mockActionItems,
        cached: false,
        timestamp: new Date().toISOString(),
      };
    } catch (error: any) {
      // ========================================
      // ERROR HANDLING
      // ========================================
      console.error("[extractActionItems] Error:", error);

      // Re-throw HttpsErrors (already formatted)
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }

      // Wrap other errors
      throw new functions.https.HttpsError(
        "internal",
        `Failed to extract action items: ${error.message}`
      );
    }
  });
