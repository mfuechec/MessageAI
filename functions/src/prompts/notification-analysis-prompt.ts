import {NotificationPreferences} from "../types/NotificationPreferences";

/**
 * Notification Analysis Prompt Template
 *
 * Story 6.3: AI Notification Analysis Cloud Function
 */

/**
 * System prompt for GPT-4 notification analysis
 *
 * Story 6.5: Includes learned user preferences for personalization
 */
export const NOTIFICATION_ANALYSIS_SYSTEM_PROMPT = `You are a notification assistant for remote team professionals. Your job is to analyze conversation messages and decide if the user should be notified.

You adapt your notification decisions based on the user's learned preferences from their feedback history.

ALWAYS NOTIFY if:
- User is directly mentioned (@username or by name)
- User is asked a direct question ("Can you...", "Could you...", "Would you...", "Will you...")
- A decision is made that affects the user's work or responsibilities
- There's an urgent/time-sensitive request related to user's projects
- Production issue or blocker is mentioned that affects user
- Someone assigns a task to the user
- A meeting or deadline is mentioned that involves the user

SHOULD NOTIFY if:
- Message contains user's priority keywords (from preferences)
- Message contains user's learned important keywords (from feedback history)
- Discussion is about a topic the user recently participated in
- Important update on a project the user is involved in
- Request for feedback or review that could involve user

NEVER NOTIFY if:
- General team chat that doesn't involve the user
- FYI updates the user isn't responsible for
- Social/casual conversation (jokes, "thanks", "lol", emoji reactions)
- Information already known to user (based on user context)
- Automated messages or bot responses
- User is actively viewing the conversation (indicated by online status)
- Message is about a topic the user has marked as "not helpful" (suppressed topics)

NOTIFICATION TEXT GUIDELINES:
- Be clear and actionable
- Include sender name and key context
- Max 100 characters
- Format: "{Sender}: {key message summary}"
- Examples:
  * "Sarah: Can you review the API design by EOD?"
  * "John mentioned you: Need help with production bug"
  * "Team meeting scheduled for 3pm today"

PRIORITY LEVELS:
- HIGH: Direct mentions, urgent issues, direct questions, production problems
- MEDIUM: Priority keywords, important updates, indirect questions
- LOW: General updates, non-urgent information

RESPOND ONLY WITH JSON in this exact format:
{
  "shouldNotify": true/false,
  "reason": "brief explanation of decision (1-2 sentences)",
  "notificationText": "clear, actionable notification text (max 100 chars)",
  "priority": "high" | "medium" | "low"
}`;

/**
 * Build user prompt with context and messages
 *
 * Story 6.5: Includes learned user profile for personalization
 *
 * @param userContext - Formatted user context string
 * @param conversationMessages - Formatted conversation messages
 * @param preferences - User notification preferences
 * @param userProfile - Optional learned user profile from feedback history
 * @returns Complete user prompt for GPT-4
 */
export function buildNotificationAnalysisUserPrompt(
  userContext: string,
  conversationMessages: string,
  preferences: NotificationPreferences,
  userProfile?: {
    preferredNotificationRate: "high" | "medium" | "low";
    learnedKeywords: string[];
    suppressedTopics: string[];
    accuracy?: number;
  }
): string {
  // Build learned preferences section (Story 6.5)
  let learnedPreferencesSection = "";
  if (userProfile) {
    const rateInstruction = {
      high: "User appreciates frequent notifications. Be more liberal in notification decisions.",
      medium: "User prefers moderate notification frequency. Balance importance vs frequency.",
      low: "User dislikes frequent notifications. Only notify for critical messages.",
    }[userProfile.preferredNotificationRate];

    learnedPreferencesSection = `
Learned User Preferences (from feedback history):
- Notification frequency preference: ${userProfile.preferredNotificationRate}
- ${rateInstruction}
- User finds these topics important: ${userProfile.learnedKeywords.length > 0 ? userProfile.learnedKeywords.join(", ") : "None learned yet"}
- User doesn't want notifications about: ${userProfile.suppressedTopics.length > 0 ? userProfile.suppressedTopics.join(", ") : "None"}
- Historical accuracy: ${userProfile.accuracy ? (userProfile.accuracy * 100).toFixed(0) + "%" : "N/A"}
`;
  }

  return `User Context:
${userContext}

User Preferences:
- AI notifications enabled: ${preferences.enabled}
- Quiet hours: ${preferences.quietHoursStart} - ${preferences.quietHoursEnd} (${preferences.timezone})
- Priority keywords: ${preferences.priorityKeywords.join(", ")}
- Max analyses per hour: ${preferences.maxAnalysesPerHour}
${learnedPreferencesSection}
Current Time: ${new Date().toISOString()}

Conversation Messages (unread for user):
${conversationMessages}

Analyze these messages and decide if the user should be notified.`;
}

/**
 * Format messages for LLM prompt
 *
 * @param messages - Array of message objects
 * @returns Formatted string
 */
export function formatMessagesForPrompt(messages: Array<{
  text: string;
  senderId: string;
  senderName: string;
  timestamp: Date;
}>): string {
  return messages.map(msg => {
    const timestamp = msg.timestamp.toISOString();
    return `[${timestamp}] ${msg.senderName}: ${msg.text}`;
  }).join("\n");
}

/**
 * Validate notification decision response from GPT-4
 *
 * @param response - Response object from GPT-4
 * @returns true if valid, false otherwise
 */
export function validateNotificationDecision(response: any): boolean {
  if (typeof response !== "object" || response === null) {
    return false;
  }

  // Check required fields
  if (typeof response.shouldNotify !== "boolean") {
    return false;
  }

  if (typeof response.reason !== "string") {
    return false;
  }

  if (typeof response.notificationText !== "string") {
    return false;
  }

  if (!["high", "medium", "low"].includes(response.priority)) {
    return false;
  }

  // Check notification text length
  if (response.notificationText.length > 100) {
    console.warn("Notification text exceeds 100 characters, truncating");
    response.notificationText = response.notificationText.substring(0, 97) + "...";
  }

  return true;
}
