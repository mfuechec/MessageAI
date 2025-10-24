import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

/**
 * Cloud Function: Generate Notification Analytics
 *
 * Story 6.5: Feedback Loop & Analytics
 *
 * Generates analytics report for user's notification feedback
 *
 * @param data - { userId: string }
 * @param context - Firebase Auth context
 * @returns Analytics report with accuracy metrics
 */
export const generateNotificationAnalytics = functions
  .runWith({
    timeoutSeconds: 60,
    memory: "512MB",
  })
  .https.onCall(async (data, context) => {
    // ========================================
    // 1. AUTHENTICATION & VALIDATION
    // ========================================
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated"
      );
    }

    const requestingUserId = context.auth.uid;

    // Validate input
    if (!data.userId || typeof data.userId !== "string") {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "userId must be a non-empty string"
      );
    }

    // Only allow users to view their own analytics (or admins)
    if (requestingUserId !== data.userId) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "You can only view your own analytics"
      );
    }

    console.log(`[generateNotificationAnalytics] Generating analytics for user ${data.userId}`);

    const db = admin.firestore();

    // ========================================
    // 2. FETCH FEEDBACK DATA (LAST 30 DAYS)
    // ========================================
    const thirtyDaysAgo = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() - 30 * 24 * 60 * 60 * 1000)
    );

    const feedbackSnapshot = await db.collection("users")
      .doc(data.userId)
      .collection("notification_feedback")
      .where("timestamp", ">", thirtyDaysAgo)
      .orderBy("timestamp", "desc")
      .get();

    const totalFeedback = feedbackSnapshot.size;

    if (totalFeedback === 0) {
      console.log(`[generateNotificationAnalytics] No feedback found for user ${data.userId}`);
      return {
        totalNotifications: 0,
        helpfulCount: 0,
        notHelpfulCount: 0,
        accuracy: 0,
        commonFalsePositives: [],
        commonFalseNegatives: [],
      };
    }

    // ========================================
    // 3. CALCULATE METRICS
    // ========================================
    let helpfulCount = 0;
    let notHelpfulCount = 0;
    const falsePositiveReasons: { [key: string]: number } = {};

    feedbackSnapshot.forEach((doc) => {
      const feedbackData = doc.data();
      const feedback = feedbackData.feedback;
      const decision = feedbackData.decision;

      if (feedback === "helpful") {
        helpfulCount++;
      } else if (feedback === "not_helpful") {
        notHelpfulCount++;

        // Track false positive patterns (notified but marked not helpful)
        if (decision.shouldNotify) {
          const reason = decision.reason || "Unknown";
          falsePositiveReasons[reason] = (falsePositiveReasons[reason] || 0) + 1;
        }
      }
    });

    const accuracy = totalFeedback > 0 ? (helpfulCount / totalFeedback) * 100 : 0;

    // ========================================
    // 4. IDENTIFY COMMON FALSE POSITIVES
    // ========================================
    const commonFalsePositives = Object.entries(falsePositiveReasons)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 5)
      .map(([reason, count]) => ({ reason, count }));

    // ========================================
    // 5. FETCH FALSE NEGATIVES (OPTIONAL)
    // ========================================
    const falseNegativesSnapshot = await db.collection("false_negatives")
      .where("userId", "==", data.userId)
      .where("timestamp", ">", thirtyDaysAgo)
      .limit(100)
      .get();

    const commonFalseNegatives: { reason: string; count: number }[] = [];

    if (!falseNegativesSnapshot.empty) {
      const falseNegativeReasonCounts: { [key: string]: number } = {};

      falseNegativesSnapshot.forEach((doc) => {
        const data = doc.data();
        const reason = data.reason || "User opened conversation quickly";
        falseNegativeReasonCounts[reason] = (falseNegativeReasonCounts[reason] || 0) + 1;
      });

      commonFalseNegatives.push(
        ...Object.entries(falseNegativeReasonCounts)
          .sort((a, b) => b[1] - a[1])
          .slice(0, 5)
          .map(([reason, count]) => ({ reason, count }))
      );
    }

    // ========================================
    // 6. RETURN ANALYTICS
    // ========================================
    console.log(`[generateNotificationAnalytics] Analytics generated for user ${data.userId}`);
    console.log(`  Total feedback: ${totalFeedback}`);
    console.log(`  Helpful: ${helpfulCount}, Not helpful: ${notHelpfulCount}`);
    console.log(`  Accuracy: ${accuracy.toFixed(2)}%`);

    return {
      totalNotifications: totalFeedback,
      helpfulCount,
      notHelpfulCount,
      accuracy: Math.round(accuracy * 100) / 100, // Round to 2 decimal places
      commonFalsePositives,
      commonFalseNegatives,
    };
  });
