# Epic 2: Complete MVP with Reliability

## Epic 2 Goal

Complete all Gauntlet MVP Phase 1 and Phase 2 requirements including group chat, advanced message features (edit/unsend/retry), read receipts, typing indicators, image attachments, offline message management, and push notifications. Each feature is built with reliability and performance criteria ensuring zero message loss and optimized delivery under various network conditions. Regression test suite established to validate stability as features are added. Expected timeline: 1.5 days.

## Story 2.0: Start New Conversation with Duplicate Prevention

As a **user**,  
I want **to start a new conversation by selecting a contact**,  
so that **I can message anyone in the system without creating duplicate conversations**.

### Acceptance Criteria

1. "New Message" button (+ icon) displayed in navigation bar of conversations list
2. Tap "New Message" opens user selection view showing all available users (excluding current user)
3. User selection view displays: avatar, display name, and email for each user
4. Search/filter functionality to find users by name or email
5. Tap user initiates `getOrCreateConversation()` repository method
6. **Duplicate Prevention Logic:**
   - Query Firestore for existing conversation with exact participant match
   - Sort participant IDs for consistent comparison (alphabetical order)
   - If conversation exists, navigate to existing conversation (no duplicate created)
   - If no conversation exists, create new conversation and navigate to it
7. **Repository Method:** `ConversationRepositoryProtocol.getOrCreateConversation(participantIds: [String]) async throws -> Conversation`
8. Loading indicator shown during conversation lookup/creation
9. Error handling: Network failures show retry option
10. **Race Condition Handling:** If two users simultaneously try to create same conversation, Firestore query detects existing conversation created by other user
11. New conversation appears immediately in conversations list for both participants
12. Performance: Conversation lookup/creation completes within 2 seconds
13. Reliability: Works offline - queued for creation when connection restored
14. **Unit Tests:**
    - Test `getOrCreateConversation` returns existing conversation when found
    - Test `getOrCreateConversation` creates new conversation when not found
    - Test participant ID sorting (ensure [A,B] matches [B,A])
    - Test duplicate detection with 2+ users
15. **Integration Test:** User A creates conversation with User B, User B tries to create conversation with User A, verify same conversation returned
16. **Edge Cases:**
    - Self-conversation prevention (can't create conversation with self)
    - Conversation with deleted/non-existent user ID shows error
    - Multiple rapid taps on "New Message" don't create duplicates

## Story 2.1: Group Chat Functionality

**Dependencies:** Story 2.0 (uses same user selection and `getOrCreateConversation` logic)

As a **user**,  
I want **to create and participate in group conversations with 3 or more people**,  
so that **I can coordinate with my entire team in one place**.

### Acceptance Criteria

1. User selection view (from Story 2.0) enhanced to support multi-select (3-10 users)
2. Group conversation created in Firestore with all participant IDs
3. Group chat view displays all participants' names in navigation bar
4. Messages in group chat show sender name for all messages (not just "You" vs "Them")
5. All participants receive real-time message updates via Firestore listeners
6. **Group Avatar UI:** Group conversations display multi-participant avatar in conversations list:
   - 2 participants: Two circular avatars arranged side-by-side within circle space
   - 3 participants: Three avatars in triangular arrangement (2 top, 1 bottom)
   - 4+ participants: Four avatars in 2x2 grid arrangement (top-left, top-right, bottom-left, bottom-right)
   - Each mini-avatar shows participant's profile photo or initials
   - All contained within same circular avatar space as one-on-one chats
   - Provides instant visual differentiation: group vs one-on-one
7. Group conversation appears in conversations list for all participants
8. Unread counts tracked per participant in group
9. Tap participant names in nav bar to view group member list
10. Message delivery works reliably for all group sizes (tested up to 10 participants)
11. Performance: Messages appear within 2 seconds for all online participants
12. Reliability: Messages delivered to all participants even if some are offline (queued for delivery)
13. **Component:** Create `GroupAvatarView` SwiftUI component for reusable multi-avatar display
14. Unit tests for group conversation creation and message distribution logic
15. Integration test: 3 users in group, User A sends message, verify Users B and C receive it
16. Regression test: Verify one-on-one chat still works after group chat implementation

## Story 2.2: Message Editing with History

As a **user**,  
I want **to edit messages I've already sent**,  
so that **I can correct typos or clarify my meaning**.

### Acceptance Criteria

1. Long-press message bubble shows contextual menu with "Edit" option (only for own messages)
2. Edit mode opens text field with current message content pre-filled
3. "Save" button updates message in Firestore with edit timestamp
4. Edited messages display "(edited)" indicator next to timestamp
5. Message edit history stored in Firestore (array of {text, timestamp} objects)
6. Tap "(edited)" indicator shows edit history modal with all versions
7. Real-time updates: All participants see edited message immediately
8. Editing works offline: Edit queued and synced when connection restored
9. Message entity updated with `editHistory` array and `isEdited` boolean
10. MessageRepository protocol extended with `editMessage` method
11. Performance: Edit appears instantly with optimistic UI, confirmed within 2 seconds
12. Reliability: Edit conflicts handled (if edited offline on multiple devices, last write wins with timestamp)
13. Unit tests for edit message logic in ViewModel and Repository
14. Integration test: User A edits message, User B sees update in real-time
15. Regression test: Message sending still works after edit implementation

## Story 2.3: Message Unsend (Delete for Everyone)

As a **user**,  
I want **to delete messages I've sent from everyone's view**,  
so that **I can remove messages sent by mistake**.

### Acceptance Criteria

1. Long-press message bubble shows "Unsend" option (only for own messages within 24 hours)
2. Confirmation alert: "Delete this message for everyone?"
3. Unsend action deletes message from Firestore or marks as deleted
4. Deleted messages show placeholder: "[Message deleted]" for all participants
5. Real-time updates: All participants see deletion immediately
6. Message data removed from database (privacy), only placeholder remains
7. Unsending works offline: Delete queued and synced when connected
8. MessageRepository protocol extended with `deleteMessage` method
9. Performance: Deletion appears instantly (optimistic UI), confirmed within 2 seconds
10. Reliability: Deletion works even if some participants offline (applied when they sync)
11. Edge case: Deleted messages removed from conversation preview in conversations list
12. Unit tests for delete message logic
13. Integration test: User A deletes message, User B sees "[Message deleted]"
14. Regression test: Edit and send functionality still work after unsend implementation

## Story 2.4: Message Send Retry on Failure

As a **user**,  
I want **to manually retry sending messages that failed**,  
so that **I have control over when failed messages are resent**.

### Acceptance Criteria

1. Messages that fail to send display with red warning icon and "Failed" status
2. Tap failed message shows alert: "Message failed to send. [Retry] [Delete]"
3. Retry button attempts to resend message via repository
4. Delete button removes message from local queue permanently
5. Failed messages persist locally (not lost on app restart)
6. Message status enum includes: sending, sent, delivered, read, failed
7. ViewModel tracks failed messages and provides retry action
8. Performance: Retry attempt completes within 3 seconds or marks failed again
9. Reliability: Failed messages stored in local queue, never lost
10. Network error types handled gracefully (timeout, no connection, Firebase error)
11. Unit tests for retry logic in ViewModel
12. Integration test: Force network failure, send message, verify failure state, restore network, retry, verify success
13. Regression test: Normal message sending still works reliably

## Story 2.5: Read Receipts

As a **user**,  
I want **to see when my messages have been read by others**,  
so that **I know if my message has been seen**.

### Acceptance Criteria

1. Message status updates to "read" when recipient views the chat containing the message
2. Read receipts displayed as small checkmarks: ✓ (sent), ✓✓ (delivered), ✓✓ (blue, read)
3. Message entity includes `readBy` array tracking user IDs who have read
4. Repository method `markMessagesAsRead` updates Firestore when user views chat
5. Real-time updates: Sender sees read receipt immediately when recipient opens chat
6. Group chat read receipts show count: "Read by 2 of 3"
7. Tap read receipt in group chat shows list of who has read
8. Read status updates work offline: Queued and synced when connected
9. Performance: Read receipts appear within 1 second of recipient opening chat
10. Reliability: Read status never downgrades (read → delivered), only upgrades
11. Unit tests for read receipt logic
12. Integration test: User A sends message to User B, User B opens chat, User A sees read receipt
13. Regression test: Message delivery and editing still work with read receipts active

## Story 2.6: Typing Indicators

As a **user**,  
I want **to see when someone is typing in a conversation**,  
so that **I know to wait for their response**.

### Acceptance Criteria

1. Typing indicator appears below last message when participant is actively typing
2. Indicator shows: "[Name] is typing..." (one-on-one) or "[Name], [Name] are typing..." (group)
3. Firestore document tracks typing state per user per conversation (ephemeral data)
4. Typing state set to true when user types, false after 3 seconds of inactivity or on send
5. Real-time updates: Typing indicators appear within 500ms for recipients
6. Typing state cleared when user leaves chat view
7. Performance: Typing updates throttled (max 1 update per second) to reduce Firestore writes
8. Reliability: Typing state automatically cleared after timeout (prevents stuck "is typing")
9. MessageKit integrated typing indicator UI used (if available) or custom SwiftUI component
10. Unit tests for typing state management logic
11. Integration test: User A types, User B sees typing indicator within 1 second
12. Performance test: Typing updates don't cause lag in message composition
13. Regression test: Message sending, editing, and real-time updates still performant

## Story 2.7: Image Attachments

As a **user**,  
I want **to send and receive images in conversations**,  
so that **I can share visual information with my team**.

### Acceptance Criteria

1. Attachment button in message input bar opens photo library picker
2. Selected image uploads to Firebase Storage
3. Message entity includes `attachments` array with { type, url, thumbnailUrl }
4. Image displayed in message bubble (MessageKit image message support)
5. Tap image opens full-screen viewer with zoom and pan
6. Image upload shows progress indicator during upload
7. Failed uploads show error state with retry option
8. Images compressed before upload to optimize storage and bandwidth (max 2MB per image)
9. Thumbnail generated for conversation list preview if last message is image
10. Image messages work offline: Image cached, upload queued until connection restored
11. Performance: Image upload completes within 10 seconds on reasonable connection
12. Reliability: Image uploads never lost, queued and retried on failure
13. Security: Firebase Storage rules restrict access to conversation participants only
14. Unit tests for image upload logic
15. Integration test: User A sends image, User B receives and views it
16. Regression test: Text messaging still works reliably with image support added

## Story 2.8: Document Attachments (PDF)

As a **user**,  
I want **to send and receive PDF documents in conversations**,  
so that **I can share reports, contracts, and other important documents with my team**.

### Acceptance Criteria

1. Attachment button in message input bar provides option to select "Document" (in addition to "Photo")
2. Document picker opens (UIDocumentPickerViewController) filtered to PDF file types
3. Selected PDF uploads to Firebase Storage in dedicated `/documents/` path
4. Message entity `attachments` array supports type: "document" with { type, url, fileName, fileSize, mimeType }
5. PDF attachment displayed in message bubble as document card showing: file icon, file name, file size
6. Tap PDF attachment opens in native iOS document viewer (QuickLook framework)
7. Document upload shows progress indicator with percentage (0-100%)
8. Failed uploads show error state with retry option
9. PDF file size limited to 10MB maximum (enforced before upload with user-friendly error)
10. Document messages work offline: Upload queued until connection restored
11. Performance: PDF upload completes within 30 seconds on reasonable connection (proportional to file size)
12. Reliability: Document uploads never lost, queued and retried on failure
13. Security: Firebase Storage rules restrict document access to conversation participants only
14. Document preview in conversation list shows file icon + "[Document]" label
15. Unit tests for document upload logic, file size validation, and MIME type validation
16. Integration test: User A sends PDF, User B receives and opens it in QuickLook viewer
17. Regression test: Image attachments and text messaging still work with document support added
18. Edge case: Handle documents with special characters or very long file names (truncate display)

## Story 2.9: Offline Message Queue with Manual Send

As a **user**,  
I want **to see messages I've composed offline and manually send them when connected**,  
so that **I have control over what gets sent when connectivity returns**.

### Acceptance Criteria

1. Messages composed while offline display with "Queued" status (yellow warning icon)
2. Persistent offline banner displays: "You're offline. X messages queued. [Send All]"
3. Queued messages persist locally (survive app restart)
4. Connectivity restored toast notification: "Connected. Auto-send 5 queued messages? [Yes] [Review First]"
5. "Review First" navigates to Offline Queue view showing all queued messages
6. Offline Queue view allows per-message actions: [Send] [Edit] [Delete]
7. "Send All" button in banner sends all queued messages in order
8. Queued messages sent sequentially (not in parallel) to maintain order
9. Successfully sent messages removed from queue and marked "sent"
10. Failed sends remain in queue with "Failed" status and manual retry option
11. Performance: Queue view loads instantly (local data only)
12. Reliability: Queue persisted in local storage (UserDefaults or local database), never lost
13. Edge case: Large queues (50+ messages) handled without UI lag
14. Unit tests for queue management logic
15. Integration test: Compose 5 messages offline, go online, send all, verify delivery
16. Regression test: Real-time messaging still works when always online

## Story 2.10: Push Notifications (Foreground & Background)

As a **user**,  
I want **to receive push notifications for new messages**,  
so that **I'm alerted even when not actively using the app**.

### Acceptance Criteria

1. APNs certificate configured in Firebase Console
2. Device token registered with FCM on app launch
3. User prompted for notification permissions on first app launch
4. Cloud Function triggers on new message write to Firestore
5. Cloud Function sends push notification to recipient device(s) via FCM
6. Notification includes: sender name, message text preview, conversation ID
7. Foreground notifications displayed as banner at top (using UNUserNotificationCenter)
8. Background notifications wake device and display lock screen alert
9. Tap notification opens app directly to relevant conversation
10. Notification sound plays (default iOS sound acceptable for MVP)
11. Badge count updates on app icon showing unread message count
12. User online in conversation does NOT receive push (avoid redundant notifications)
13. Group chat notifications show: "[Sender] in [Group Name]: [Message]"
14. Performance: Notifications delivered within 5 seconds of message send
15. Reliability: Notifications delivered even if app is closed or device was offline (queued by APNs)
16. Cloud Function deployed and callable from Firestore triggers
17. Integration test: User A sends message while User B app backgrounded, verify User B receives push
18. Security: Cloud Function validates sender is participant in conversation before sending
19. Regression test: Real-time messaging in-app still works with push notifications enabled

## Story 2.11: Performance Optimization & Network Resilience

As a **developer**,  
I want **the app to handle poor network conditions and high message volume gracefully**,  
so that **users experience reliable messaging even under adverse conditions**.

### Acceptance Criteria

1. Firestore queries optimized with proper indexing (composite indexes created)
2. Message pagination implemented (load 50 most recent, fetch older on scroll)
3. Conversation list pagination for users with 100+ conversations
4. Image thumbnails used in conversation previews (not full-resolution images)
5. Firestore listeners cleaned up properly when views dismissed (prevent memory leaks)
6. Network error handling with exponential backoff retry logic
7. Timeout handling for long-running operations (10 second max wait for network calls)
8. App handles 3G network speeds without crashes or data loss
9. Rapid-fire messaging test: Send 20+ messages quickly, verify all delivered in order
10. Performance baseline: App launch < 1 second, conversation load < 1 second, message send < 2 seconds
11. Memory profiling: App uses < 150MB RAM with 10 conversations loaded
12. Battery usage acceptable (no background processing runaway)
13. Offline → Online transition smooth (no crashes, queued messages process)
14. **Relative Timestamp Updates:** Conversation list timestamps update periodically
    - "2 minutes ago" becomes "3 minutes ago" automatically
    - Timer updates every 60 seconds for active conversations
    - Pauses when app backgrounded (battery optimization)
    - Uses SwiftUI `.onReceive(timer)` pattern
    - No flicker or visual disruption during updates
15. Integration test: Toggle airplane mode repeatedly during active messaging, verify no data loss
16. Load testing: 1000 message conversation loads and scrolls smoothly
17. **User Cache Optimization (Discovered in Story 2.2):**
    - ConversationsListViewModel implements user caching to prevent redundant Firebase reads
    - Cache fetched users with 5-minute TTL (time-to-live)
    - Online status uses separate 30-second TTL
    - LRU eviction strategy (max 100 users)
    - Message edit triggers 0-1 participant fetches (vs 50+ without cache)
    - Profile changes appear within 5 minutes
    - Firebase read count reduced by 90%+ on conversation list updates
    - **Impact:** Fixes performance issue where editing 1 message triggers ~50+ redundant user reads
    - **Reference:** See Story 2.2 Dev Agent Record for console logs and detailed analysis

## Story 2.12: Comprehensive Reliability Testing & Regression Suite

As a **QA engineer**,  
I want **a comprehensive test suite covering all MVP functionality and reliability scenarios**,  
so that **we can confidently validate the app meets production-quality standards**.

### Acceptance Criteria

1. **Regression Test Suite Created** covering all Epic 1 and Epic 2 functionality:
   - Authentication flows
   - One-on-one messaging (with duplicate conversation prevention)
   - Group chat
   - Message editing, unsend, retry
   - Read receipts and typing indicators
   - Image and document attachments
   - Offline queue
   - Push notifications

2. **10 Reliability Test Scenarios Defined and Executed:**
   - Scenario 1: Send 50 messages while toggling airplane mode 5 times - verify zero message loss
   - Scenario 2: Kill app mid-send - verify message completes on app restart
   - Scenario 3: Send message, edit 3 times, unsend - verify all participants see correct final state
   - Scenario 4: Group chat with 10 users, all send simultaneously - verify all messages delivered
   - Scenario 5: Compose 20 messages offline, review queue, send all - verify order maintained
   - Scenario 6: Send 100 messages rapidly (< 30 seconds) - verify all delivered without crashes
   - Scenario 7: Leave app backgrounded for 1 hour, receive 50 messages - verify all push notifications delivered
   - Scenario 8: Upload 10MB image on slow 3G - verify progress, completion, and retry on failure
   - Scenario 9: Two users edit same message simultaneously - verify conflict resolution (last write wins)
   - Scenario 10: Start with offline cached data, delete 5 conversations online (other device), sync - verify correct state

3. **Test Execution Results Documented:**
   - All 10 scenarios pass without critical failures
   - Any minor issues documented with workarounds or known limitations
   - Performance benchmarks recorded (message send time, app launch time, etc.)

4. **Code Coverage Verified:**
   - Minimum 70% coverage for Domain and Data layers maintained
   - New Epic 2 features have corresponding unit tests

5. **TestFlight Deployment:**
   - App successfully deployed to TestFlight
   - Beta testing instructions documented
   - At least 2 external testers receive build and validate basic messaging

6. **MVP Checkpoint Passed:**
   - All Gauntlet MVP requirements validated against spec
   - Demo-ready: Can showcase all required features to evaluators
   - Known issues list created for any non-critical bugs

---
