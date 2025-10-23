import * as admin from "firebase-admin";
import * as functions from "firebase-functions";

/**
 * Verify that the authenticated user is a participant in the specified conversation
 *
 * @param userId - The user ID to check (from context.auth.uid)
 * @param conversationId - The conversation ID to validate access for
 * @throws HttpsError with 'permission-denied' if user is not a participant
 */
export async function verifyConversationParticipant(
  userId: string,
  conversationId: string
): Promise<void> {
  const conversationDoc = await admin.firestore()
    .collection("conversations")
    .doc(conversationId)
    .get();

  if (!conversationDoc.exists) {
    throw new functions.https.HttpsError(
      "not-found",
      `Conversation ${conversationId} not found`
    );
  }

  const conversation = conversationDoc.data();
  if (!conversation) {
    throw new functions.https.HttpsError(
      "internal",
      "Conversation data is missing"
    );
  }

  const participantIds: string[] = conversation.participantIds || [];

  if (!participantIds.includes(userId)) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "User is not a participant in this conversation"
    );
  }
}

/**
 * Verify that the authenticated user is a participant in all specified conversations
 *
 * @param userId - The user ID to check
 * @param conversationIds - Array of conversation IDs to validate
 * @throws HttpsError if user is not a participant in any conversation
 */
export async function verifyMultipleConversationAccess(
  userId: string,
  conversationIds: string[]
): Promise<void> {
  for (const conversationId of conversationIds) {
    await verifyConversationParticipant(userId, conversationId);
  }
}

/**
 * Get all conversation IDs where the user is a participant
 *
 * @param userId - The user ID
 * @returns Array of conversation IDs
 */
export async function getUserConversations(
  userId: string
): Promise<string[]> {
  const conversationsSnapshot = await admin.firestore()
    .collection("conversations")
    .where("participantIds", "array-contains", userId)
    .get();

  return conversationsSnapshot.docs.map((doc) => doc.id);
}
