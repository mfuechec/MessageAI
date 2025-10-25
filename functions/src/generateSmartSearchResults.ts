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
import {findRelevantMessages} from "./helpers/semantic-search";

/**
 * Cloud Function: Generate Smart Search Results
 *
 * Performs AI-enhanced semantic search across conversations using OpenAI embeddings.
 * Uses pre-computed message embeddings for fast semantic similarity search.
 *
 * Input: { query: string, conversationIds?: string[], limit?: number }
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
      const limit = data.limit || 20; // Default to 20 results
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
      // 5. PERFORM SEMANTIC SEARCH
      // ========================================
      // Use findRelevantMessages to perform semantic search across user's conversations
      // This function:
      // 1. Generates embedding for query using OpenAI
      // 2. Fetches embeddings from user's conversations
      // 3. Calculates cosine similarity
      // 4. Returns top matches sorted by relevance

      console.log(
        `[generateSmartSearchResults] Performing semantic search across user's conversations`
      );

      const semanticResults = await findRelevantMessages(userId, query, limit);

      if (semanticResults.length === 0) {
        console.log(`[generateSmartSearchResults] No results found`);
        return {
          success: true,
          results: [],
          cached: false,
          timestamp: new Date().toISOString(),
        };
      }

      console.log(
        `[generateSmartSearchResults] Found ${semanticResults.length} semantic matches`
      );

      // ========================================
      // 6. FETCH SENDER NAMES
      // ========================================
      // Enrich results with sender display names
      const db = admin.firestore();

      // Fetch messages to get sender info
      const enrichedResults = await Promise.all(
        semanticResults.map(async (result) => {
          try {
            const messageDoc = await db.collection("messages")
              .doc(result.messageId)
              .get();

            if (!messageDoc.exists) {
              // Fallback if message not found
              return {
                messageId: result.messageId,
                conversationId: result.conversationId,
                snippet: result.text.substring(0, 150) +
                  (result.text.length > 150 ? "..." : ""),
                relevanceScore: result.similarity,
                timestamp: result.timestamp,
                senderName: "Unknown",
              };
            }

            const messageData = messageDoc.data()!;
            const senderId = messageData.senderId;

            // Fetch sender display name
            let senderName = "Unknown";
            try {
              const senderDoc = await db.collection("users").doc(senderId).get();
              if (senderDoc.exists) {
                senderName = senderDoc.data()?.displayName || "Unknown";
              }
            } catch (err) {
              console.error(`Error fetching sender ${senderId}:`, err);
            }

            return {
              messageId: result.messageId,
              conversationId: result.conversationId,
              snippet: result.text.substring(0, 150) +
                (result.text.length > 150 ? "..." : ""),
              relevanceScore: result.similarity,
              timestamp: result.timestamp,
              senderName: senderName,
            };
          } catch (error) {
            console.error(`Error enriching result for message ${result.messageId}:`, error);
            // Return partial result
            return {
              messageId: result.messageId,
              conversationId: result.conversationId,
              snippet: result.text.substring(0, 150) +
                (result.text.length > 150 ? "..." : ""),
              relevanceScore: result.similarity,
              timestamp: result.timestamp,
              senderName: "Unknown",
            };
          }
        })
      );

      console.log(
        `[generateSmartSearchResults] Enriched ${enrichedResults.length} results with sender names`
      );

      // ========================================
      // 7. STORE RESULT IN CACHE
      // ========================================
      const resultToCache = {
        results: enrichedResults,
      };

      await storeInCache(
        cacheKey,
        resultToCache,
        "search",
        conversationIdsHash,
        semanticResults.length,
        0.5 // 30 minutes expiration (0.5 hours)
      );

      // ========================================
      // 8. RETURN STRUCTURED RESPONSE
      // ========================================
      return {
        success: true,
        results: enrichedResults,
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
