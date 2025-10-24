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

            // Also store in Firestore for instant client access (per-user)
            const latestMessageId = messages[0]?.id || "";
            const summaryData = {
              summary: cachedResult.summary,
              keyPoints: cachedResult.keyPoints || [],
              priorityMessages: cachedResult.priorityMessages || [],
              meetings: cachedResult.meetings || [],
              actionItems: cachedResult.actionItems || [],
              decisions: cachedResult.decisions || [],
              participants: cachedResult.participants || [],
              dateRange: cachedResult.dateRange || "",
              generatedAt: cacheData!.generatedAt || admin.firestore.FieldValue.serverTimestamp(),
              lastMessageId: latestMessageId,
              messageCount: messages.length,
              expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
              conversationId: conversationId,
            };

            await admin.firestore()
              .collection("users")
              .doc(userId)
              .collection("conversation_summaries")
              .doc(conversationId)
              .set(summaryData);

            console.log(`[summarizeThread] Updated Firestore with cached summary for user ${userId}`);

            // Update conversation with priority metadata from cache
            const cachedPriorityMessages = cachedResult.priorityMessages || [];
            const hasUnreadPriority = cachedPriorityMessages.length > 0;
            const priorityCount = cachedPriorityMessages.length;

            await admin.firestore()
              .collection("conversations")
              .doc(conversationId)
              .update({
                hasUnreadPriority,
                priorityCount,
              });

            console.log(`[summarizeThread] Updated conversation from cache: hasUnreadPriority=${hasUnreadPriority}, priorityCount=${priorityCount}`);

            return {
              success: true,
              summary: cachedResult.summary,
              keyPoints: cachedResult.keyPoints || [],
              priorityMessages: cachedResult.priorityMessages || [],
              meetings: cachedResult.meetings || [],
              actionItems: cachedResult.actionItems || [],
              decisions: cachedResult.decisions || [],
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
      // Format messages with sender names and IDs for better context
      const formattedMessages = await Promise.all(
        messages.reverse().map(async (msg: any) => {
          const senderDoc = await admin.firestore()
            .collection("users")
            .doc(msg.senderId)
            .get();
          const senderName = senderDoc.data()?.displayName || "Unknown";
          return {
            id: msg.id,
            text: `${senderName}: ${msg.text}`,
          };
        })
      );

      console.log(`[summarizeThread] Prepared ${messages.length} messages for OpenAI`);

      // ========================================
      // 9. OPENAI API CALL (Story 3.5)
      // ========================================
      let aiSummary: {
        summary: string;
        keyPoints: string[];
        priorityMessages: Array<{text: string; sourceMessageId: string; priority: string}>;
        meetings: Array<{topic: string; sourceMessageId: string; type: string; scheduledTime: string | null; durationMinutes: number; urgency: string; participants: string[]}>;
        actionItems: Array<{task: string; assignee: string | null; dueDate: string | null; sourceMessageId: string}>;
        decisions: Array<{decision: string; context: string; sourceMessageId: string}>;
        participants: string[];
        dateRange: string;
      };

      try {
        const completion = await openai.chat.completions.create({
          model: "gpt-4o-mini",
          temperature: 0.3, // Lower = more deterministic
          max_tokens: 800,  // Increased for meetings + priority messages
          messages: [
            {
              role: "system",
              content: `You are an AI assistant that summarizes team conversations.
Your summaries MUST be:
- Exactly 1-2 sentences (20-30 words MAXIMUM)
- Focus ONLY on the most critical point
- Use extremely concise language
- No filler words or unnecessary details

You also identify priority messages that require immediate attention.`,
            },
            {
              role: "user",
              content: `Analyze this conversation and return a JSON object with this exact format:
{
  "summary": "Ultra-concise 1-2 sentence summary (20-30 words)",
  "keyPoints": ["point 1", "point 2", "point 3"],
  "priorityMessages": [
    {
      "text": "Condensed essence of the urgent message (8-12 words max)",
      "messageIndex": 0,
      "priority": "high"
    }
  ],
  "meetings": [
    {
      "topic": "Brief meeting topic (5-10 words)",
      "messageIndex": 0,
      "type": "detected",
      "scheduledTime": null,
      "durationMinutes": 30,
      "urgency": "medium",
      "participants": ["Alice", "Bob"]
    }
  ],
  "actionItems": [
    {
      "task": "Brief description of what needs to be done",
      "assignee": "Person responsible (or null)",
      "dueDate": "When it's due (or null)",
      "messageIndex": 0
    }
  ],
  "decisions": [
    {
      "decision": "What was decided",
      "context": "Why this decision matters",
      "messageIndex": 0
    }
  ]
}

For priorityMessages:
- Include ONLY messages that require IMMEDIATE attention or action
- CONDENSE the message to its ESSENTIAL information only (8-12 words max)
- Remove filler phrases like "we need", "someone should", "I think", "right now"
- Focus on: WHAT is urgent + CONSEQUENCE/IMPACT
- DO NOT include sender name
- Priority levels: "high" (urgent), "medium" (important), "low" (notable)
- Limit to top 3 most critical messages

For meetings:
- Detect mentions of needing to schedule meetings OR already scheduled meetings
- type: "detected" (needs scheduling) or "scheduled" (already scheduled)
- scheduledTime: null for detected needs, ISO date string for scheduled meetings
- topic: Brief description of meeting purpose (5-10 words)
- durationMinutes: Mentioned duration or reasonable default (30, 60, etc.)
- urgency: "high" (urgent need), "medium" (should schedule), "low" (optional)
- participants: Names mentioned in context (from conversation participants)
- Limit to top 3 most relevant meetings

For actionItems:
- Extract explicit tasks, TODOs, or commitments mentioned
- task: What needs to be done (clear and actionable)
- assignee: Who is responsible (null if not mentioned)
- dueDate: When it's due as natural language (e.g., "Friday EOD", "by tomorrow") or null
- Include only concrete action items, not vague suggestions
- Limit to top 5 most important action items

For decisions:
- Identify key decisions or agreements made in the conversation
- decision: What was decided (concise statement)
- context: Brief explanation of why this matters or what problem it solves
- Focus on significant decisions that affect the team or project
- Limit to top 4 most important decisions

Condensing guidelines:
- Keep core problem + business impact
- Remove redundant urgency words
- Use active voice
- Example pattern: "[Problem]. [Consequence]" or "[Action needed] to [avoid consequence]"

Conversation (numbered):
${formattedMessages.map((m, i) => `${i}. ${m.text}`).join("\n")}`,
            },
          ],
        });

        const responseText = completion.choices[0]?.message?.content || "{}";

        console.log("[summarizeThread] ========== OpenAI Response ==========");
        console.log("[summarizeThread] Model used:", completion.model);
        console.log("[summarizeThread] Finish reason:", completion.choices[0]?.finish_reason);
        console.log("[summarizeThread] Tokens used:", completion.usage?.total_tokens, "(prompt:", completion.usage?.prompt_tokens, "completion:", completion.usage?.completion_tokens, ")");
        console.log("[summarizeThread] Response length:", responseText.length, "characters");
        console.log("[summarizeThread] Raw response text:");
        console.log("---START---");
        console.log(responseText);
        console.log("---END---");

        // Parse OpenAI's JSON response
        let parsedResponse;
        try {
          console.log("[summarizeThread] ========== JSON Parsing ==========");

          // Strip markdown code blocks if present (```json ... ```)
          let cleanedText = responseText.trim();
          console.log("[summarizeThread] Step 1: Trimmed, length:", cleanedText.length);

          if (cleanedText.startsWith("```")) {
            console.log("[summarizeThread] Step 2: Detected markdown code block, stripping...");
            // Remove opening ```json or ```
            cleanedText = cleanedText.replace(/^```(?:json)?\s*\n?/, "");
            // Remove closing ```
            cleanedText = cleanedText.replace(/\n?```\s*$/, "");
            console.log("[summarizeThread] Step 2: After stripping markdown, length:", cleanedText.length);
          } else {
            console.log("[summarizeThread] Step 2: No markdown detected, skipping");
          }

          // Remove trailing commas before closing braces/brackets (common GPT error)
          const beforeCommaFix = cleanedText;
          cleanedText = cleanedText.replace(/,(\s*[}\]])/g, "$1");
          if (beforeCommaFix !== cleanedText) {
            console.log("[summarizeThread] Step 3: Removed trailing commas");
          } else {
            console.log("[summarizeThread] Step 3: No trailing commas found");
          }

          console.log("[summarizeThread] Step 4: Final cleaned text (first 200 chars):", cleanedText.substring(0, 200));
          console.log("[summarizeThread] Step 5: Attempting JSON.parse()...");

          parsedResponse = JSON.parse(cleanedText);

          console.log("[summarizeThread] ✅ Step 6: JSON parse SUCCESS!");
          console.log("[summarizeThread] Parsed keys:", Object.keys(parsedResponse).join(", "));
          console.log("[summarizeThread] - summary length:", parsedResponse.summary?.length || 0);
          console.log("[summarizeThread] - keyPoints count:", parsedResponse.keyPoints?.length || 0);
          console.log("[summarizeThread] - priorityMessages count:", parsedResponse.priorityMessages?.length || 0);
          console.log("[summarizeThread] - meetings count:", parsedResponse.meetings?.length || 0);
          console.log("[summarizeThread] Full parsed object:", JSON.stringify(parsedResponse, null, 2));
        } catch (parseError: any) {
          // Fallback if OpenAI doesn't return valid JSON
          console.error("[summarizeThread] ❌ JSON PARSE FAILED!");
          console.error("[summarizeThread] Parse error:", parseError.message);
          console.error("[summarizeThread] Raw response (first 500 chars):", responseText.substring(0, 500));
          console.error("[summarizeThread] This usually means:");
          console.error("  1. OpenAI response was truncated (check max_tokens)");
          console.error("  2. Response has invalid JSON syntax (trailing commas, unescaped quotes)");
          console.error("  3. Response wrapped in unexpected text");
          parsedResponse = {
            summary: responseText.substring(0, 300),
            keyPoints: [],
            priorityMessages: [],
            meetings: [],
            actionItems: [],
            decisions: [],
          };
        }

        // Map priority messages with actual message IDs
        console.log("[summarizeThread] ========== Priority Message Mapping ==========");
        console.log("[summarizeThread] Raw priorityMessages from AI:", parsedResponse.priorityMessages);
        console.log("[summarizeThread] Number of formatted messages:", formattedMessages.length);

        const priorityMessages = (parsedResponse.priorityMessages || [])
          .map((pm: any, idx: number) => {
            const messageIndex = pm.messageIndex;
            console.log(`[summarizeThread] Priority message ${idx}:`, {
              text: pm.text,
              messageIndex,
              priority: pm.priority,
              isValidIndex: messageIndex >= 0 && messageIndex < formattedMessages.length,
            });

            if (messageIndex >= 0 && messageIndex < formattedMessages.length) {
              const mapped = {
                text: pm.text,
                sourceMessageId: formattedMessages[messageIndex].id,  // Consistent with ActionItemDTO
                priority: pm.priority || "medium",
              };
              console.log(`[summarizeThread] Mapped to:`, mapped);
              return mapped;
            }
            console.log(`[summarizeThread] SKIPPED - invalid index ${messageIndex}`);
            return null;
          })
          .filter((pm: any) => pm !== null);

        console.log("[summarizeThread] ========== Final Priority Messages ==========");
        console.log("[summarizeThread] Priority messages after filtering:", JSON.stringify(priorityMessages, null, 2));

        // Map meetings with actual message IDs
        console.log("[summarizeThread] ========== Meeting Mapping ==========");
        console.log("[summarizeThread] Raw meetings from AI:", parsedResponse.meetings);

        const meetings = (parsedResponse.meetings || [])
          .map((meeting: any, idx: number) => {
            const messageIndex = meeting.messageIndex;
            console.log(`[summarizeThread] Meeting ${idx}:`, {
              topic: meeting.topic,
              messageIndex,
              type: meeting.type,
              isValidIndex: messageIndex >= 0 && messageIndex < formattedMessages.length,
            });

            if (messageIndex >= 0 && messageIndex < formattedMessages.length) {
              const mapped = {
                topic: meeting.topic,
                sourceMessageId: formattedMessages[messageIndex].id,
                type: meeting.type || "detected",
                scheduledTime: meeting.scheduledTime,
                durationMinutes: meeting.durationMinutes || 30,
                urgency: meeting.urgency || "medium",
                participants: meeting.participants || [],
              };
              console.log(`[summarizeThread] Mapped to:`, mapped);
              return mapped;
            }
            console.log(`[summarizeThread] SKIPPED - invalid index ${messageIndex}`);
            return null;
          })
          .filter((meeting: any) => meeting !== null);

        console.log("[summarizeThread] ========== Final Meetings ==========");
        console.log("[summarizeThread] Meetings after filtering:", JSON.stringify(meetings, null, 2));

        // Map action items with actual message IDs
        console.log("[summarizeThread] ========== Action Item Mapping ==========");
        console.log("[summarizeThread] Raw actionItems from AI:", parsedResponse.actionItems);

        const actionItems = (parsedResponse.actionItems || [])
          .map((item: any, idx: number) => {
            const messageIndex = item.messageIndex;
            console.log(`[summarizeThread] Action item ${idx}:`, {
              task: item.task,
              messageIndex,
              assignee: item.assignee,
              isValidIndex: messageIndex >= 0 && messageIndex < formattedMessages.length,
            });

            if (messageIndex >= 0 && messageIndex < formattedMessages.length) {
              const mapped = {
                task: item.task,
                assignee: item.assignee || null,
                dueDate: item.dueDate || null,
                sourceMessageId: formattedMessages[messageIndex].id,
              };
              console.log(`[summarizeThread] Mapped to:`, mapped);
              return mapped;
            }
            console.log(`[summarizeThread] SKIPPED - invalid index ${messageIndex}`);
            return null;
          })
          .filter((item: any) => item !== null);

        console.log("[summarizeThread] ========== Final Action Items ==========");
        console.log("[summarizeThread] Action items after filtering:", JSON.stringify(actionItems, null, 2));

        // Map decisions with actual message IDs
        console.log("[summarizeThread] ========== Decision Mapping ==========");
        console.log("[summarizeThread] Raw decisions from AI:", parsedResponse.decisions);

        const decisions = (parsedResponse.decisions || [])
          .map((decision: any, idx: number) => {
            const messageIndex = decision.messageIndex;
            console.log(`[summarizeThread] Decision ${idx}:`, {
              decision: decision.decision,
              messageIndex,
              context: decision.context,
              isValidIndex: messageIndex >= 0 && messageIndex < formattedMessages.length,
            });

            if (messageIndex >= 0 && messageIndex < formattedMessages.length) {
              const mapped = {
                decision: decision.decision,
                context: decision.context || "",
                sourceMessageId: formattedMessages[messageIndex].id,
              };
              console.log(`[summarizeThread] Mapped to:`, mapped);
              return mapped;
            }
            console.log(`[summarizeThread] SKIPPED - invalid index ${messageIndex}`);
            return null;
          })
          .filter((decision: any) => decision !== null);

        console.log("[summarizeThread] ========== Final Decisions ==========");
        console.log("[summarizeThread] Decisions after filtering:", JSON.stringify(decisions, null, 2));

        aiSummary = {
          summary: parsedResponse.summary || "Summary generated",
          keyPoints: parsedResponse.keyPoints || [],
          priorityMessages,
          meetings,
          actionItems,
          decisions,
          participants: participantNames,
          dateRange,
        };

        console.log(`[summarizeThread] OpenAI summary generated successfully`);
        console.log(`[summarizeThread] Found ${priorityMessages.length} priority messages`);
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
      // 10.5. STORE SUMMARY IN FIRESTORE (For instant client loading)
      // ========================================
      // Store summary per-user for personalization and privacy
      const latestMessageId = messages[0]?.id || "";
      const summaryData = {
        summary: aiSummary.summary,
        keyPoints: aiSummary.keyPoints,
        priorityMessages: aiSummary.priorityMessages,
        meetings: aiSummary.meetings,
        actionItems: aiSummary.actionItems,
        decisions: aiSummary.decisions,
        participants: aiSummary.participants,
        dateRange: aiSummary.dateRange,
        generatedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastMessageId: latestMessageId, // For staleness detection
        messageCount: messages.length,   // For staleness detection
        expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000), // 24 hours
        conversationId: conversationId,  // Store conversation ID for reference
      };

      await admin.firestore()
        .collection("users")
        .doc(userId)
        .collection("conversation_summaries")
        .doc(conversationId)
        .set(summaryData);

      console.log(`[summarizeThread] Stored summary in Firestore: users/${userId}/conversation_summaries/${conversationId}`);

      // ========================================
      // 10.6. UPDATE CONVERSATION WITH PRIORITY METADATA
      // ========================================
      // Update conversation document with priority information for conversation list badges
      const hasUnreadPriority = aiSummary.priorityMessages.length > 0;
      const priorityCount = aiSummary.priorityMessages.length;

      await admin.firestore()
        .collection("conversations")
        .doc(conversationId)
        .update({
          hasUnreadPriority,
          priorityCount,
          lastAISummaryAt: admin.firestore.FieldValue.serverTimestamp(),
        });

      console.log(`[summarizeThread] Updated conversation with priority metadata: hasUnreadPriority=${hasUnreadPriority}, priorityCount=${priorityCount}`);

      // ========================================
      // 11. RETURN STRUCTURED RESPONSE
      // ========================================
      const response = {
        success: true,
        summary: aiSummary.summary,
        keyPoints: aiSummary.keyPoints,
        priorityMessages: aiSummary.priorityMessages,
        meetings: aiSummary.meetings,
        actionItems: aiSummary.actionItems,
        decisions: aiSummary.decisions,
        participants: aiSummary.participants,
        dateRange: aiSummary.dateRange,
        cached: false,
        messagesSinceCache: 0, // Fresh summary
        timestamp: new Date().toISOString(),
      };

      console.log("[summarizeThread] ========== Final Response ==========");
      console.log("[summarizeThread] Response priorityMessages:", JSON.stringify(response.priorityMessages, null, 2));
      console.log("[summarizeThread] Response summary:", response.summary.substring(0, 100));

      return response;
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
