import * as admin from "firebase-admin";
import * as functions from "firebase-functions";

/**
 * Rate Limiting Utility (Story 3.5)
 *
 * Implements per-user rate limiting for AI features to control costs.
 * Default: 100 AI requests per user per day
 */

const DEFAULT_DAILY_LIMIT = 100;

/**
 * Check and increment rate limit for a user
 *
 * @param userId - The user ID to check
 * @param featureType - Type of AI feature (summary, actionItems, search)
 * @param dailyLimit - Maximum requests per day (default: 100)
 * @throws HttpsError if rate limit exceeded
 */
export async function checkRateLimit(
  userId: string,
  featureType: string,
  dailyLimit: number = DEFAULT_DAILY_LIMIT
): Promise<void> {
  const today = new Date().toISOString().split("T")[0]; // YYYY-MM-DD
  const rateLimitDoc = admin.firestore()
    .collection("rate_limits")
    .doc(`${userId}_${today}`);

  const rateLimitSnap = await rateLimitDoc.get();
  const data = rateLimitSnap.data();

  if (data) {
    const currentCount = data[featureType] || 0;

    if (currentCount >= dailyLimit) {
      console.warn(`[RateLimit] User ${userId} exceeded daily limit for ${featureType}: ${currentCount}/${dailyLimit}`);

      throw new functions.https.HttpsError(
        "resource-exhausted",
        `Daily AI request limit exceeded (${dailyLimit} requests per day). ` +
        `Your limit will reset tomorrow. Upgrade to a premium plan for higher limits.`
      );
    }

    // Increment counter
    await rateLimitDoc.update({
      [featureType]: admin.firestore.FieldValue.increment(1),
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`[RateLimit] User ${userId} ${featureType}: ${currentCount + 1}/${dailyLimit}`);
  } else {
    // First request today - create document
    await rateLimitDoc.set({
      userId,
      date: today,
      [featureType]: 1,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`[RateLimit] User ${userId} ${featureType}: 1/${dailyLimit} (first request today)`);
  }
}

/**
 * Get remaining requests for a user today
 *
 * @param userId - The user ID to check
 * @param featureType - Type of AI feature
 * @param dailyLimit - Maximum requests per day
 * @returns Number of remaining requests
 */
export async function getRemainingRequests(
  userId: string,
  featureType: string,
  dailyLimit: number = DEFAULT_DAILY_LIMIT
): Promise<number> {
  const today = new Date().toISOString().split("T")[0];
  const rateLimitDoc = admin.firestore()
    .collection("rate_limits")
    .doc(`${userId}_${today}`);

  const rateLimitSnap = await rateLimitDoc.get();

  if (!rateLimitSnap.exists) {
    return dailyLimit; // No requests yet today
  }

  const data = rateLimitSnap.data();
  const currentCount = data?.[featureType] || 0;

  return Math.max(0, dailyLimit - currentCount);
}
