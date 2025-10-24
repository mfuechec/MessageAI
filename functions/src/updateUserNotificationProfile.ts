import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

/**
 * Cloud Function: Update User Notification Profile (Scheduled)
 *
 * Story 6.5: Feedback Loop & Analytics
 *
 * Analyzes user feedback and updates their AI notification profiles
 * Runs weekly via Cloud Scheduler (Monday 00:00 UTC)
 *
 * @returns null (scheduled functions don't return values)
 */
export const updateUserNotificationProfileScheduled = functions
  .runWith({
    timeoutSeconds: 540, // 9 minutes (max for scheduled functions)
    memory: "1GB",
  })
  .pubsub.schedule("0 0 * * 1") // Every Monday at midnight UTC
  .timeZone("UTC")
  .onRun(async (context) => {
    console.log("[Scheduled] Starting weekly profile update");

    const userIds = await getAllUsersWithFeedback();
    console.log(`[Scheduled] Updating ${userIds.length} users with feedback`);

    if (userIds.length === 0) {
      console.log("[Scheduled] No users to update");
      return null;
    }

    const db = admin.firestore();
    let usersUpdated = 0;

    for (const userId of userIds) {
      try {
        await updateSingleUserProfile(userId, db);
        usersUpdated++;
      } catch (error) {
        console.error(`[Scheduled] Error updating user ${userId}:`, error);
      }
    }

    console.log(`[Scheduled] Updated ${usersUpdated}/${userIds.length} user profiles`);
    return null;
  });

/**
 * Cloud Function: Update User Notification Profile (Manual)
 *
 * Story 6.5: Feedback Loop & Analytics
 *
 * Allows users to trigger profile update immediately
 * Callable from iOS app
 *
 * @param data - Empty object (uses authenticated user)
 * @param context - Firebase Auth context
 * @returns Update summary
 */
export const updateUserNotificationProfileManual = functions
  .runWith({
    timeoutSeconds: 60,
    memory: "512MB",
  })
  .https.onCall(async (data, context) => {
    // Authentication
    if (!context?.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated"
      );
    }

    const userId = context.auth.uid;
    console.log(`[Manual] Profile update requested by user ${userId}`);

    const db = admin.firestore();

    try {
      await updateSingleUserProfile(userId, db);
      console.log(`[Manual] Profile updated for user ${userId}`);

      return {
        success: true,
        message: "Profile updated successfully",
      };
    } catch (error: any) {
      console.error(`[Manual] Error updating profile:`, error);
      throw new functions.https.HttpsError(
        "internal",
        `Failed to update profile: ${error.message}`
      );
    }
  });

/**
 * Get all users who have submitted feedback in the last 30 days
 *
 * NOTE: With new structure (/users/{userId}/notification_feedback), we need to
 * iterate through all users. This is less efficient but more architecturally sound.
 */
async function getAllUsersWithFeedback(): Promise<string[]> {
  const db = admin.firestore();
  const thirtyDaysAgo = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() - 30 * 24 * 60 * 60 * 1000)
  );

  const usersWithFeedback: string[] = [];

  // Get all users
  const usersSnapshot = await db.collection("users").get();

  // Check each user for recent feedback
  for (const userDoc of usersSnapshot.docs) {
    const userId = userDoc.id;

    const feedbackSnapshot = await db.collection("users")
      .doc(userId)
      .collection("notification_feedback")
      .where("timestamp", ">", thirtyDaysAgo)
      .limit(1) // Just check if any exist
      .get();

    if (!feedbackSnapshot.empty) {
      usersWithFeedback.push(userId);
    }
  }

  return usersWithFeedback;
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

  const feedbackSnapshot = await db.collection("users")
    .doc(userId)
    .collection("notification_feedback")
    .where("timestamp", ">", thirtyDaysAgo)
    .orderBy("timestamp", "desc")
    .get();

  if (feedbackSnapshot.empty) {
    console.log(`[updateUserNotificationProfile] No feedback found for user ${userId}`);
    return;
  }

  // ========================================
  // 2. ANALYZE FEEDBACK PATTERNS
  // ========================================
  let helpfulCount = 0;
  let notHelpfulCount = 0;
  let helpfulNotified = 0;  // Notified and helpful
  let helpfulSuppressed = 0;  // Suppressed and helpful
  let notHelpfulNotified = 0;  // Notified but not helpful
  let notHelpfulSuppressed = 0;  // Suppressed but not helpful

  const helpfulReasons: string[] = [];
  const notHelpfulReasons: string[] = [];
  const helpfulTexts: string[] = [];
  const notHelpfulTexts: string[] = [];

  feedbackSnapshot.forEach((doc) => {
    const feedbackData = doc.data();
    const feedback = feedbackData.feedback;
    const decision = feedbackData.decision;
    const wasNotified = decision.shouldNotify === true;

    if (feedback === "helpful") {
      helpfulCount++;
      if (wasNotified) {
        helpfulNotified++;
      } else {
        helpfulSuppressed++;
      }

      if (decision.reason) {
        helpfulReasons.push(decision.reason);
      }
      if (decision.notificationText) {
        helpfulTexts.push(decision.notificationText);
      }
    } else if (feedback === "not_helpful") {
      notHelpfulCount++;
      if (wasNotified) {
        notHelpfulNotified++;
      } else {
        notHelpfulSuppressed++;
      }

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

  // Calculate notification vs suppression accuracy
  const notifyAccuracy = (helpfulNotified + notHelpfulSuppressed) / totalFeedback;
  const falsePositiveRate = notHelpfulNotified / (notHelpfulNotified + helpfulNotified || 1);
  const falseNegativeRate = helpfulSuppressed / (helpfulSuppressed + notHelpfulSuppressed || 1);

  console.log(`[updateUserNotificationProfile] User ${userId} metrics:`);
  console.log(`  - Overall accuracy: ${(accuracy * 100).toFixed(2)}%`);
  console.log(`  - Notify accuracy: ${(notifyAccuracy * 100).toFixed(2)}%`);
  console.log(`  - False positive rate: ${(falsePositiveRate * 100).toFixed(2)}% (notified when shouldn't)`);
  console.log(`  - False negative rate: ${(falseNegativeRate * 100).toFixed(2)}% (missed important messages)`);

  // ========================================
  // 3. DETERMINE PREFERRED NOTIFICATION RATE
  // ========================================
  let preferredNotificationRate: "high" | "medium" | "low";

  // Smart rate determination based on false positive/negative rates
  // Goal: Minimize false positives (annoying) while catching important messages
  if (accuracy >= 0.8 && falsePositiveRate < 0.2) {
    // High accuracy, low annoyance → User appreciates current rate
    preferredNotificationRate = "high";
  } else if (falsePositiveRate > 0.4) {
    // Too many unwanted notifications → Notify less
    preferredNotificationRate = "low";
    console.log(`  → Reducing notification rate (high false positive rate)`);
  } else if (falseNegativeRate > 0.3) {
    // Missing important messages → Notify more
    preferredNotificationRate = "high";
    console.log(`  → Increasing notification rate (high false negative rate)`);
  } else {
    // Balanced performance
    preferredNotificationRate = "medium";
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
    notifyAccuracy: Math.round(notifyAccuracy * 100) / 100,
    falsePositiveRate: Math.round(falsePositiveRate * 100) / 100,
    falseNegativeRate: Math.round(falseNegativeRate * 100) / 100,
    totalFeedback,
    helpfulCount,
    notHelpfulCount,
    helpfulNotified,
    helpfulSuppressed,
    notHelpfulNotified,
    notHelpfulSuppressed,
    lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
  };

  await db.collection("users")
    .doc(userId)
    .collection("ai_notification_profile")
    .doc("profile")
    .set(profileData, { merge: true });

  console.log(`[updateUserNotificationProfile] Updated profile for user ${userId}`);
}

/**
 * Extract keywords and phrases from feedback texts and reasons
 *
 * Enhanced extraction using:
 * - Multi-word phrase detection
 * - TF-IDF-like relevance scoring
 * - Context-aware filtering
 */
function extractKeywords(texts: string[], reasons: string[]): string[] {
  if (texts.length === 0 && reasons.length === 0) {
    return [];
  }

  const wordCounts: { [word: string]: number } = {};
  const phraseCounts: { [phrase: string]: number } = {};

  // Combine texts (weighted higher) and reasons
  const allTexts = [...texts, ...texts, ...reasons];  // Weight texts 2x

  // Enhanced stop words
  const stopWords = new Set([
    "the", "a", "an", "and", "or", "but", "is", "are", "was", "were",
    "to", "from", "in", "on", "at", "for", "with", "of", "by", "this",
    "that", "it", "you", "your", "has", "have", "had", "be", "been",
    "will", "would", "could", "should", "can", "may", "might",
    "message", "messages", "notification", "notified", "notify", "user",
    "about", "there", "their", "they", "them", "then", "than",
  ]);

  // Important keywords to boost
  const importantKeywords = new Set([
    "urgent", "asap", "important", "critical", "deadline", "meeting",
    "question", "request", "mentioned", "tagged", "assigned",
    "review", "approval", "feedback", "blocked", "emergency",
  ]);

  allTexts.forEach((text) => {
    const cleaned = text.toLowerCase()
      .replace(/[^a-z0-9\s]/g, " ")
      .replace(/\s+/g, " ")
      .trim();

    const words = cleaned.split(" ").filter((word) => word.length > 3 && !stopWords.has(word));

    // Extract single words
    words.forEach((word) => {
      const weight = importantKeywords.has(word) ? 3 : 1;
      wordCounts[word] = (wordCounts[word] || 0) + weight;
    });

    // Extract 2-word phrases
    for (let i = 0; i < words.length - 1; i++) {
      const phrase = `${words[i]} ${words[i + 1]}`;
      if (phrase.length > 8) {  // Min phrase length
        phraseCounts[phrase] = (phraseCounts[phrase] || 0) + 2;  // Weight phrases higher
      }
    }
  });

  // Combine and score keywords
  const scoredKeywords: Array<{term: string; score: number}> = [];

  // Add single words
  Object.entries(wordCounts).forEach(([word, count]) => {
    // TF-IDF-like scoring: more occurrences = higher score, but diminishing returns
    const score = Math.log(count + 1) * count;
    scoredKeywords.push({term: word, score});
  });

  // Add phrases (scored higher if they appear multiple times)
  Object.entries(phraseCounts).forEach(([phrase, count]) => {
    if (count >= 2) {  // Only include phrases that appear at least twice
      const score = Math.log(count + 1) * count * 1.5;  // Phrases weighted 1.5x
      scoredKeywords.push({term: phrase, score});
    }
  });

  // Return top 15 keywords/phrases, sorted by score
  return scoredKeywords
    .sort((a, b) => b.score - a.score)
    .slice(0, 15)
    .map(({term}) => term);
}
