import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

/**
 * Cloud Function: Submit Notification Feedback
 *
 * Story 6.5: Feedback Loop & Analytics
 *
 * Allows users to provide feedback on AI notification decisions
 *
 * @param data - { conversationId: string, messageId: string, decision: NotificationDecision, feedback: "helpful" | "not_helpful" }
 * @param context - Firebase Auth context
 * @returns { success: boolean }
 */
export const submitNotificationFeedback = functions
  .runWith({
    timeoutSeconds: 30,
    memory: "256MB",
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

    const userId = context.auth.uid;

    // Validate input
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

    if (!data.feedback || !["helpful", "not_helpful"].includes(data.feedback)) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        'feedback must be "helpful" or "not_helpful"'
      );
    }

    if (!data.decision || typeof data.decision !== "object") {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "decision must be a valid NotificationDecision object"
      );
    }

    console.log(`[submitNotificationFeedback] User ${userId} submitted "${data.feedback}" for conversation ${data.conversationId}`);

    const db = admin.firestore();

    // ========================================
    // 2. VERIFY USER IS PARTICIPANT
    // ========================================
    const conversationDoc = await db.collection("conversations").doc(data.conversationId).get();
    if (!conversationDoc.exists) {
      throw new functions.https.HttpsError(
        "not-found",
        "Conversation not found"
      );
    }

    const conversationData = conversationDoc.data();
    const participantIds = conversationData?.participantIds || [];

    if (!participantIds.includes(userId)) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "User not a participant in conversation"
      );
    }

    // ========================================
    // 3. STORE FEEDBACK IN FIRESTORE
    // ========================================
    const feedbackId = `${userId}_${data.conversationId}_${data.messageId}`;

    await db.collection("notification_feedback").doc(feedbackId).set({
      userId,
      conversationId: data.conversationId,
      messageId: data.messageId,
      decision: data.decision,
      feedback: data.feedback,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`[submitNotificationFeedback] Feedback stored: ${feedbackId}`);

    // ========================================
    // 4. RETURN SUCCESS
    // ========================================
    return {
      success: true,
      feedbackId,
    };
  });
