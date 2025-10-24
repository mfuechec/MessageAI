# Epic 6: Smart AI-Powered Notifications - Manual Testing Guide

**Created:** 2025-10-23
**Epic:** Epic 6 - Smart AI-Powered Notifications
**Stories:** 6.0, 6.1, 6.2, 6.3, 6.4, 6.5, 6.6
**Tester:** _______________
**Date Tested:** _______________
**Environment:** ☐ Development ☐ Production

---

## Prerequisites & Test Environment Setup

### Required Setup (Complete Before Testing)

- [ ] **Two iOS Devices or Simulators:**
  - Device A: "Alice" (will enable smart notifications)
  - Device B: "Bob" (will send messages to Alice)

- [ ] **User Accounts:**
  - [ ] Create Alice's account (alice@test.com)
  - [ ] Create Bob's account (bob@test.com)
  - [ ] Create a conversation between Alice and Bob

- [ ] **Firebase Console Access:**
  - [ ] Open Firebase Console (https://console.firebase.google.com)
  - [ ] Select `messageai-dev-1f2ec` project
  - [ ] Open Firestore Database tab
  - [ ] Open Functions tab (for monitoring)

- [ ] **OpenAI API Status:**
  - [ ] Verify OpenAI API key configured in Cloud Functions
  - [ ] Check API quota is sufficient (requires ~$1 for testing)
  - [ ] Run: `firebase functions:config:get openai.api_key`

- [ ] **Xcode Console Output:**
  - [ ] Run app from Xcode (not TestFlight)
  - [ ] Open Console pane (Cmd+Shift+Y)
  - [ ] Filter for "🌐", "🔥", "🔔" emojis for relevant logs

### Test Data Preparation

Create these test conversations on **Bob's device**:

**Conversation 1: Technical Discussion** (Alice + Bob)
- Send 3 messages about general project status
- Wait 2 minutes
- Send 1 message with @Alice mention
- Send 1 message with "urgent" keyword

**Conversation 2: Social Chat** (Alice + Bob)
- Send 5 casual messages ("hey", "how are you", "lunch?", "😊", "thanks!")

**Conversation 3: Decision Making** (Alice + Bob + Charlie)
- Send 3 messages about API design decisions
- Send 1 message asking Alice to make a decision

---

## Story 6.0: Setup & Prerequisites

### Test 6.0.1: OpenAI API Configuration

**Objective:** Verify OpenAI API is configured and accessible.

**Steps:**
1. Open terminal
2. Navigate to functions directory: `cd functions`
3. Check API key: `firebase functions:config:get openai.api_key --project messageai-dev-1f2ec`
4. Test OpenAI connection: `node src/testOpenAI.ts` (if test file exists)

**Expected Results:**
- [ ] API key is configured and starts with `sk-`
- [ ] Test connection succeeds (if test file available)
- [ ] No error messages

**Actual Results:**
```
[Write observations here]
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

### Test 6.0.2: Firestore Security Rules

**Objective:** Verify new Firestore collections have correct security rules.

**Steps:**
1. Open `firestore.rules` file
2. Verify rules exist for:
   - `users/{userId}/ai_notification_preferences`
   - `message_embeddings/{embeddingId}`
   - `notification_feedback/{feedbackId}`
   - `ai_notification_cache/{cacheId}`
3. Deploy rules: `firebase deploy --only firestore:rules --project messageai-dev-1f2ec`

**Expected Results:**
- [ ] All new collections have security rules
- [ ] Deployment succeeds without errors
- [ ] Firebase Console shows updated rules

**Actual Results:**
```
[Write observations here]
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

### Test 6.0.3: Firestore Indexes

**Objective:** Verify composite indexes are deployed.

**Steps:**
1. Open `firestore.indexes.json`
2. Verify indexes exist for:
   - `message_embeddings`: `conversationId` + `timestamp`
   - `notification_decisions`: `userId` + `timestamp`
3. Deploy: `firebase deploy --only firestore:indexes --project messageai-dev-1f2ec`
4. Check Firebase Console → Firestore → Indexes tab

**Expected Results:**
- [ ] Indexes defined in JSON file
- [ ] Deployment succeeds
- [ ] Indexes show "Enabled" status in Console (may take 5-10 minutes)

**Actual Results:**
```
[Write observations here]
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

## Story 6.1: Conversation Activity Monitoring & Trigger Logic

### Test 6.1.1: Activity Monitor Initialization

**Objective:** Verify `ConversationActivityMonitor` starts on app launch.

**Steps:**
1. Kill and restart Alice's app
2. Check Xcode console for activity monitor logs
3. Look for: `"[ConversationActivityMonitor] Initialized"`

**Expected Results:**
- [ ] Console shows initialization log
- [ ] No error messages
- [ ] Monitor starts before messages arrive

**Actual Results:**
```
[Write observations here]
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

### Test 6.1.2: Message Tracking

**Objective:** Verify monitor tracks incoming messages.

**Steps:**
1. On Alice's device, open conversation with Bob
2. On Bob's device, send 3 messages rapidly: "Hey", "Update on project", "We're on track"
3. On Alice's device, check Xcode console

**Expected Results:**
- [ ] Console shows: `"[ConversationActivityMonitor] Message received in conversation: [ID]"`
- [ ] Message count increments: `"[ConversationActivityMonitor] Message count: 1"`, `"2"`, `"3"`
- [ ] No errors

**Actual Results:**
```
[Write observations here]
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

### Test 6.1.3: Pause Detection Trigger

**Objective:** Verify analysis triggers after conversation pause.

**Steps:**
1. Ensure Alice's app is in background (not viewing conversation)
2. From Bob's device, send 3 messages to Alice
3. Wait exactly 2 minutes (120 seconds) without sending more messages
4. On Alice's device, check Xcode console

**Expected Results:**
- [ ] After 120 seconds: `"[ConversationActivityMonitor] Pause detected after [N] messages"`
- [ ] Immediately after: `"[ConversationActivityMonitor] Triggering analysis for conversation: [ID]"`
- [ ] Cloud Function call initiated: `"[NotificationAnalysisRepository] Calling analyzeForNotification"`

**Actual Results:**
```
[Write observations here]
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

### Test 6.1.4: Active Conversation Suppression

**Objective:** Verify analysis does NOT trigger when user actively viewing conversation.

**Steps:**
1. On Alice's device, OPEN conversation with Bob (keep it in foreground)
2. From Bob's device, send 3 messages
3. Wait 2+ minutes
4. Check Xcode console

**Expected Results:**
- [ ] Console shows: `"[ConversationActivityMonitor] Suppressing analysis - user viewing conversation"`
- [ ] NO analysis triggered
- [ ] NO Cloud Function call

**Actual Results:**
```
[Write observations here]
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

### Test 6.1.5: Debouncing (Multiple Pauses)

**Objective:** Verify only ONE analysis per 5-minute window.

**Steps:**
1. Ensure Alice's app is in background
2. From Bob's device, send 2 messages
3. Wait 2 minutes (triggers first analysis)
4. Send 2 more messages
5. Wait 2 minutes (within 5-minute window)
6. Check console

**Expected Results:**
- [ ] First pause: Analysis triggered
- [ ] Second pause: `"[ConversationActivityMonitor] Debouncing - analysis within 5-minute window"`
- [ ] Second pause: NO Cloud Function call

**Actual Results:**
```
[Write observations here]
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

### Test 6.1.6: Message Threshold Trigger

**Objective:** Verify analysis triggers after exceeding message threshold (20 messages).

**Steps:**
1. Ensure Alice's app is in background
2. From Bob's device, send 22 messages rapidly (within 10 minutes)
3. Wait 2+ minutes after last message
4. Check console

**Expected Results:**
- [ ] Console shows: `"[ConversationActivityMonitor] Message threshold exceeded (22/20)"`
- [ ] After pause: `"[ConversationActivityMonitor] Triggering analysis for threshold-exceeded conversation"`
- [ ] Cloud Function call initiated

**Actual Results:**
```
[Write observations here]
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

## Story 6.2: RAG System for Full User Context

### Test 6.2.1: On-Demand Embedding Generation

**Objective:** Verify embeddings are generated when needed (not for every message).

**Steps:**
1. Open Firebase Console → Firestore → `message_embeddings` collection
2. Note current document count
3. From Bob's device, send 1 message to Alice
4. Trigger analysis (wait 2 minutes)
5. Check `message_embeddings` collection again

**Expected Results:**
- [ ] New embedding created ONLY when analysis triggered (not immediately)
- [ ] Embedding document contains: `messageId`, `conversationId`, `embedding` (array of 1536 floats), `timestamp`
- [ ] Cloud Function logs show: `"[RAG] Generating embedding for message: [ID]"`

**Actual Results:**
```
[Write observations here]
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

### Test 6.2.2: Embedding Reuse

**Objective:** Verify existing embeddings are reused (< 7 days old).

**Steps:**
1. Trigger analysis on conversation (creates embeddings)
2. Note the embedding IDs in Firestore
3. Wait 1 minute
4. Trigger another analysis on same conversation
5. Check Cloud Function logs

**Expected Results:**
- [ ] Second analysis logs: `"[RAG] Using existing embedding for message: [ID]"`
- [ ] NO new embedding generated
- [ ] Same embedding IDs in Firestore

**Actual Results:**
```
[Write observations here]
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

### Test 6.2.3: User Context Retrieval

**Objective:** Verify RAG retrieves user's recent activity across all conversations.

**Steps:**
1. Ensure Alice has messages in multiple conversations (at least 3 conversations)
2. Trigger analysis on one conversation
3. Check Cloud Function logs for: `"[RAG] getUserRecentContext"`
4. Look for context size in logs

**Expected Results:**
- [ ] Logs show: `"[RAG] Retrieved [N] recent messages for user alice"`
- [ ] N ≤ 100 (respects limit)
- [ ] Context includes messages from MULTIPLE conversations (not just analyzed conversation)
- [ ] Context includes messages from past 7 days only

**Actual Results:**
```
[Write observations here]
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

### Test 6.2.4: Semantic Search

**Objective:** Verify semantic search finds relevant past messages.

**Steps:**
1. Create historical context:
   - Bob sends message to Alice: "Can you review the API design doc?" (3 days ago)
   - Bob sends message to Alice: "@Alice urgent: production issue" (2 days ago)
2. Trigger analysis on new conversation
3. Check Cloud Function logs for semantic search results

**Expected Results:**
- [ ] Logs show: `"[RAG] Semantic search for: [query]"`
- [ ] Logs show: `"[RAG] Found [N] relevant messages"`
- [ ] Relevant messages include past @mentions and urgent keywords

**Actual Results:**
```
[Write observations here]
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

### Test 6.2.5: User Preference Loading

**Objective:** Verify AI loads user's notification preferences.

**Steps:**
1. Ensure Alice has smart notifications enabled (Story 6.4 setup)
2. Set custom priority keywords: "demo", "urgent", "blocker"
3. Trigger analysis
4. Check Cloud Function logs

**Expected Results:**
- [ ] Logs show: `"[RAG] Loading user preferences for: alice"`
- [ ] Logs show custom keywords: `"[RAG] Priority keywords: demo, urgent, blocker"`
- [ ] Preferences included in LLM context

**Actual Results:**
```
[Write observations here]
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

## Story 6.3: AI Notification Analysis Cloud Function

### Test 6.3.1: Direct Mention (MUST Notify)

**Objective:** Verify AI always notifies for @mentions.

**Steps:**
1. Ensure Alice's app is in background
2. From Bob's device, send: "@Alice can you review the API design by EOD?"
3. Wait 2 minutes (trigger analysis)
4. Check Cloud Function logs and Alice's device

**Expected Results:**
- [ ] Cloud Function logs: `"[AI] Decision: NOTIFY"`
- [ ] Reason: `"Direct mention with action requested"`
- [ ] Priority: `"high"`
- [ ] Notification text: `"Bob mentioned you: Can you review the API design by EOD?"`
- [ ] Alice receives notification on device

**Actual Results:**
```
[Write observations here]
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

### Test 6.3.2: Urgent Keyword (SHOULD Notify)

**Objective:** Verify AI notifies for priority keywords.

**Steps:**
1. Ensure Alice's app is in background
2. From Bob's device, send: "Production down! Database connection failing"
3. Wait 2 minutes
4. Check logs and notification

**Expected Results:**
- [ ] Cloud Function logs: `"[AI] Decision: NOTIFY"`
- [ ] Reason includes: `"urgent priority keyword detected"`
- [ ] Priority: `"high"` or `"medium"`
- [ ] Alice receives notification

**Actual Results:**
```
[Write observations here]
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

### Test 6.3.3: General Chat (Should NOT Notify)

**Objective:** Verify AI does NOT notify for casual conversation.

**Steps:**
1. Ensure Alice's app is in background
2. From Bob's device, send: "Great job on the demo! 🎉"
3. Wait 2 minutes
4. Check logs

**Expected Results:**
- [ ] Cloud Function logs: `"[AI] Decision: DO NOT NOTIFY"`
- [ ] Reason: `"Social conversation not involving Alice"` or similar
- [ ] Priority: `"low"`
- [ ] Alice does NOT receive notification

**Actual Results:**
```
[Write observations here]
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

### Test 6.3.4: Direct Question (SHOULD Notify)

**Objective:** Verify AI notifies for direct questions.

**Steps:**
1. Ensure Alice's app is in background
2. From Bob's device, send: "Alice, could you send me the latest build?"
3. Wait 2 minutes
4. Check logs

**Expected Results:**
- [ ] Cloud Function logs: `"[AI] Decision: NOTIFY"`
- [ ] Reason includes: `"direct question to Alice"`
- [ ] Priority: `"medium"` or `"high"`
- [ ] Alice receives notification

**Actual Results:**
```
[Write observations here]
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

### Test 6.3.5: Decision Affecting User (SHOULD Notify)

**Objective:** Verify AI detects decisions requiring user input.

**Steps:**
1. Ensure Alice's app is in background
2. From Bob's device in group conversation, send: "Team, we're going with Option B for the API design unless anyone objects"
3. Wait 2 minutes
4. Check logs

**Expected Results:**
- [ ] Cloud Function logs: `"[AI] Decision: NOTIFY"`
- [ ] Reason includes: `"decision affecting Alice's work"` or `"requires team input"`
- [ ] Alice receives notification

**Actual Results:**
```
[Write observations here]
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

### Test 6.3.6: Cache Hit Performance

**Objective:** Verify caching reduces latency and cost.

**Steps:**
1. Trigger first analysis on conversation
2. Note timestamp from logs: `"[AI] Analysis started at: [timestamp]"`
3. Note timestamp: `"[AI] Analysis completed at: [timestamp]"`
4. Calculate latency (completion - start)
5. Wait 1 minute
6. Trigger second analysis on SAME conversation (same unread messages)
7. Note timestamps and latency again

**Expected Results:**
- [ ] First analysis latency: 5-10 seconds (LLM call)
- [ ] Second analysis logs: `"[AI] Cache hit for key: [key]"`
- [ ] Second analysis latency: < 1 second
- [ ] Cloud Function logs show NO OpenAI API call on second analysis

**Actual Results:**
```
First analysis: _____ seconds
Second analysis: _____ seconds (cache hit: Y/N)
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

### Test 6.3.7: Fallback Heuristics (AI Unavailable)

**Objective:** Verify fallback logic when OpenAI API fails.

**Steps:**
1. Temporarily break OpenAI API key: `firebase functions:config:unset openai.api_key --project messageai-dev-1f2ec`
2. Deploy: `firebase deploy --only functions --project messageai-dev-1f2ec`
3. From Bob's device, send: "@Alice urgent task"
4. Wait 2 minutes
5. Check logs
6. **RESTORE API key when done**: `firebase functions:config:set openai.api_key="sk-..." --project messageai-dev-1f2ec`

**Expected Results:**
- [ ] Cloud Function logs: `"[AI] OpenAI unavailable, using fallback heuristics"`
- [ ] Fallback detects @mention: `"[Fallback] Direct mention detected → NOTIFY"`
- [ ] Alice receives notification
- [ ] Notification text generated by fallback logic (not LLM)

**Actual Results:**
```
[Write observations here]
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

## Story 6.4: User Preferences, Opt-In Controls & Fallback

### Test 6.4.1: First-Time Opt-In Flow

**Objective:** Verify opt-in modal appears and preferences are saved.

**Steps:**
1. Fresh install or delete Alice's user preferences from Firestore
2. On Alice's device, open Settings → Notifications
3. Tap "Smart Notifications (AI-Powered)" section
4. Read opt-in modal
5. Tap "Enable Smart Notifications"
6. Check Firestore

**Expected Results:**
- [ ] Modal appears with:
  - Feature explanation
  - Privacy statement
  - "Enable Smart Notifications" button
- [ ] After enabling, modal dismisses
- [ ] Firestore: `users/alice/ai_notification_preferences` created with defaults:
  - `enabled: true`
  - `pauseThresholdSeconds: 120`
  - `priorityKeywords: ["urgent", "ASAP", "production down", "blocker", "help"]`
  - `fallbackStrategy: "simple_rules"`

**Actual Results:**
```
[Write observations here]
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

### Test 6.4.2: Privacy Statement

**Objective:** Verify privacy information is clear.

**Steps:**
1. Open opt-in modal (if first time) or Settings → Smart Notifications
2. Read privacy statement
3. Check for link to privacy policy

**Expected Results:**
- [ ] Privacy statement explains:
  - Messages analyzed securely
  - No long-term storage of message content
  - Only notification decisions stored
- [ ] Privacy policy link present and clickable
- [ ] User can opt-out anytime

**Actual Results:**
```
[Write observations here]
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

### Test 6.4.3: Pause Threshold Customization

**Objective:** Verify user can adjust pause threshold.

**Steps:**
1. On Alice's device, open Settings → Smart Notifications
2. Adjust "Pause Threshold" slider to 60 seconds (minimum)
3. Save settings
4. Check Firestore: `users/alice/ai_notification_preferences/pauseThresholdSeconds`
5. From Bob's device, send 2 messages
6. Wait exactly 60 seconds
7. Check if analysis triggers

**Expected Results:**
- [ ] Slider adjusts from 60s to 300s
- [ ] Firestore updates to `pauseThresholdSeconds: 60`
- [ ] Analysis triggers after 60 seconds (not default 120 seconds)

**Actual Results:**
```
[Write observations here]
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

### Test 6.4.4: Custom Priority Keywords

**Objective:** Verify user can add custom keywords.

**Steps:**
1. On Alice's device, open Settings → Smart Notifications → Priority Keywords
2. Add "demo" and "review" to keyword list
3. Save
4. Check Firestore
5. From Bob's device, send: "Alice, can you review this demo?"
6. Wait 2 minutes
7. Check AI decision logs

**Expected Results:**
- [ ] Keywords saved to Firestore: `priorityKeywords: ["urgent", "ASAP", ..., "demo", "review"]`
- [ ] Cloud Function logs show custom keywords in context: `"[RAG] Priority keywords: ..., demo, review"`
- [ ] AI decision considers custom keywords
- [ ] Alice receives notification

**Actual Results:**
```
[Write observations here]
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

### Test 6.4.5: Quiet Hours

**Objective:** Verify quiet hours suppress non-urgent notifications.

**Steps:**
1. On Alice's device, set Quiet Hours: Start: 10:00 PM, End: 8:00 AM
2. Save settings
3. **Option A (if current time is within quiet hours):**
   - From Bob's device, send casual message: "Hey, how's it going?"
   - Wait 2 minutes
   - Check if notification suppressed
4. **Option B (if current time is outside quiet hours):**
   - Manually set device time to 11:00 PM (within quiet hours)
   - Repeat test

**Expected Results:**
- [ ] Firestore: `quietHoursStart: "22:00"`, `quietHoursEnd: "08:00"`
- [ ] During quiet hours + low/medium priority → NO notification
- [ ] Cloud Function logs: `"[NotificationDelivery] Quiet hours active, suppressing notification"`
- [ ] High priority messages (mentions, urgent) bypass quiet hours

**Actual Results:**
```
[Write observations here]
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

### Test 6.4.6: Fallback Strategy Selection

**Objective:** Verify user can choose fallback behavior.

**Steps:**
1. On Alice's device, open Settings → Smart Notifications → Fallback Strategy
2. Change from "Use simple rules" to "Notify for all messages"
3. Save
4. Temporarily disable OpenAI (Story 6.3.7 steps)
5. From Bob's device, send casual message: "Nice weather today"
6. Wait 2 minutes
7. Check if Alice receives notification

**Expected Results:**
- [ ] Fallback strategy saved to Firestore: `fallbackStrategy: "notify_all"`
- [ ] When AI unavailable, fallback uses "notify_all" strategy
- [ ] Alice receives notification even for casual message
- [ ] Cloud Function logs: `"[Fallback] Using notify_all strategy"`

**Actual Results:**
```
[Write observations here]
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

### Test 6.4.7: Test Notification Button

**Objective:** Verify "Test Smart Notification" feature works.

**Steps:**
1. On Alice's device, ensure there are recent messages in a conversation
2. Open Settings → Smart Notifications
3. Tap "Test Smart Notification" button
4. Wait for test result modal

**Expected Results:**
- [ ] Modal appears showing:
  - Decision: ✅ Will Notify / ❌ Won't Notify
  - Priority badge (High / Medium / Low)
  - AI reasoning
  - Notification text preview
  - Note: "This is a test - no actual notification sent"
- [ ] NO actual notification delivered
- [ ] Cloud Function logs show test analysis call

**Actual Results:**
```
[Write observations here]
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

### Test 6.4.8: Opt-Out Flow

**Objective:** Verify user can disable smart notifications.

**Steps:**
1. On Alice's device, open Settings → Smart Notifications
2. Toggle "Enable Smart Notifications" OFF
3. Confirm opt-out
4. Check Firestore
5. From Bob's device, send: "@Alice urgent task"
6. Wait 2 minutes

**Expected Results:**
- [ ] Opt-out confirmation modal: "Are you sure? You'll receive notifications for every message."
- [ ] After confirmation, Firestore: `users/alice/ai_notification_preferences/enabled: false`
- [ ] NO analysis triggered (monitor suppressed)
- [ ] Alice receives notification via traditional flow (Story 2.10)

**Actual Results:**
```
[Write observations here]
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

## Story 6.5: Feedback Loop, Analytics & Continuous Improvement

### Test 6.5.1: Notification Feedback Buttons

**Objective:** Verify feedback buttons appear in notifications.

**Steps:**
1. Ensure Alice receives a notification (use Test 6.3.1 @mention)
2. On Alice's device, pull down notification to expand
3. Check for action buttons

**Expected Results:**
- [ ] Notification shows two action buttons:
  - "👍 Helpful"
  - "👎 Not Helpful"
- [ ] Buttons are tappable
- [ ] iOS notification actions configured

**Actual Results:**
```
[Write observations here]
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

### Test 6.5.2: Helpful Feedback Submission

**Objective:** Verify "Helpful" feedback is recorded.

**Steps:**
1. Alice receives notification
2. Tap "👍 Helpful" action button
3. Check Firestore: `notification_feedback` collection
4. Check Cloud Function logs

**Expected Results:**
- [ ] Firestore document created:
  - `userId: "alice"`
  - `conversationId: [conversation ID]`
  - `feedback: "helpful"`
  - `decision: { ... }` (includes AI reasoning)
  - `timestamp: [current time]`
- [ ] Cloud Function logs: `"[Feedback] User alice marked notification as helpful"`

**Actual Results:**
```
[Write observations here]
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

### Test 6.5.3: Not Helpful Feedback Submission

**Objective:** Verify "Not Helpful" feedback is recorded.

**Steps:**
1. Alice receives notification (use casual message that AI incorrectly notified)
2. Tap "👎 Not Helpful" action button
3. Check Firestore

**Expected Results:**
- [ ] Firestore document created with `feedback: "not_helpful"`
- [ ] Cloud Function logs: `"[Feedback] User alice marked notification as NOT helpful"`

**Actual Results:**
```
[Write observations here]
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

### Test 6.5.4: Notification History View

**Objective:** Verify user can view notification history.

**Steps:**
1. Ensure Alice has received at least 3 notifications
2. On Alice's device, open Settings → Smart Notifications → Notification History
3. Scroll through history

**Expected Results:**
- [ ] Last 20 notifications displayed
- [ ] Each entry shows:
  - Conversation name
  - Notification text
  - Timestamp (e.g., "2 hours ago")
  - AI reasoning ("Why this was sent")
  - Thumbs up/down buttons for retroactive feedback
- [ ] Most recent notifications at top

**Actual Results:**
```
[Write observations here]
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

### Test 6.5.5: Retroactive Feedback

**Objective:** Verify user can provide feedback retroactively from history.

**Steps:**
1. Open Notification History
2. Find a notification without feedback
3. Tap "👍 Helpful"
4. Check Firestore

**Expected Results:**
- [ ] Feedback saved to Firestore (same as real-time feedback)
- [ ] UI updates to show feedback recorded
- [ ] Thumbs up/down buttons disabled or highlighted

**Actual Results:**
```
[Write observations here]
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

### Test 6.5.6: User Profile Learning (Weekly Job)

**Objective:** Verify feedback updates user notification profile.

**Steps:**
1. Manually trigger profile update (if Cloud Function supports manual trigger)
   - OR wait for weekly job to run
   - OR simulate by running function locally: `firebase functions:shell`
2. Check Firestore: `users/alice/ai_notification_profile`
3. Check for learned patterns

**Expected Results:**
- [ ] Profile document created/updated with:
  - `preferredNotificationRate: "high" | "medium" | "low"` (based on helpful/not helpful ratio)
  - `learnedKeywords: [...]` (extracted from helpful notifications)
  - `suppressedTopics: [...]` (extracted from not-helpful notifications)
  - `accuracy: 0.XX` (helpful count / total)
- [ ] Cloud Function logs: `"[Learning] Updated user profile for alice, accuracy: 0.XX"`

**Actual Results:**
```
[Write observations here]
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

### Test 6.5.7: Profile Applied to Future Decisions

**Objective:** Verify learned preferences affect future notifications.

**Steps:**
1. Ensure Alice's profile shows `suppressedTopics: ["lunch", "weather"]`
2. From Bob's device, send: "Anyone want to grab lunch?"
3. Wait 2 minutes
4. Check AI decision logs

**Expected Results:**
- [ ] Cloud Function logs: `"[AI] User profile suppresses topic: lunch"`
- [ ] Decision: `DO NOT NOTIFY`
- [ ] Reason includes: `"User has indicated preference against this topic"`
- [ ] Alice does NOT receive notification

**Actual Results:**
```
[Write observations here]
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

### Test 6.5.8: False Negative Detection

**Objective:** Verify system detects when user opens conversation shortly after message (missed notification).

**Steps:**
1. Ensure Alice's app is in background
2. From Bob's device, send important message that AI incorrectly suppresses: "Alice, client is asking for update"
3. Wait 2 minutes (no notification sent)
4. On Alice's device, manually open conversation within 5 minutes of message
5. Check Firestore: `notification_decisions` collection

**Expected Results:**
- [ ] Original decision logged with `wasDelivered: false`
- [ ] Background job detects: User opened conversation within 5 minutes
- [ ] Firestore logs potential false negative: `possibleFalseNegative: true`
- [ ] Cloud Function logs: `"[Analytics] Potential false negative detected for user alice"`

**Actual Results:**
```
[Write observations here]
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

## Story 6.6: Push Notification Delivery & Deep Linking

### Test 6.6.1: FCM Token Registration (Reused from Story 2.10)

**Objective:** Verify FCM token exists for Alice.

**Steps:**
1. Check Firestore: `users/alice/fcmToken`
2. Verify token is recent (< 30 days old)

**Expected Results:**
- [ ] FCM token exists
- [ ] Token format: starts with long alphanumeric string
- [ ] Token updated timestamp is recent

**Actual Results:**
```
[Write observations here]
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

### Test 6.6.2: High Priority Notification Delivery

**Objective:** Verify high-priority notifications display as alert banner.

**Steps:**
1. Ensure Alice's app is in background or closed
2. From Bob's device, send: "@Alice URGENT: Production database down"
3. Wait 2 minutes
4. On Alice's device, observe notification

**Expected Results:**
- [ ] Notification appears as **alert banner** (not just notification center)
- [ ] Notification includes **sound**
- [ ] Notification shows:
  - Title: "MessageAI" or conversation name
  - Body: "Bob mentioned you: URGENT: Production database down"
  - Sender avatar (if available)
- [ ] Priority: High (verified in logs)

**Actual Results:**
```
[Write observations here]
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

### Test 6.6.3: Medium Priority Notification (Silent)

**Objective:** Verify medium-priority notifications are silent.

**Steps:**
1. Ensure Alice's app is in background
2. From Bob's device, send: "Alice, could you review the API docs when you get a chance?"
3. Wait 2 minutes
4. Observe notification

**Expected Results:**
- [ ] Notification appears in **notification center only** (no banner)
- [ ] **No sound** played
- [ ] Notification text clear and actionable
- [ ] Priority: Medium (verified in logs)

**Actual Results:**
```
[Write observations here]
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

### Test 6.6.4: Low Priority (Badge Only)

**Objective:** Verify low-priority decisions update badge only.

**Steps:**
1. From Bob's device, send casual message that AI marks as low priority
2. Wait 2 minutes
3. Check Cloud Function logs for priority
4. On Alice's device, check app badge

**Expected Results:**
- [ ] Cloud Function logs: `priority: "low"`
- [ ] **No notification banner or sound**
- [ ] App badge increments (if implemented)
- [ ] Low priority documented in decision logs

**Actual Results:**
```
[Write observations here]
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

### Test 6.6.5: Deep Link to Conversation

**Objective:** Verify tapping notification opens correct conversation.

**Steps:**
1. Ensure Alice's app is **closed** (fully quit)
2. Trigger notification (use @mention)
3. On Alice's device, tap notification
4. Observe app behavior

**Expected Results:**
- [ ] App launches (if closed)
- [ ] App navigates directly to conversation with Bob
- [ ] Conversation view displays
- [ ] No intermediate screens

**Actual Results:**
```
[Write observations here]
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

### Test 6.6.6: Deep Link to Specific Message

**Objective:** Verify notification scrolls to exact message that triggered notification.

**Steps:**
1. Create long conversation with Bob (50+ messages)
2. From Bob's device, send new message with @mention
3. Wait for notification
4. Tap notification on Alice's device
5. Observe scroll position

**Expected Results:**
- [ ] App opens conversation
- [ ] **Scrolls to the @mention message** (not bottom of conversation)
- [ ] Message highlighted briefly with yellow flash animation
- [ ] Highlight fades after 2-3 seconds

**Actual Results:**
```
[Write observations here]
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

### Test 6.6.7: Deep Link When App Backgrounded

**Objective:** Verify deep linking works when app already running.

**Steps:**
1. Ensure Alice's app is **running but backgrounded** (home screen visible)
2. Trigger notification
3. Tap notification

**Expected Results:**
- [ ] App comes to foreground
- [ ] Navigates to conversation
- [ ] Scrolls to specific message

**Actual Results:**
```
[Write observations here]
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

### Test 6.6.8: Active Conversation Suppression (Server-Side)

**Objective:** Verify Cloud Function suppresses notification if user viewing conversation.

**Steps:**
1. On Alice's device, OPEN conversation with Bob (keep in foreground)
2. Verify Firestore: `users/alice/currentConversationId` is set to this conversation ID
3. From Bob's device, send: "@Alice quick question"
4. Wait 2 minutes
5. Check Cloud Function logs

**Expected Results:**
- [ ] Cloud Function logs: `"[NotificationDelivery] User actively viewing conversation, suppressing notification"`
- [ ] NO FCM push sent
- [ ] Alice does NOT receive notification (message already visible on screen)

**Actual Results:**
```
[Write observations here]
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

### Test 6.6.9: Quiet Hours Enforcement (Server-Side)

**Objective:** Verify Cloud Function respects quiet hours.

**Steps:**
1. Set Alice's quiet hours: 10:00 PM - 8:00 AM
2. Set device time to 11:00 PM (or wait until quiet hours)
3. From Bob's device, send medium-priority message (not urgent)
4. Wait 2 minutes
5. Check logs

**Expected Results:**
- [ ] Cloud Function logs: `"[NotificationDelivery] Quiet hours active (22:00-08:00)"`
- [ ] Priority is medium/low: `"[NotificationDelivery] Suppressing non-urgent notification"`
- [ ] Alice does NOT receive notification

**Actual Results:**
```
[Write observations here]
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

### Test 6.6.10: Quiet Hours Bypass for High Priority

**Objective:** Verify high-priority notifications bypass quiet hours.

**Steps:**
1. Ensure quiet hours active (11:00 PM)
2. From Bob's device, send: "@Alice URGENT: Production down"
3. Wait 2 minutes

**Expected Results:**
- [ ] Cloud Function logs: `"[NotificationDelivery] High priority bypasses quiet hours"`
- [ ] Alice receives notification DESPITE quiet hours
- [ ] Notification shows as banner with sound

**Actual Results:**
```
[Write observations here]
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

### Test 6.6.11: Quick Reply from Notification

**Objective:** Verify user can reply directly from notification.

**Steps:**
1. Alice receives notification
2. Long-press or 3D Touch notification
3. Tap "Reply" action
4. Type message: "Got it, will review"
5. Send

**Expected Results:**
- [ ] Text input appears in notification
- [ ] Message sends successfully
- [ ] Message appears in Firestore: `messages` collection
- [ ] Bob sees message on his device
- [ ] Notification dismisses

**Actual Results:**
```
[Write observations here]
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

### Test 6.6.12: Mark as Read from Notification

**Objective:** Verify "Mark Read" action works.

**Steps:**
1. Alice receives notification
2. Long-press notification
3. Tap "Mark Read" action
4. Check Firestore

**Expected Results:**
- [ ] Notification dismisses
- [ ] Firestore: Messages marked as read (readBy array includes Alice's ID)
- [ ] Unread count decrements
- [ ] Badge count updates

**Actual Results:**
```
[Write observations here]
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

### Test 6.6.13: Notification Grouping by Conversation

**Objective:** Verify multiple notifications from same conversation are grouped.

**Steps:**
1. Ensure Alice's app is in background
2. From Bob's device, send 3 separate messages that each trigger notifications
3. Wait 2 minutes after each
4. On Alice's device, check notification center

**Expected Results:**
- [ ] iOS groups notifications by conversation
- [ ] Single conversation entry shows: "3 messages"
- [ ] Expand to see all 3 notifications
- [ ] Each notification individually actionable

**Actual Results:**
```
[Write observations here]
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

### Test 6.6.14: Rate Limiting

**Objective:** Verify maxAnalysesPerHour limit enforced.

**Steps:**
1. Set Alice's maxAnalysesPerHour to 3
2. Trigger 4 separate analyses within 1 hour:
   - Send messages → wait 2 min (analysis 1)
   - Send messages → wait 2 min (analysis 2)
   - Send messages → wait 2 min (analysis 3)
   - Send messages → wait 2 min (analysis 4 - should be rate limited)
3. Check logs

**Expected Results:**
- [ ] First 3 analyses execute normally
- [ ] 4th analysis logs: `"[NotificationAnalysis] Rate limit exceeded (3/3), using fallback"`
- [ ] 4th analysis uses fallback heuristics OR queues for later
- [ ] Alice notified: "Smart notification limit reached. Using simple rules."

**Actual Results:**
```
[Write observations here]
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

## Integration & End-to-End Tests

### Test INT-1: Complete Flow (Opt-In → Notification → Feedback)

**Objective:** Verify entire Epic 6 flow works end-to-end.

**Steps:**
1. **Setup:**
   - Fresh Alice account (no preferences)
   - Bob's account ready

2. **Opt-In:**
   - Alice opens Settings → Smart Notifications
   - Reads privacy modal
   - Enables smart notifications
   - Verifies Firestore preferences created

3. **Trigger Analysis:**
   - Alice backgrounds app
   - Bob sends 3 messages (including @mention)
   - Wait 2 minutes
   - Verify analysis triggered (logs)

4. **Notification Delivery:**
   - Alice receives notification
   - Notification shows correct text
   - Tap notification → deep links to conversation

5. **Provide Feedback:**
   - Tap "👍 Helpful" on notification
   - Verify feedback saved to Firestore

6. **Check History:**
   - Open Notification History
   - See notification logged
   - Feedback recorded

**Expected Results:**
- [ ] All steps complete without errors
- [ ] Each component works as expected
- [ ] Data flows correctly: Client → Cloud Functions → Firestore → Client

**Actual Results:**
```
[Write observations here]
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

### Test INT-2: Multi-Conversation Scenario

**Objective:** Verify smart notifications work across multiple conversations.

**Steps:**
1. Alice has 3 active conversations:
   - Conversation A with Bob (work project)
   - Conversation B with Charlie (social)
   - Conversation C with Dana (urgent tasks)

2. Send messages across all 3:
   - Bob: "Hey Alice, project update" (general)
   - Charlie: "Lunch tomorrow?" (social)
   - Dana: "@Alice URGENT: Client escalation" (urgent)

3. Wait 2 minutes after each
4. Check which notifications Alice receives

**Expected Results:**
- [ ] Conversation A (Bob): NO notification (general update)
- [ ] Conversation B (Charlie): NO notification (social)
- [ ] Conversation C (Dana): YES notification (urgent @mention)
- [ ] Only 1 notification delivered (correct prioritization)

**Actual Results:**
```
[Write observations here]
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

### Test INT-3: RAG Context Influence

**Objective:** Verify RAG context influences notification decision.

**Steps:**
1. **Setup Historical Context:**
   - Bob previously sent: "Alice, remember to review API designs on Fridays" (3 days ago)
   - Alice replied: "Will do" (3 days ago)

2. **Current Scenario:**
   - Today is Friday
   - Bob sends: "API design ready for review"
   - No @mention, no urgent keyword

3. Wait 2 minutes
4. Check AI decision

**Expected Results:**
- [ ] AI considers historical context (Friday review pattern)
- [ ] AI decision: NOTIFY
- [ ] Reason includes: "User committed to Friday reviews" or similar context reference
- [ ] Alice receives notification

**Actual Results:**
```
[Write observations here]
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

### Test INT-4: Learned Preferences Application

**Objective:** Verify AI learns from feedback and adapts.

**Steps:**
1. **Collect Feedback:**
   - Alice marks 5 "lunch" notifications as "Not Helpful"
   - Alice marks 5 "API review" notifications as "Helpful"

2. **Trigger Profile Update:**
   - Manually run weekly profile update job
   - Verify profile shows:
     - `suppressedTopics: ["lunch"]`
     - `learnedKeywords: ["API", "review"]`

3. **Test Adaptation:**
   - Bob sends: "Team lunch at 12?" → NO notification expected
   - Bob sends: "API review needed" → YES notification expected

4. Check results

**Expected Results:**
- [ ] Profile updated correctly
- [ ] Future "lunch" messages suppressed
- [ ] Future "API review" messages prioritized
- [ ] Alice receives only relevant notification

**Actual Results:**
```
[Write observations here]
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

## Performance Tests

### Test PERF-1: Analysis Latency

**Objective:** Measure end-to-end analysis time.

**Steps:**
1. Trigger analysis (send messages, wait 2 min)
2. Record timestamp from logs:
   - Start: `"[ConversationActivityMonitor] Triggering analysis"`
   - End: `"[AI] Analysis completed"`
3. Calculate latency

**Expected Results:**
- [ ] First analysis (cache miss): < 8 seconds
- [ ] Subsequent analysis (cache hit): < 1 second
- [ ] RAG context retrieval: < 2 seconds
- [ ] LLM call: < 5 seconds

**Actual Results:**
```
Cache miss: _____ seconds
Cache hit: _____ seconds
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

### Test PERF-2: Cache Hit Rate

**Objective:** Measure cache effectiveness.

**Steps:**
1. Trigger 10 analyses throughout the day
2. Check Cloud Function logs for cache hits vs misses
3. Calculate cache hit rate

**Expected Results:**
- [ ] Cache hit rate: > 60%
- [ ] Cost savings: ~70% reduction on cached analyses

**Actual Results:**
```
Total analyses: 10
Cache hits: _____
Cache hit rate: _____%
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

### Test PERF-3: Monitor Overhead

**Objective:** Verify activity monitor adds minimal overhead to message handling.

**Steps:**
1. Send 100 messages rapidly (within 1 minute)
2. Measure time from message sent to message displayed
3. Check for UI lag or delays

**Expected Results:**
- [ ] Monitor overhead: < 50ms per message
- [ ] No visible UI lag
- [ ] Messages appear immediately
- [ ] No frame drops in UI

**Actual Results:**
```
[Write observations here]
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

## Regression Tests (Epic Dependencies)

### Test REG-1: Story 2.10 Push Notifications Still Work

**Objective:** Verify traditional push notifications still function when smart notifications disabled.

**Steps:**
1. Alice disables smart notifications (Story 6.4.8)
2. Bob sends message to Alice
3. Check if Alice receives notification

**Expected Results:**
- [ ] Traditional notification flow activates
- [ ] Alice receives notification for EVERY message
- [ ] No AI analysis triggered

**Actual Results:**
```
[Write observations here]
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

### Test REG-2: Epic 3 AI Summaries Unaffected

**Objective:** Verify thread summarization still works independently.

**Steps:**
1. Open conversation with summary feature
2. Trigger summary generation
3. Verify summary displays

**Expected Results:**
- [ ] Summaries work normally
- [ ] No interference from Epic 6 features
- [ ] Separate caching for summaries

**Actual Results:**
```
[Write observations here]
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

## Security & Privacy Tests

### Test SEC-1: Authentication Required

**Objective:** Verify Cloud Function requires authentication.

**Steps:**
1. Attempt to call `analyzeForNotification` Cloud Function without Firebase Auth token
2. Check response

**Expected Results:**
- [ ] Function returns 401 Unauthorized
- [ ] Error message: "User must be authenticated"
- [ ] No analysis performed

**Actual Results:**
```
[Write observations here]
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

### Test SEC-2: Participant Validation

**Objective:** Verify users can only analyze conversations they participate in.

**Steps:**
1. Alice is participant in Conversation A
2. Attempt to trigger analysis on Conversation B (Alice is NOT participant)
3. Check Cloud Function response

**Expected Results:**
- [ ] Function returns 403 Forbidden
- [ ] Error message: "User not a participant in conversation"
- [ ] No analysis performed

**Actual Results:**
```
[Write observations here]
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

### Test SEC-3: Message Content Not Stored Long-Term

**Objective:** Verify message text is NOT stored in AI cache or analytics.

**Steps:**
1. Send sensitive message: "Alice, the API key is sk-test123"
2. Trigger analysis
3. Check Firestore collections:
   - `ai_notification_cache`
   - `notification_decisions`
   - `notification_feedback`
   - `users/{userId}/ai_notification_profile`

**Expected Results:**
- [ ] NO message text stored in any collection
- [ ] Only metadata stored (decision, priority, reasoning)
- [ ] Message embeddings are mathematical vectors (not text)

**Actual Results:**
```
[Write observations here]
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

## Error Handling & Edge Cases

### Test ERR-1: OpenAI API Timeout

**Objective:** Verify graceful handling of LLM timeout.

**Steps:**
1. Simulate slow OpenAI response (if possible via mock)
2. OR trigger analysis and observe timeout behavior
3. Check fallback activation

**Expected Results:**
- [ ] After 10 seconds: Function logs timeout
- [ ] Fallback heuristics activate
- [ ] User receives notification based on fallback logic
- [ ] Error logged but not exposed to user

**Actual Results:**
```
[Write observations here]
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

### Test ERR-2: Malformed AI Response

**Objective:** Verify handling of invalid JSON from LLM.

**Steps:**
1. Trigger analysis
2. Monitor Cloud Function logs for JSON parsing
3. Check for retry logic if malformed response occurs

**Expected Results:**
- [ ] If malformed JSON: Function logs error
- [ ] Retry once with modified prompt
- [ ] If retry fails: Fall back to heuristics
- [ ] No crash or unhandled exception

**Actual Results:**
```
[Write observations here]
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

### Test ERR-3: No Unread Messages

**Objective:** Verify handling when no unread messages exist.

**Steps:**
1. Alice has read all messages in conversation
2. Manually trigger analysis (if possible)
3. Check logs

**Expected Results:**
- [ ] Function logs: `"[AI] No unread messages, skipping analysis"`
- [ ] NO OpenAI API call
- [ ] NO notification sent
- [ ] Function completes gracefully

**Actual Results:**
```
[Write observations here]
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

### Test ERR-4: Conversation Deleted

**Objective:** Verify handling when conversation no longer exists.

**Steps:**
1. Trigger analysis on conversation
2. Delete conversation from Firestore DURING analysis
3. Check error handling

**Expected Results:**
- [ ] Function detects conversation missing
- [ ] Logs error: `"[AI] Conversation not found"`
- [ ] NO crash
- [ ] Analysis aborted gracefully

**Actual Results:**
```
[Write observations here]
```

**Status:** ☐ PASS ☐ FAIL ☐ BLOCKED

---

## Test Summary

**Total Tests:** 80+
**Tests Passed:** _____
**Tests Failed:** _____
**Tests Blocked:** _____
**Pass Rate:** _____%

### Critical Issues Found

1. **Issue ID:** _____
   **Severity:** High / Medium / Low
   **Description:** _____
   **Steps to Reproduce:** _____
   **Expected vs Actual:** _____

2. **Issue ID:** _____
   **Severity:** High / Medium / Low
   **Description:** _____

3. *(Add more as needed)*

---

### Blocker Issues (Prevent Release)

- [ ] None
- [ ] List blockers here

---

### Recommendations

☐ **PASS** - Epic 6 ready for release
☐ **PASS WITH MINOR ISSUES** - Release with known issues documented
☐ **FAIL** - Critical issues must be fixed before release

**Tester Signature:** _______________
**Date:** _______________

---

## Notes & Observations

```
[Write any additional observations, edge cases discovered, or suggestions here]
```
