import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import OpenAI from "openai";
import {verifyConversationParticipant} from "./utils/security";
import {generateCacheKey, storeInCache, checkCacheStaleness} from "./utils/cache";
import {checkRateLimit} from "./utils/rateLimiting";

// Initialize OpenAI with API key from environment
const openai = new OpenAI({
  apiKey: functions.config().openai?.api_key || process.env.OPENAI_API_KEY,
});

/**
 * Cloud Function: Summarize Thread (Story 3.5)
 *
 * Generates an AI summary of a conversation thread using OpenAI GPT-4.
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
      const bypassCache = data.bypassCache === true; // Optional parameter to force fresh generation

      console.log(
        `[summarizeThread] User ${userId} requesting summary for conversation ${conversationId}`,
        messageIds ? `with ${messageIds.length} specific messages` : "for all messages",
        bypassCache ? "(bypassing cache)" : ""
      );

      // ========================================
      // 3. RATE LIMITING (Story 3.5)
      // ========================================
      // Check rate limit BEFORE expensive operations to prevent abuse
      await checkRateLimit(userId, "summary", 100);

      // ========================================
      // 4. SECURITY CHECK (Participant Verification)
      // ========================================
      await verifyConversationParticipant(userId, conversationId);

      // ========================================
      // 5. FETCH MESSAGES FROM FIRESTORE
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

      // ========================================
      // 6. SMART CACHE LOOKUP (Story 3.5)
      // ========================================
      // Use conversationId only (not latestMessageId) for cache key
      // This allows us to return slightly stale summaries if acceptable
      const cacheKey = generateCacheKey("summary", conversationId, "v1");

      // Skip cache if bypass requested (e.g., from "Regenerate" button)
      if (bypassCache) {
        console.log(`[summarizeThread] Cache bypass requested - forcing fresh generation`);
      } else {
        // Try to get cached summary
        const cacheDoc = await admin.firestore()
          .collection("ai_cache")
          .doc(cacheKey)
          .get();

        if (cacheDoc.exists) {
        const cacheData = cacheDoc.data();

        // Check if cache has expired (24 hours)
        const expiresAt = cacheData?.expiresAt;
        const isExpired = expiresAt && (
          expiresAt.toDate ? expiresAt.toDate() : new Date(expiresAt)
        ) < new Date();

        if (!isExpired) {
          // Check staleness: Only regenerate if >10 new messages or >24 hours
          const stalenessCheck = checkCacheStaleness(
            cacheData!,
            messages.length,
            10, // Regenerate if 10+ new messages
            24  // Or if 24+ hours old
          );

          if (!stalenessCheck.isStale) {
            // Cache is fresh enough - return it with staleness metadata
            console.log(`[summarizeThread] Returning cached summary (fresh)`);
            const cachedResult = JSON.parse(cacheData!.result);

            return {
              success: true,
              summary: cachedResult.summary,
              keyPoints: cachedResult.keyPoints || [],
              participants: cachedResult.participants || [],
              dateRange: cachedResult.dateRange || "",
              cached: true,
              messagesSinceCache: stalenessCheck.messagesSinceCache,
              timestamp: new Date().toISOString(),
            };
          } else {
            console.log(`[summarizeThread] Cache exists but is stale - regenerating`);
            console.log(`  ${stalenessCheck.messagesSinceCache} new messages since cache`);
            console.log(`  ${stalenessCheck.hoursSinceCache.toFixed(1)} hours since cache`);
          }
        } else {
          console.log(`[summarizeThread] Cache expired - regenerating`);
        }
        } else {
          console.log(`[summarizeThread] No cache found - generating new summary`);
        }
      }

      // ========================================
      // 7. FETCH PARTICIPANT NAMES AND DATE RANGE
      // ========================================
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

      // ========================================
      // 8. PREPARE MESSAGES FOR AI (Story 3.5)
      // ========================================
      // Format messages with sender names for better context
      const formattedMessages = await Promise.all(
        messages.reverse().map(async (msg: any) => {
          const senderDoc = await admin.firestore()
            .collection("users")
            .doc(msg.senderId)
            .get();
          const senderName = senderDoc.data()?.displayName || "Unknown";
          return `${senderName}: ${msg.text}`;
        })
      );

      const conversationText = formattedMessages.join("\n");

      console.log(`[summarizeThread] Prepared ${messages.length} messages for OpenAI`);

      // ========================================
      // 9. OPENAI API CALL (Story 3.5)
      // ========================================
      let aiSummary: {
        summary: string;
        keyPoints: string[];
        participants: string[];
        dateRange: string;
      };

      try {
        const completion = await openai.chat.completions.create({
          model: "gpt-4-turbo-preview",
          temperature: 0.3, // Lower = more deterministic
          max_tokens: 500,
          messages: [
            {
              role: "system",
              content: `You are an AI assistant that summarizes team conversations.
Your summaries should:
- Be 150-300 words
- Capture key decisions and action items
- Highlight important questions or concerns
- Use professional, clear language
- Focus on the "what matters" for remote teams`,
            },
            {
              role: "user",
              content: `Summarize this conversation and extract key points as a JSON object with this exact format:
{
  "summary": "2-3 sentence summary here",
  "keyPoints": ["point 1", "point 2", "point 3"]
}

Conversation:
${conversationText}`,
            },
          ],
        });

        const responseText = completion.choices[0]?.message?.content || "{}";

        // Parse OpenAI's JSON response
        let parsedResponse;
        try {
          // Strip markdown code blocks if present (```json ... ```)
          let cleanedText = responseText.trim();
          if (cleanedText.startsWith("```")) {
            // Remove opening ```json or ```
            cleanedText = cleanedText.replace(/^```(?:json)?\s*\n?/, "");
            // Remove closing ```
            cleanedText = cleanedText.replace(/\n?```\s*$/, "");
          }

          parsedResponse = JSON.parse(cleanedText);
        } catch (parseError) {
          // Fallback if OpenAI doesn't return valid JSON
          console.warn("[summarizeThread] Failed to parse OpenAI response as JSON, using fallback");
          console.warn("[summarizeThread] Raw response:", responseText);
          parsedResponse = {
            summary: responseText.substring(0, 300),
            keyPoints: [],
          };
        }

        aiSummary = {
          summary: parsedResponse.summary || "Summary generated",
          keyPoints: parsedResponse.keyPoints || [],
          participants: participantNames,
          dateRange,
        };

        console.log(`[summarizeThread] OpenAI summary generated successfully`);
      } catch (openaiError: any) {
        console.error("[summarizeThread] OpenAI API error:", openaiError);

        // Handle specific OpenAI errors with user-friendly messages
        if (openaiError.status === 429) {
          throw new functions.https.HttpsError(
            "resource-exhausted",
            "AI service rate limit exceeded. Please try again in a few minutes."
          );
        }

        if (openaiError.status === 401) {
          throw new functions.https.HttpsError(
            "internal",
            "AI service configuration error. Please contact support."
          );
        }

        // Generic AI service error
        throw new functions.https.HttpsError(
          "unavailable",
          "AI service temporarily unavailable. Please try again later."
        );
      }

      // ========================================
      // 10. STORE RESULT IN CACHE
      // ========================================
      await storeInCache(
        cacheKey,
        aiSummary,
        "summary",
        conversationId,
        messages.length,
        24 // 24 hours expiration
      );

      // ========================================
      // 11. RETURN STRUCTURED RESPONSE
      // ========================================
      return {
        success: true,
        summary: aiSummary.summary,
        keyPoints: aiSummary.keyPoints,
        participants: aiSummary.participants,
        dateRange: aiSummary.dateRange,
        cached: false,
        messagesSinceCache: 0, // Fresh summary
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
