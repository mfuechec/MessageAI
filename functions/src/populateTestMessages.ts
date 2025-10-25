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

        // Check if test messages already exist (prevent duplicate populations)
        const existingMessages = await db.collection('messages')
            .where('conversationId', '==', conversationId)
            .limit(1)
            .get();

        if (!existingMessages.empty) {
            console.log(`⚠️ [populateTestMessages] Conversation already has messages. Deleting existing messages first...`);

            // Delete all existing messages in this conversation
            const allMessages = await db.collection('messages')
                .where('conversationId', '==', conversationId)
                .get();

            const deleteBatch = db.batch();
            allMessages.docs.forEach(doc => {
                deleteBatch.delete(doc.ref);
            });
            await deleteBatch.commit();

            console.log(`🗑️ [populateTestMessages] Deleted ${allMessages.size} existing message(s)`);
        }

        // Get participant IDs for realistic conversation
        const currentUserId = userId;
        const otherUserIds = participantIds.filter(id => id !== currentUserId);
        const otherUserId1 = otherUserIds[0] || currentUserId; // Fallback to self if alone
        const otherUserId2 = otherUserIds[1] || otherUserIds[0] || currentUserId;

        // Detect conversation type: 2-person (PM + Engineer) vs group (team)
        const isGroupConversation = participantIds.length >= 3;

        console.log(`📊 Conversation type: ${isGroupConversation ? 'GROUP' : '2-PERSON'} (${participantIds.length} participants)`);

        // Define test messages based on conversation type
        let testMessages: Array<{senderId: string; text: string}>;

        if (isGroupConversation) {
            // GROUP CONVERSATION: Team standup/project discussion
            testMessages = [
                // Initial check-in
                { senderId: currentUserId, text: "Morning team! Let's do a quick standup on the Q4 launch" },
                { senderId: otherUserId1, text: "Hey! I'm finishing up the mobile responsive design. Should be ready for review by tomorrow" },
                { senderId: otherUserId2, text: "Working on the API performance optimization. Found some bottlenecks in the search endpoint" },

                // Action items emerge
                { senderId: currentUserId, text: "Great progress! Sarah, can you prepare the staging environment for testing by Friday?" },
                { senderId: otherUserId1, text: "On it! Also, Mike - don't forget to update the API documentation before the client demo next Tuesday" },
                { senderId: otherUserId2, text: "Good catch! Will do. Also need someone to review PR #456 - it's blocking the deploy" },

                // Decision point
                { senderId: currentUserId, text: "About the database choice - after weighing the options, we've decided to go with PostgreSQL instead of MongoDB. Better fit for our relational data" },
                { senderId: otherUserId1, text: "Makes sense. I'll update the architecture docs to reflect that" },

                // Urgent issue (priority)
                { senderId: otherUserId2, text: "Heads up - production API is throwing 500 errors on checkout. Payment processor says 20+ customers affected in last 30 minutes" },
                { senderId: currentUserId, text: "That's critical. Mike, can you investigate immediately? I'll notify the customer support team" },
                { senderId: otherUserId2, text: "Already on it. Looking at the logs now" },

                // Action items with deadlines
                { senderId: currentUserId, text: "Everyone please submit your time logs by 5pm today. Finance needs them for payroll" },
                { senderId: otherUserId1, text: "Will do. Also, should we schedule that design review meeting for the new dashboard?" },

                // Team decision
                { senderId: currentUserId, text: "Team consensus: we're postponing the launch to next Monday to ensure quality. Better to ship late than ship broken" },
                { senderId: otherUserId2, text: "Agreed. I'd rather have a stable release than rush it" },

                // Meeting scheduling
                { senderId: otherUserId1, text: "Can we sync tomorrow at 2pm to walk through the staging deployment process?" },
                { senderId: currentUserId, text: "Works for me. Mike, does that time work?" },
                { senderId: otherUserId2, text: "Yep, I'll be there" },

                // Budget decision
                { senderId: currentUserId, text: "Finalized the Q4 budget at $75K. Allocating $30K to cloud infrastructure, $25K to contractor hours, $20K to tooling" },

                // Wrap-up with action items
                { senderId: otherUserId1, text: "Good session! I'll send out the meeting notes and action item list in Slack" },
                { senderId: currentUserId, text: "Perfect. Let me know if anyone hits blockers. We've got a tight timeline!" }
            ];
        } else {
            // 2-PERSON CONVERSATION: PM + Engineer discussing feature implementation
            testMessages = [
                // Feature kickoff
                { senderId: currentUserId, text: "Hey! Ready to discuss the new search feature for the iOS app?" },
                { senderId: otherUserId1, text: "Absolutely! I've been looking at the requirements you sent over" },

                // Requirements discussion
                { senderId: currentUserId, text: "The main ask from the product side is semantic search - users should find what they're looking for even with fuzzy queries" },
                { senderId: otherUserId1, text: "Got it. So we'd need to integrate an embeddings model for that. Are we thinking OpenAI or something local?" },

                // Decision made
                { senderId: currentUserId, text: "After chatting with engineering leadership, we've decided to go with OpenAI's embeddings API. Faster time to market and proven quality" },
                { senderId: otherUserId1, text: "Makes sense. I'll spike on the integration this week" },

                // Action items
                { senderId: currentUserId, text: "Can you have the technical spec ready by Wednesday? We need to review it with the architecture team" },
                { senderId: otherUserId1, text: "Yep! I'll also need you to set up a meeting with the data team - want to understand the search volume we're expecting" },

                // Technical discussion
                { senderId: otherUserId1, text: "One concern - latency. If we're calling OpenAI for every search, that could be slow. Should we implement caching?" },
                { senderId: currentUserId, text: "Good catch. Yes, let's cache common searches. Maybe Redis with a 24-hour TTL?" },
                { senderId: otherUserId1, text: "Perfect. I'll include that in the spec" },

                // Priority issue surfaces
                { senderId: otherUserId1, text: "Quick heads up - our current search is completely broken in production. The Algolia index got corrupted somehow and users are getting zero results" },
                { senderId: currentUserId, text: "Oh no! How many users affected?" },
                { senderId: otherUserId1, text: "Everyone who's tried to search in the last hour. Support tickets are piling up" },
                { senderId: currentUserId, text: "Okay, drop everything and fix that first. The new feature can wait" },

                // Resolution
                { senderId: otherUserId1, text: "Fixed! Re-indexed from scratch. Search is back up" },
                { senderId: currentUserId, text: "Amazing, thank you! Crisis averted" },

                // Back to planning
                { senderId: currentUserId, text: "Okay, back to the smart search feature. Timeline-wise, can we ship this by end of Q4?" },
                { senderId: otherUserId1, text: "If we stick to the MVP scope - semantic search only, no filters - then yes. I'd estimate 3 weeks of dev, 1 week of testing" },

                // Decision and action
                { senderId: currentUserId, text: "Let's do it. I'll get design to mock up the search UI by next Monday" },
                { senderId: otherUserId1, text: "Sounds good! And I'll have that technical spec to you by Wednesday like we discussed" },

                // Meeting scheduling
                { senderId: currentUserId, text: "Want to sync Friday at 10am to review your spec together?" },
                { senderId: otherUserId1, text: "Perfect! See you then" },

                // Final action reminder
                { senderId: currentUserId, text: "One last thing - please add the project to Jira and create the epic. We'll need to track this for the roadmap review" },
                { senderId: otherUserId1, text: "Will do! Creating it now" }
            ];
        }

        console.log(`📨 Creating ${testMessages.length} test messages...`);

        // Use batch writes for efficiency (max 500 per batch)
        const batch = db.batch();
        const now = admin.firestore.Timestamp.now();
        let successCount = 0;
        let lastCreatedMessageId = '';

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
            lastCreatedMessageId = messageId;  // Track last message ID
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
            lastMessageId: lastCreatedMessageId  // Use actual last message ID
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
