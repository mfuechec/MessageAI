import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import OpenAI from "openai";
import {verifyConversationParticipant} from "./utils/security";
import {generateCacheKey, storeInCache} from "./utils/cache";
import {checkRateLimit} from "./utils/rateLimiting";

// Initialize OpenAI with API key from environment
const openai = new OpenAI({
  apiKey: functions.config().openai?.api_key || process.env.OPENAI_API_KEY,
});

interface Message {
  senderId: string;
  text: string;
  timestamp: any;
}

interface SmartReplyRequest {
  conversationId: string;
  messageId: string;
  recentMessages: Message[];
}

/**
 * Cloud Function: Generate Smart Replies
 *
 * Generates AI-powered quick response suggestions for the latest message
 * in a conversation. Uses smart caching to minimize API calls and costs.
 *
 * Input: { conversationId: string, messageId: string, recentMessages: Message[] }
 * Output: { success: boolean, suggestions: string[], cached: boolean, timestamp: string }
 */
export const generateSmartReplies = functions
  .runWith({
    timeoutSeconds: 30,
    memory: "256MB",
  })
  .https.onCall(async (data: SmartReplyRequest, context) => {
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

      if (!data.messageId || typeof data.messageId !== "string") {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "messageId must be a non-empty string"
        );
      }

      if (!data.recentMessages || !Array.isArray(data.recentMessages)) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "recentMessages must be an array"
        );
      }

      const conversationId = data.conversationId;
      const messageId = data.messageId;
      const recentMessages = data.recentMessages;

      console.log(
        `[generateSmartReplies] User ${userId} requesting smart replies for message ${messageId}`
      );

      // ========================================
      // 3. RATE LIMITING
      // ========================================
      // Allow higher rate limit for smart replies (500/day vs 100 for summaries)
      await checkRateLimit(userId, "smart_reply", 500);

      // ========================================
      // 4. SECURITY CHECK (Participant Verification)
      // ========================================
      await verifyConversationParticipant(userId, conversationId);

      // ========================================
      // 5. SMART CACHE LOOKUP
      // ========================================
      // Cache key based on the specific message ID
      const cacheKey = generateCacheKey("smart_reply", messageId, "v1");

      const cacheDoc = await admin.firestore()
        .collection("ai_cache")
        .doc(cacheKey)
        .get();

      if (cacheDoc.exists) {
        const cacheData = cacheDoc.data();

        // Check if cache has expired (7 days for smart replies)
        const expiresAt = cacheData?.expiresAt;
        const isExpired = expiresAt && (
          expiresAt.toDate ? expiresAt.toDate() : new Date(expiresAt)
        ) < new Date();

        if (!isExpired) {
          // Cache hit - return immediately
          console.log(`[generateSmartReplies] Returning cached suggestions (< 200ms)`);
          const cachedResult = JSON.parse(cacheData!.result);

          return {
            success: true,
            suggestions: cachedResult.suggestions || [],
            cached: true,
            timestamp: new Date().toISOString(),
          };
        } else {
          console.log(`[generateSmartReplies] Cache expired - regenerating`);
        }
      } else {
        console.log(`[generateSmartReplies] No cache found - generating new suggestions`);
      }

      // ========================================
      // 6. PREPARE CONVERSATION CONTEXT
      // ========================================
      // Build conversation context from recent messages
      const conversationContext = recentMessages
        .map((msg) => {
          const role = msg.senderId === userId ? "You" : "Them";
          return `${role}: ${msg.text}`;
        })
        .join("\n");

      console.log(`[generateSmartReplies] Context: ${recentMessages.length} messages`);

      // ========================================
      // 7. OPENAI API CALL
      // ========================================
      let suggestions: string[];

      try {
        const completion = await openai.chat.completions.create({
          model: "gpt-3.5-turbo", // Fast and cheap model for quick responses
          temperature: 0.5, // Lower for more consistent/faster responses
          max_tokens: 100, // Reduced for faster generation
          messages: [
            {
              role: "system",
              content: `You are a smart reply generator. Generate 3 short, natural response suggestions.

Rules:
- Keep under 40 characters each
- Conversational and natural
- Vary tone (enthusiastic, neutral, questioning)
- NO greetings - only contextual responses
- Return ONLY valid JSON: {"suggestions": ["reply1", "reply2", "reply3"]}`,
            },
            {
              role: "user",
              content: `Conversation:\n${conversationContext}\n\nGenerate 3 smart replies.`,
            },
          ],
          response_format: {type: "json_object"},
        });

        const responseText = completion.choices[0]?.message?.content || "{}";

        console.log("[generateSmartReplies] OpenAI Response:", responseText);
        console.log("[generateSmartReplies] Tokens used:", completion.usage?.total_tokens);

        // Parse response
        const parsedResponse = JSON.parse(responseText);
        suggestions = parsedResponse.suggestions || [];

        // Validate we have 3 suggestions
        if (suggestions.length !== 3) {
          console.warn(`[generateSmartReplies] Expected 3 suggestions, got ${suggestions.length}`);
          // Pad with generic fallbacks if needed
          while (suggestions.length < 3) {
            const fallbacks = ["Thanks!", "Got it", "👍", "Sounds good", "Let me check"];
            suggestions.push(fallbacks[suggestions.length % fallbacks.length]);
          }
        }

        console.log(`[generateSmartReplies] Generated ${suggestions.length} suggestions`);
      } catch (openaiError: any) {
        console.error("[generateSmartReplies] OpenAI API error:", openaiError);

        // Handle specific OpenAI errors
        if (openaiError.status === 429) {
          // Rate limit - return generic fallback suggestions
          console.log("[generateSmartReplies] Rate limit hit - using fallback");
          suggestions = ["Thanks!", "Got it", "👍"];
        } else if (openaiError.status === 401) {
          throw new functions.https.HttpsError(
            "internal",
            "AI service configuration error. Please contact support."
          );
        } else {
          // Generic error - return fallback suggestions
          console.log("[generateSmartReplies] Error - using fallback");
          suggestions = ["Thanks!", "Got it", "👍"];
        }
      }

      // ========================================
      // 8. STORE RESULT IN CACHE
      // ========================================
      const result = {suggestions};

      await storeInCache(
        cacheKey,
        result,
        "smart_reply",
        messageId,
        recentMessages.length,
        24 * 7 // 7 days expiration for smart replies
      );

      console.log(`[generateSmartReplies] Stored in cache: ${cacheKey}`);

      // ========================================
      // 9. RETURN RESPONSE
      // ========================================
      return {
        success: true,
        suggestions,
        cached: false,
        timestamp: new Date().toISOString(),
      };
    } catch (error: any) {
      console.error("[generateSmartReplies] Error:", error);

      // Re-throw HttpsErrors (already formatted)
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }

      // Wrap other errors
      throw new functions.https.HttpsError(
        "internal",
        `Failed to generate smart replies: ${error.message}`
      );
    }
  });
