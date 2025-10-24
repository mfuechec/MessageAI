import {NotificationDecision, NotificationPreferences} from "../types/NotificationPreferences";

/**
 * Fallback Notification Logic
 *
 * Story 6.3: AI Notification Analysis Cloud Function
 *
 * Simple heuristics-based notification decision when AI is unavailable
 * (rate limits, timeouts, errors, etc.)
 */

interface Message {
  text: string;
  senderId: string;
  senderName: string;
  timestamp: Date;
}

/**
 * Apply fallback heuristics to decide if user should be notified
 *
 * Rules:
 * 1. Direct mention (@username) → notify (high priority)
 * 2. Priority keyword → notify (medium priority)
 * 3. Direct question (ends with "?") → notify (medium priority)
 * 4. Otherwise → don't notify
 *
 * @param messages - Array of unread messages
 * @param userId - User ID
 * @param userName - User display name
 * @param preferences - User notification preferences
 * @returns NotificationDecision
 */
export function fallbackNotificationDecision(
  messages: Message[],
  userId: string,
  userName: string,
  preferences: NotificationPreferences
): NotificationDecision {
  console.log(`[Fallback] Applying heuristics for user ${userId}`);
  console.log(`[Fallback] Total unread messages: ${messages.length}`);

  if (messages.length === 0) {
    return {
      shouldNotify: false,
      reason: "No unread messages (fallback heuristic)",
      notificationText: "",
      priority: "low",
    };
  }

  // Only analyze the NEWEST message (first in array since ordered DESC)
  // We should only trigger notifications based on new messages, not old unread ones
  const newestMessage = messages[0];
  console.log(`[Fallback] Analyzing only the newest message: "${newestMessage.text.substring(0, 50)}..."`);

  // Check for direct mention
  const text = newestMessage.text.toLowerCase();
  if (text.includes(`@${userId.toLowerCase()}`) ||
      text.includes(`@${userName.toLowerCase()}`)) {
    const notificationText = truncateText(
      `${newestMessage.senderName}: ${newestMessage.text}`,
      100
    );

    return {
      shouldNotify: true,
      reason: "User directly mentioned (fallback heuristic)",
      notificationText,
      priority: "high",
    };
  }

  // Check for priority keywords
  const keywords = preferences.priorityKeywords.map(k => k.toLowerCase());
  for (const keyword of keywords) {
    if (text.includes(keyword)) {
      const notificationText = truncateText(
        `${newestMessage.senderName}: ${newestMessage.text}`,
        100
      );

      return {
        shouldNotify: true,
        reason: `Priority keyword detected: "${keyword}" (fallback heuristic)`,
        notificationText,
        priority: "medium",
      };
    }
  }

  // Check for direct questions
  const questionPatterns = [
    /can you\b/i,
    /could you\b/i,
    /would you\b/i,
    /will you\b/i,
    /\?$/,
  ];

  for (const pattern of questionPatterns) {
    if (pattern.test(newestMessage.text)) {
      const notificationText = truncateText(
        `${newestMessage.senderName}: ${newestMessage.text}`,
        100
      );

      return {
        shouldNotify: true,
        reason: "Direct question detected (fallback heuristic)",
        notificationText,
        priority: "medium",
      };
    }
  }

  // Default: Don't notify
  return {
    shouldNotify: false,
    reason: "No notification triggers found (fallback heuristic)",
    notificationText: "",
    priority: "low",
  };
}

/**
 * Truncate text to max length
 *
 * @param text - Text to truncate
 * @param maxLength - Max length
 * @returns Truncated text
 */
function truncateText(text: string, maxLength: number): string {
  if (text.length <= maxLength) {
    return text;
  }

  return text.substring(0, maxLength - 3) + "...";
}

/**
 * Check if current time is within user's quiet hours
 *
 * @param preferences - User notification preferences
 * @returns true if in quiet hours, false otherwise
 */
export function isInQuietHours(preferences: NotificationPreferences): boolean {
  try {
    // Get current time in user's timezone
    const now = new Date();
    const userTimeString = now.toLocaleString("en-US", {
      timeZone: preferences.timezone,
      hour12: false,
      hour: "2-digit",
      minute: "2-digit",
    });

    // Parse current time in user's timezone (format: "HH:mm")
    const [currentHour, currentMinute] = userTimeString.split(":").map(Number);

    // Parse quiet hours (format: "HH:mm")
    const [startHour, startMinute] = preferences.quietHoursStart.split(":").map(Number);
    const [endHour, endMinute] = preferences.quietHoursEnd.split(":").map(Number);

    const currentMinutes = currentHour * 60 + currentMinute;
    const startMinutes = startHour * 60 + startMinute;
    const endMinutes = endHour * 60 + endMinute;

    console.log(`[isInQuietHours] User timezone: ${preferences.timezone}`);
    console.log(`[isInQuietHours] Current time (user's TZ): ${userTimeString}`);
    console.log(`[isInQuietHours] Quiet hours: ${preferences.quietHoursStart} - ${preferences.quietHoursEnd}`);
    console.log(`[isInQuietHours] In quiet hours: ${currentMinutes >= startMinutes && currentMinutes < endMinutes}`);

    // Handle overnight quiet hours (e.g., 22:00 - 08:00)
    if (startMinutes > endMinutes) {
      const inQuietHours = currentMinutes >= startMinutes || currentMinutes < endMinutes;
      console.log(`[isInQuietHours] Overnight quiet hours - in quiet hours: ${inQuietHours}`);
      return inQuietHours;
    }

    return currentMinutes >= startMinutes && currentMinutes < endMinutes;
  } catch (error) {
    console.error("Error checking quiet hours:", error);
    return false;
  }
}
