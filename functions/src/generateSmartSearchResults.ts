import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import {
  verifyMultipleConversationAccess,
  getUserConversations,
} from "./utils/security";
import {
  generateCacheKey,
  lookupCache,
  storeInCache,
  simpleHash,
} from "./utils/cache";

/**
 * Cloud Function: Generate Smart Search Results
 *
 * Performs AI-enhanced semantic search across conversations.
 * In Story 3.1, this returns placeholder data. Real OpenAI integration in Story 3.5.
 *
 * Input: { query: string, conversationIds?: string[] }
 * Output: { success: boolean, results: SearchResult[], cached: boolean, timestamp: string }
 */
export const generateSmartSearchResults = functions
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
      if (!data.query || typeof data.query !== "string") {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "query must be a non-empty string"
        );
      }

      if (data.query.length > 200) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "query must be 200 characters or less"
        );
      }

      if (data.conversationIds && !Array.isArray(data.conversationIds)) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "conversationIds must be an array"
        );
      }

      const query = data.query.trim();
      let conversationIds = data.conversationIds as string[] | undefined;

      console.log(
        `[generateSmartSearchResults] User ${userId} searching for: "${query}"`
      );

      // ========================================
      // 3. SECURITY CHECK (Participant Verification)
      // ========================================
      if (conversationIds && conversationIds.length > 0) {
        // Verify user is participant in all specified conversations
        await verifyMultipleConversationAccess(userId, conversationIds);
      } else {
        // If no conversations specified, search across all user's conversations
        conversationIds = await getUserConversations(userId);
        console.log(
          `[generateSmartSearchResults] Searching across ${conversationIds.length} conversations`
        );
      }

      if (conversationIds.length === 0) {
        // User has no conversations to search
        return {
          success: true,
          results: [],
          cached: false,
          timestamp: new Date().toISOString(),
        };
      }

      // ========================================
      // 4. CACHE LOOKUP
      // ========================================
      const queryHash = simpleHash(query);
      const conversationIdsHash = simpleHash(conversationIds.sort().join(","));
      const cacheKey = generateCacheKey(
        "search",
        conversationIdsHash,
        queryHash
      );

      const cachedResult = await lookupCache(cacheKey);

      if (cachedResult) {
        console.log(`[generateSmartSearchResults] Returning cached search results`);
        return {
          success: true,
          results: cachedResult.results,
          cached: true,
          timestamp: new Date().toISOString(),
        };
      }

      // ========================================
      // 5. FETCH RELEVANT MESSAGES
      // ========================================
      // Fetch recent messages from specified conversations
      const allMessages: any[] = [];

      for (const conversationId of conversationIds.slice(0, 10)) {
        // Limit to 10 conversations
        const messagesSnapshot = await admin.firestore()
          .collection("messages")
          .where("conversationId", "==", conversationId)
          .where("isDeleted", "==", false)
          .orderBy("timestamp", "desc")
          .limit(20) // Limit messages per conversation
          .get();

        const messages = messagesSnapshot.docs.map((doc) => ({
          id: doc.id,
          conversationId,
          ...doc.data(),
        }));

        allMessages.push(...messages);
      }

      console.log(
        `[generateSmartSearchResults] Found ${allMessages.length} messages to search`
      );

      if (allMessages.length === 0) {
        return {
          success: true,
          results: [],
          cached: false,
          timestamp: new Date().toISOString(),
        };
      }

      // ========================================
      // 6. AI API CALL (PLACEHOLDER for Story 3.1)
      // ========================================
      // In Story 3.5, this will use OpenAI to semantically rank messages

      // MOCK RESPONSE - Replace with actual OpenAI semantic search in Story 3.5
      // For now, just return the first few messages as "relevant"
      const mockSearchResults = allMessages.slice(0, 3).map((msg, index) => ({
        messageId: msg.id,
        conversationId: msg.conversationId,
        snippet: msg.text ?
          msg.text.substring(0, 150) + (msg.text.length > 150 ? "..." : "") :
          "[Media]",
        relevanceScore: 0.95 - (index * 0.1), // Decreasing relevance
        timestamp: msg.timestamp,
        senderName: "Placeholder User", // Would fetch from users collection
      }));

      console.log(
        `[generateSmartSearchResults] Generated ${mockSearchResults.length} placeholder results`
      );

      // ========================================
      // 7. STORE RESULT IN CACHE
      // ========================================
      const resultToCache = {
        results: mockSearchResults,
      };

      await storeInCache(
        cacheKey,
        resultToCache,
        "search",
        conversationIdsHash,
        allMessages.length,
        0.0833 // 5 minutes expiration (1/12 of an hour)
      );

      // ========================================
      // 8. RETURN STRUCTURED RESPONSE
      // ========================================
      return {
        success: true,
        results: mockSearchResults,
        cached: false,
        timestamp: new Date().toISOString(),
      };
    } catch (error: any) {
      // ========================================
      // ERROR HANDLING
      // ========================================
      console.error("[generateSmartSearchResults] Error:", error);

      // Re-throw HttpsErrors (already formatted)
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }

      // Wrap other errors
      throw new functions.https.HttpsError(
        "internal",
        `Failed to generate search results: ${error.message}`
      );
    }
  });
