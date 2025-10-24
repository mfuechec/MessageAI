import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

/**
 * Cloud Function: Update User Notification Profile
 *
 * Story 6.5: Feedback Loop & Analytics
 *
 * Analyzes user feedback and updates their AI notification profile
 * Runs weekly via Cloud Scheduler (Monday 00:00 UTC)
 *
 * Can also be called manually for a specific user
 *
 * @param data - { userId?: string } (optional, for manual trigger)
 * @param context - Firebase Auth context (for manual calls)
 * @returns Update summary
 */
export const updateUserNotificationProfile = functions
  .runWith({
    timeoutSeconds: 540, // 9 minutes (max for scheduled functions)
    memory: "1GB",
  })
  .https.onCall(async (data, context) => {
    // ========================================
    // 1. AUTHENTICATION (FOR MANUAL CALLS)
    // ========================================
    let userIds: string[] = [];

    if (data && data.userId) {
      // Manual call for specific user
      if (!context?.auth) {
        throw new functions.https.HttpsError(
          "unauthenticated",
          "User must be authenticated"
        );
      }

      // Only allow users to update their own profile
      if (context.auth.uid !== data.userId) {
        throw new functions.https.HttpsError(
          "permission-denied",
          "You can only update your own profile"
        );
      }

      userIds = [data.userId];
      console.log(`[updateUserNotificationProfile] Manual update for user ${data.userId}`);
    } else {
      // Scheduled run - update all users with feedback
      console.log(`[updateUserNotificationProfile] Scheduled run - updating all users`);
      userIds = await getAllUsersWithFeedback();
    }

    if (userIds.length === 0) {
      console.log(`[updateUserNotificationProfile] No users to update`);
      return {
        success: true,
        usersUpdated: 0,
        message: "No users with feedback found",
      };
    }

    const db = admin.firestore();
    let usersUpdated = 0;

    // ========================================
    // 2. PROCESS EACH USER
    // ========================================
    for (const userId of userIds) {
      try {
        await updateSingleUserProfile(userId, db);
        usersUpdated++;
      } catch (error) {
        console.error(`[updateUserNotificationProfile] Error updating user ${userId}:`, error);
        // Continue with next user
      }
    }

    console.log(`[updateUserNotificationProfile] Updated ${usersUpdated} user profiles`);

    return {
      success: true,
      usersUpdated,
      totalUsers: userIds.length,
    };
  });

/**
 * Get all users who have submitted feedback in the last 30 days
 */
async function getAllUsersWithFeedback(): Promise<string[]> {
  const db = admin.firestore();
  const thirtyDaysAgo = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() - 30 * 24 * 60 * 60 * 1000)
  );

  const feedbackSnapshot = await db.collection("notification_feedback")
    .where("timestamp", ">", thirtyDaysAgo)
    .get();

  const userIdsSet = new Set<string>();
  feedbackSnapshot.forEach((doc) => {
    const data = doc.data();
    if (data.userId) {
      userIdsSet.add(data.userId);
    }
  });

  return Array.from(userIdsSet);
}

/**
 * Update profile for a single user
 */
async function updateSingleUserProfile(
  userId: string,
  db: admin.firestore.Firestore
): Promise<void> {
  console.log(`[updateUserNotificationProfile] Processing user ${userId}`);

  // ========================================
  // 1. FETCH FEEDBACK (LAST 30 DAYS)
  // ========================================
  const thirtyDaysAgo = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() - 30 * 24 * 60 * 60 * 1000)
  );

  const feedbackSnapshot = await db.collection("notification_feedback")
    .where("userId", "==", userId)
    .where("timestamp", ">", thirtyDaysAgo)
    .orderBy("timestamp", "desc")
    .get();

  if (feedbackSnapshot.empty) {
    console.log(`[updateUserNotificationProfile] No feedback found for user ${userId}`);
    return;
  }

  // ========================================
  // 2. CALCULATE ACCURACY
  // ========================================
  let helpfulCount = 0;
  let notHelpfulCount = 0;
  const helpfulReasons: string[] = [];
  const notHelpfulReasons: string[] = [];
  const helpfulTexts: string[] = [];
  const notHelpfulTexts: string[] = [];

  feedbackSnapshot.forEach((doc) => {
    const feedbackData = doc.data();
    const feedback = feedbackData.feedback;
    const decision = feedbackData.decision;

    if (feedback === "helpful") {
      helpfulCount++;
      if (decision.reason) {
        helpfulReasons.push(decision.reason);
      }
      if (decision.notificationText) {
        helpfulTexts.push(decision.notificationText);
      }
    } else if (feedback === "not_helpful") {
      notHelpfulCount++;
      if (decision.reason) {
        notHelpfulReasons.push(decision.reason);
      }
      if (decision.notificationText) {
        notHelpfulTexts.push(decision.notificationText);
      }
    }
  });

  const totalFeedback = helpfulCount + notHelpfulCount;
  const accuracy = totalFeedback > 0 ? (helpfulCount / totalFeedback) : 0;

  console.log(`[updateUserNotificationProfile] User ${userId} accuracy: ${(accuracy * 100).toFixed(2)}%`);

  // ========================================
  // 3. DETERMINE PREFERRED NOTIFICATION RATE
  // ========================================
  let preferredNotificationRate: "high" | "medium" | "low";

  if (accuracy >= 0.8) {
    preferredNotificationRate = "high";
  } else if (accuracy >= 0.5) {
    preferredNotificationRate = "medium";
  } else {
    preferredNotificationRate = "low";
  }

  // ========================================
  // 4. EXTRACT LEARNED KEYWORDS
  // ========================================
  const learnedKeywords = extractKeywords(helpfulTexts, helpfulReasons);
  const suppressedTopics = extractKeywords(notHelpfulTexts, notHelpfulReasons);

  console.log(`[updateUserNotificationProfile] Learned keywords: ${learnedKeywords.join(", ")}`);
  console.log(`[updateUserNotificationProfile] Suppressed topics: ${suppressedTopics.join(", ")}`);

  // ========================================
  // 5. UPDATE USER PROFILE
  // ========================================
  const profileData = {
    preferredNotificationRate,
    learnedKeywords,
    suppressedTopics,
    accuracy: Math.round(accuracy * 100) / 100,
    totalFeedback,
    helpfulCount,
    notHelpfulCount,
    lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
  };

  await db.collection("users")
    .doc(userId)
    .collection("ai_notification_profile")
    .doc("default")
    .set(profileData, { merge: true });

  console.log(`[updateUserNotificationProfile] Updated profile for user ${userId}`);
}

/**
 * Extract keywords from feedback texts and reasons
 *
 * Simple keyword extraction - counts word frequency and returns top keywords
 */
function extractKeywords(texts: string[], reasons: string[]): string[] {
  const wordCounts: { [word: string]: number } = {};

  // Combine texts and reasons
  const allTexts = [...texts, ...reasons];

  // Common stop words to exclude
  const stopWords = new Set([
    "the", "a", "an", "and", "or", "but", "is", "are", "was", "were",
    "to", "from", "in", "on", "at", "for", "with", "of", "by", "this",
    "that", "it", "you", "your", "has", "have", "had", "be", "been",
    "message", "messages", "notification", "notified", "notify",
  ]);

  // Count word frequencies
  allTexts.forEach((text) => {
    const words = text.toLowerCase()
      .replace(/[^a-z0-9\s]/g, " ")
      .split(/\s+/)
      .filter((word) => word.length > 3 && !stopWords.has(word));

    words.forEach((word) => {
      wordCounts[word] = (wordCounts[word] || 0) + 1;
    });
  });

  // Return top 10 keywords
  return Object.entries(wordCounts)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 10)
    .map(([word]) => word);
}
