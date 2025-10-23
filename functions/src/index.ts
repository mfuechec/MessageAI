import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();

// ========================================
// AI CLOUD FUNCTIONS (Story 3.1)
// ========================================
export {summarizeThread} from "./summarizeThread";
export {extractActionItems} from "./extractActionItems";
export {generateSmartSearchResults} from "./generateSmartSearchResults";

// ========================================
// MESSAGING CLOUD FUNCTIONS
// ========================================

/**
 * Cloud Function: Send push notification when new message is created
 *
 * Triggers on: /messages/{messageId} document creation
 * Action: Sends FCM push notification to all conversation participants
 * except sender
 */
export const sendMessageNotification = functions.firestore
  .document("messages/{messageId}")
  .onCreate(async (snapshot, context) => {
    const message = snapshot.data();
    const messageId = context.params.messageId;

    try {
      // Extract message data
      const senderId = message.senderId;
      const conversationId = message.conversationId;
      const messageText = message.text || "[Media]";
      const timestamp = message.timestamp;

      console.log(
        `Processing notification for message ${messageId} from ${senderId}`
      );

      // Fetch conversation to get participants
      const conversationDoc = await admin.firestore()
        .collection("conversations")
        .doc(conversationId)
        .get();

      if (!conversationDoc.exists) {
        console.error(`Conversation ${conversationId} not found`);
        return;
      }

      const conversation = conversationDoc.data();
      if (!conversation) {
        console.error(`Conversation ${conversationId} data not found`);
        return;
      }

      const participantIds: string[] = conversation.participantIds || [];

      // Fetch sender info for notification
      const senderDoc = await admin.firestore()
        .collection("users")
        .doc(senderId)
        .get();

      const senderName = senderDoc.data()?.displayName || "Someone";

      // Determine recipients (all participants except sender)
      const recipientIds = participantIds.filter(
        (id: string) => id !== senderId
      );

      if (recipientIds.length === 0) {
        console.log("No recipients for notification");
        return;
      }

      // Fetch recipient FCM tokens
      const recipientTokens: string[] = [];
      for (const recipientId of recipientIds) {
        const userDoc = await admin.firestore()
          .collection("users")
          .doc(recipientId)
          .get();

        const userData = userDoc.data();

        // Only send notification if user is offline or not in conversation
        const isOnline = userData?.isOnline || false;
        const currentConversationId = userData?.currentConversationId || null;

        // Skip if user is online AND currently viewing this conversation
        if (isOnline && currentConversationId === conversationId) {
          console.log(
            `Skipping notification for ${recipientId} - viewing conversation`
          );
          continue;
        }

        const fcmToken = userData?.fcmToken;
        if (fcmToken) {
          recipientTokens.push(fcmToken);
        }
      }

      if (recipientTokens.length === 0) {
        console.log("No FCM tokens available for recipients");
        return;
      }

      // Build notification payload
      const notificationTitle = conversation.isGroup ?
        `${senderName} in ${conversation.name || "Group"}` :
        senderName;

      const notificationBody = messageText.length > 100 ?
        `${messageText.substring(0, 97)}...` :
        messageText;

      // Send notification to all recipients
      const payload = {
        notification: {
          title: notificationTitle,
          body: notificationBody,
          sound: "default",
        },
        data: {
          conversationId: conversationId,
          messageId: messageId,
          senderId: senderId,
          timestamp: timestamp.toString(),
          type: "new_message",
        },
      };

      const response = await admin.messaging()
        .sendToDevice(recipientTokens, payload);

      console.log(
        `Successfully sent notification to ${recipientTokens.length} devices`
      );
      console.log(`Success count: ${response.successCount}`);
      console.log(`Failure count: ${response.failureCount}`);

      // Log any failures
      if (response.failureCount > 0) {
        response.results.forEach((result, index) => {
          if (result.error) {
            console.error(
              `Error sending to token ${recipientTokens[index]}:`,
              result.error
            );
          }
        });
      }

      return response;
    } catch (error) {
      console.error("Error sending notification:", error);
      throw error;
    }
  });

/**
 * Cloud Function: Clean up stale typing indicators
 *
 * Scheduled to run every minute
 * Action: Sets typing status to false for users inactive > 5 seconds
 */
export const cleanupTypingIndicators = functions.pubsub
  .schedule("every 1 minutes")
  .onRun(async (context) => {
    const fiveSecondsAgo = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() - 5000)
    );

    const staleTypingQuery = await admin.firestore()
      .collection("conversations")
      .where("typingUsers", "!=", {})
      .get();

    const batch = admin.firestore().batch();
    let updateCount = 0;

    staleTypingQuery.forEach((doc) => {
      const data = doc.data();
      const typingUsers = data.typingUsers || {};

      // Filter out stale typing indicators
      const updatedTypingUsers: Record<string, any> = {};
      let hasChanges = false;

      for (const [userId, typingData] of Object.entries(typingUsers)) {
        const lastTyping = (typingData as any).lastTyping;
        if (lastTyping && lastTyping > fiveSecondsAgo) {
          updatedTypingUsers[userId] = typingData;
        } else {
          hasChanges = true;
        }
      }

      if (hasChanges) {
        batch.update(doc.ref, {typingUsers: updatedTypingUsers});
        updateCount++;
      }
    });

    if (updateCount > 0) {
      await batch.commit();
      console.log(`Cleaned up ${updateCount} stale typing indicators`);
    }

    return null;
  });

