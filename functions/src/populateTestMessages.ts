import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

/**
 * Cloud Function to populate test messages for AI feature testing
 *
 * This function bypasses Firestore security rules to create messages
 * from multiple participants, enabling realistic conversation testing.
 *
 * Security: Only callable in development environment or by authenticated users
 */
export const populateTestMessages = functions.https.onCall(async (data, context) => {
    // Verify authentication
    if (!context.auth) {
        throw new functions.https.HttpsError(
            'unauthenticated',
            'User must be authenticated to populate test messages'
        );
    }

    const userId = context.auth.uid;

    // Validate input
    if (!data.conversationId || typeof data.conversationId !== 'string') {
        throw new functions.https.HttpsError(
            'invalid-argument',
            'conversationId is required and must be a string'
        );
    }

    const conversationId = data.conversationId;

    console.log(`🧪 [populateTestMessages] Starting for conversation: ${conversationId}`);
    console.log(`🧪 [populateTestMessages] Caller: ${userId}`);

    try {
        const db = admin.firestore();

        // Get conversation to verify caller is a participant
        const conversationDoc = await db.collection('conversations').doc(conversationId).get();

        if (!conversationDoc.exists) {
            throw new functions.https.HttpsError(
                'not-found',
                'Conversation not found'
            );
        }

        const conversation = conversationDoc.data()!;
        const participantIds: string[] = conversation.participantIds || [];

        if (!participantIds.includes(userId)) {
            throw new functions.https.HttpsError(
                'permission-denied',
                'User is not a participant in this conversation'
            );
        }

        console.log(`✅ User is participant. Total participants: ${participantIds.length}`);

        // Get participant IDs for realistic conversation
        const currentUserId = userId;
        const otherUserIds = participantIds.filter(id => id !== currentUserId);
        const otherUserId1 = otherUserIds[0] || currentUserId; // Fallback to self if alone
        const otherUserId2 = otherUserIds[1] || otherUserIds[0] || currentUserId;

        // Define test messages with realistic multi-user conversation
        const testMessages: Array<{senderId: string; text: string}> = [
            // Regular conversation starter
            { senderId: currentUserId, text: "Hey team! Quick check-in about the project status" },
            { senderId: otherUserId1, text: "Sure! I've been working on the design mockups" },

            // Action items - should be detected by AI
            { senderId: currentUserId, text: "Can you finish the quarterly report by Friday EOD?" },
            { senderId: otherUserId1, text: "Yes, I'll get that done. Also, remember to send the contract to John before tomorrow's meeting" },
            { senderId: otherUserId2, text: "I need someone to review the pull request #234 before we deploy" },

            // Priority messages - should be flagged as urgent (natural language, no labels)
            { senderId: otherUserId1, text: "The database migration failed and rolled back. All user data from the last 2 hours is lost and we need to figure out recovery before people notice" },
            { senderId: currentUserId, text: "Legal just called - we're violating GDPR with our current data retention policy and could face fines. Need immediate review and changes" },

            // Decision tracking - important conclusions
            { senderId: currentUserId, text: "After discussing with the team, we've decided to go with option B for the architecture" },
            { senderId: otherUserId1, text: "Team agreed to postpone the launch to next Monday to ensure quality" },
            { senderId: otherUserId2, text: "We've finalized the budget at $50K for Q2" },

            // More action items
            { senderId: currentUserId, text: "Please update the documentation by Wednesday" },
            { senderId: otherUserId1, text: "Don't forget to schedule the client demo for next week" },

            // Mixed conversation with embedded actions
            { senderId: otherUserId2, text: "The API integration looks good. Can you test it in staging today?" },
            { senderId: currentUserId, text: "Will do. Also need to follow up with marketing about the campaign" },

            // Decision with reasoning
            { senderId: otherUserId1, text: "We've decided to use PostgreSQL instead of MongoDB because of the complex relational data" },

            // Priority with action (natural urgency through context)
            { senderId: currentUserId, text: "Major client threatening to cancel their $500K contract because of the performance issues. We have until tomorrow morning to show improvement or they're walking" },

            // Regular updates
            { senderId: otherUserId2, text: "Just finished the user testing session. Results look promising" },
            { senderId: otherUserId1, text: "Great! Let's review them in tomorrow's standup" },

            // Action with deadline
            { senderId: currentUserId, text: "Everyone needs to complete their timesheets by 5 PM today" },

            // Decision confirmation
            { senderId: otherUserId1, text: "Confirmed: We're moving forward with the React migration starting next sprint" },

            // Mixed priority and action (natural urgency)
            { senderId: otherUserId2, text: "Payment processor is rejecting all transactions right now. We've had 50+ failed checkouts in the last hour and customers are complaining on social media" },

            // Wrap-up with actions
            { senderId: currentUserId, text: "Good progress everyone! Let's make sure all action items are tracked in Jira" },
            { senderId: otherUserId1, text: "Will do. I'll also send out meeting notes by end of day" }
        ];

        console.log(`📨 Creating ${testMessages.length} test messages...`);

        // Use batch writes for efficiency (max 500 per batch)
        const batch = db.batch();
        const now = admin.firestore.Timestamp.now();
        let successCount = 0;

        for (let i = 0; i < testMessages.length; i++) {
            const messageData = testMessages[i];
            const messageId = db.collection('messages').doc().id;

            // Create message with past timestamp (spaced out over last hour)
            const timestamp = admin.firestore.Timestamp.fromMillis(
                now.toMillis() - (testMessages.length - i) * 60 * 1000
            );

            const message = {
                id: messageId,
                conversationId: conversationId,
                senderId: messageData.senderId,
                text: messageData.text,
                timestamp: timestamp,
                status: 'sent',
                statusUpdatedAt: timestamp,
                attachments: [],
                editHistory: null,
                editCount: 0,
                isEdited: false,
                isDeleted: false,
                deletedAt: null,
                deletedBy: null,
                readBy: [messageData.senderId],
                readCount: 1,
                isPriority: false,
                priorityReason: null,
                schemaVersion: 1
            };

            batch.set(db.collection('messages').doc(messageId), message);
            successCount++;
        }

        // Commit batch
        await batch.commit();
        console.log(`✅ Successfully created ${successCount} test messages`);

        // Update conversation's last message
        const lastMessage = testMessages[testMessages.length - 1];
        await db.collection('conversations').doc(conversationId).update({
            lastMessage: lastMessage.text,
            lastMessageTimestamp: now,
            lastMessageSenderId: lastMessage.senderId,
            lastMessageId: db.collection('messages').doc().id
        });

        console.log(`✅ Updated conversation lastMessage`);

        return {
            success: true,
            messageCount: successCount,
            conversationId: conversationId,
            timestamp: now.toDate().toISOString()
        };

    } catch (error: any) {
        console.error('❌ Error populating test messages:', error);

        if (error instanceof functions.https.HttpsError) {
            throw error;
        }

        throw new functions.https.HttpsError(
            'internal',
            `Failed to populate test messages: ${error.message}`
        );
    }
});
