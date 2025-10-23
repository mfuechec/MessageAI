import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import {verifyConversationParticipant} from "./utils/security";
import {generateCacheKey, lookupCache, storeInCache} from "./utils/cache";

/**
 * Cloud Function: Summarize Thread
 *
 * Generates an AI summary of a conversation thread.
 * In Story 3.1, this returns placeholder data. Real OpenAI integration in Story 3.5.
 *
 * Input: { conversationId: string, messageIds?: string[] }
 * Output: { success: boolean, summary: string, keyPoints: string[], cached: boolean, timestamp: string }
 */
export const summarizeThread = functions
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
        `[summarizeThread] User ${userId} requesting summary for conversation ${conversationId}`,
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

      // If specific message IDs provided, filter to those
      // (This would require a different query approach in production)
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

      console.log(`[summarizeThread] Found ${messages.length} messages`);

      // Get latest message ID for cache key
      const latestMessageId = messages[0].id as string;

      // ========================================
      // 5. CACHE LOOKUP
      // ========================================
      const cacheKey = generateCacheKey("summary", conversationId, latestMessageId);
      const cachedResult = await lookupCache(cacheKey);

      if (cachedResult) {
        console.log(`[summarizeThread] Returning cached summary`);
        return {
          success: true,
          summary: cachedResult.summary,
          keyPoints: cachedResult.keyPoints || [],
          participants: cachedResult.participants || [],
          dateRange: cachedResult.dateRange || "",
          cached: true,
          timestamp: new Date().toISOString(),
        };
      }

      // ========================================
      // 6. AI API CALL (PLACEHOLDER for Story 3.1)
      // ========================================
      // In Story 3.5, this will be replaced with actual OpenAI API call

      // Fetch sender names for participants list
      const participantIds = Array.from(
        new Set(messages.map((m: any) => m.senderId))
      );
      const participantNames = await Promise.all(
        participantIds.map(async (id) => {
          const userDoc = await admin.firestore()
            .collection("users")
            .doc(id)
            .get();
          return userDoc.data()?.displayName || "Unknown User";
        })
      );

      // Calculate date range
      const oldestMessage = messages[messages.length - 1] as any;
      const newestMessage = messages[0] as any;
      const oldestDate = oldestMessage.timestamp?.toDate ?
        oldestMessage.timestamp.toDate() :
        new Date();
      const newestDate = newestMessage.timestamp?.toDate ?
        newestMessage.timestamp.toDate() :
        new Date();

      const dateRange = `${oldestDate.toLocaleDateString()} - ${newestDate.toLocaleDateString()}`;

      // MOCK RESPONSE - Replace with actual OpenAI call in Story 3.5
      const mockSummary = {
        summary: `This is a placeholder summary of the conversation. ` +
          `The conversation includes ${messages.length} messages from ` +
          `${participantNames.join(", ")}. ` +
          `Actual AI integration will be implemented in Story 3.5. ` +
          `This placeholder demonstrates the Cloud Function infrastructure, ` +
          `authentication, caching, and response format.`,
        keyPoints: [
          "Placeholder key point 1: Infrastructure testing",
          "Placeholder key point 2: Authentication working",
          "Placeholder key point 3: Cache system functional",
        ],
        participants: participantNames,
        dateRange,
      };

      console.log(`[summarizeThread] Generated placeholder summary`);

      // ========================================
      // 7. STORE RESULT IN CACHE
      // ========================================
      await storeInCache(
        cacheKey,
        mockSummary,
        "summary",
        conversationId,
        messages.length,
        24 // 24 hours expiration
      );

      // ========================================
      // 8. RETURN STRUCTURED RESPONSE
      // ========================================
      return {
        success: true,
        summary: mockSummary.summary,
        keyPoints: mockSummary.keyPoints,
        participants: mockSummary.participants,
        dateRange: mockSummary.dateRange,
        cached: false,
        timestamp: new Date().toISOString(),
      };
    } catch (error: any) {
      // ========================================
      // ERROR HANDLING
      // ========================================
      console.error("[summarizeThread] Error:", error);

      // Re-throw HttpsErrors (already formatted)
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }

      // Wrap other errors
      throw new functions.https.HttpsError(
        "internal",
        `Failed to generate summary: ${error.message}`
      );
    }
  });
