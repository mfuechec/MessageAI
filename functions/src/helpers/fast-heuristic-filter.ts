/**
 * Fast Heuristic Filter for Notification Analysis
 *
 * Implements rule-based filtering to skip LLM for obvious cases
 * - DEFINITELY_NOTIFY: Direct mentions, urgent keywords, direct questions
 * - DEFINITELY_SKIP: Social chat, emoji-only, common acknowledgments
 * - NEED_LLM: Ambiguous cases requiring AI judgment
 *
 * Epic 6 - Performance Optimization
 * Target: 70% LLM skip rate, <50ms decision time
 */

export type HeuristicDecision = "DEFINITELY_NOTIFY" | "DEFINITELY_SKIP" | "NEED_LLM";

export interface FastDecisionResult {
  decision: HeuristicDecision;
  reason: string;
  priority?: "high" | "medium" | "low";
}

/**
 * Apply fast heuristics to determine if message needs LLM analysis
 *
 * @param message - Message object with text and metadata
 * @param user - User object with displayName and preferences
 * @returns FastDecisionResult
 */
export function applyFastHeuristics(
  message: { text: string; senderId: string; senderName: string },
  user: { id: string; displayName: string; preferredKeywords?: string[] }
): FastDecisionResult {
  const text = message.text.trim();
  const lowerText = text.toLowerCase();

  // ========================================
  // DEFINITELY_NOTIFY (Tier 1 - Obvious)
  // ========================================

  // 1. Direct @mentions
  if (lowerText.includes(`@${user.displayName.toLowerCase()}`)) {
    return {
      decision: "DEFINITELY_NOTIFY",
      reason: "Direct @mention",
      priority: "high",
    };
  }

  // 2. User's name in message (case-insensitive)
  const namePattern = new RegExp(`\\b${user.displayName}\\b`, "i");
  if (namePattern.test(text)) {
    return {
      decision: "DEFINITELY_NOTIFY",
      reason: "User mentioned by name",
      priority: "high",
    };
  }

  // 3. High-urgency keywords
  const urgentKeywords = /\b(urgent|asap|emergency|critical|blocker|production|p0|priority\s*0)\b/i;
  if (urgentKeywords.test(text)) {
    return {
      decision: "DEFINITELY_NOTIFY",
      reason: "Urgent keyword detected",
      priority: "high",
    };
  }

  // 4. Direct questions to user (looking at previous context would be ideal)
  const directQuestions = /\b(can you|could you|would you|will you|please)\b/i;
  if (directQuestions.test(text) && text.includes("?")) {
    return {
      decision: "DEFINITELY_NOTIFY",
      reason: "Direct question detected",
      priority: "medium",
    };
  }

  // 5. Task assignment patterns
  const taskPatterns = /\b(assigned to|your task|you should|you need to|action item for you)\b/i;
  if (taskPatterns.test(text)) {
    return {
      decision: "DEFINITELY_NOTIFY",
      reason: "Task assignment detected",
      priority: "high",
    };
  }

  // 6. User's custom priority keywords
  if (user.preferredKeywords && user.preferredKeywords.length > 0) {
    const userKeywordPattern = new RegExp(
      `\\b(${user.preferredKeywords.join("|")})\\b`,
      "i"
    );
    if (userKeywordPattern.test(text)) {
      return {
        decision: "DEFINITELY_NOTIFY",
        reason: "User's priority keyword found",
        priority: "medium",
      };
    }
  }

  // ========================================
  // DEFINITELY_SKIP (Tier 1 - Noise)
  // ========================================

  // 1. Empty or very short messages (likely acknowledgments)
  if (text.length < 5) {
    return {
      decision: "DEFINITELY_SKIP",
      reason: "Message too short",
      priority: "low",
    };
  }

  // 2. Common acknowledgments/reactions
  const acknowledgments = /^(ok|okay|k|kk|thanks|thank you|ty|thx|lol|haha|ha|👍|😄|😊|🙏|❤️|nice|cool|sure|yep|yup|nope|got it|sounds good|np|no problem)$/i;
  if (acknowledgments.test(text)) {
    return {
      decision: "DEFINITELY_SKIP",
      reason: "Common acknowledgment/reaction",
      priority: "low",
    };
  }

  // 3. Emoji-only messages
  const emojiPattern = /^[\p{Emoji}\s]+$/u;
  if (emojiPattern.test(text)) {
    return {
      decision: "DEFINITELY_SKIP",
      reason: "Emoji-only message",
      priority: "low",
    };
  }

  // 4. Bot/automated messages
  if (
    message.senderName.toLowerCase().includes("bot") ||
    message.senderName.toLowerCase().includes("notification")
  ) {
    return {
      decision: "DEFINITELY_SKIP",
      reason: "Automated message",
      priority: "low",
    };
  }

  // 5. Out-of-office or away messages
  const autoReplies = /\b(out of office|away from|on vacation|afk|brb|be right back)\b/i;
  if (autoReplies.test(text)) {
    return {
      decision: "DEFINITELY_SKIP",
      reason: "Auto-reply message",
      priority: "low",
    };
  }

  // ========================================
  // NEED_LLM (Tier 2 - Ambiguous)
  // ========================================

  // Everything else requires AI judgment
  return {
    decision: "NEED_LLM",
    reason: "Message requires contextual analysis",
  };
}
