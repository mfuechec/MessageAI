# Manual Testing Guide - Epic 6 AI Notification Optimizations

**Version:** 1.0
**Date:** 2025-01-24
**Environment:** Dev (`messageai-dev-1f2ec`)
**Status:** Ready for Testing

---

## Overview

This document provides comprehensive manual testing steps for the AI notification optimization implementation, organized by phase. All changes have been deployed to the dev environment.

**Deployed Functions:**
- ✅ `analyzeForNotification` - Updated with heuristic filter & GPT-4o-mini
- ✅ `embedMessageOnCreate` - New Firestore trigger for async embeddings
- ✅ `updateUserNotificationProfileScheduled` - New scheduled function (weekly)
- ✅ `updateUserNotificationProfileManual` - New callable function
- ✅ `submitNotificationFeedback` - Updated to handle decision parameter

---

## Test Account Setup

**Prerequisites:**
- Two test accounts (for sender/receiver testing)
- iOS device or simulator with dev build installed
- Access to Firebase Console for dev project
- Firebase Emulator (optional, for local testing)

**Test Accounts:**
```
Account 1 (Tester):
Email: tester1@example.com
Password: [Use secure test password]

Account 2 (Partner):
Email: tester2@example.com
Password: [Use secure test password]
```

---

## Phase 0: Critical Bug Fixes

### Bug #1: Feedback Submission with Decision Parameter

**What Changed:**
Fixed feedback submission to include the complete notification decision object.

**Test Steps:**

1. **Setup:**
   - Sign in as Account 1
   - Navigate to Settings → Notification History
   - Ensure you have at least 1 notification decision in history

2. **Test Feedback Submission:**
   - Tap on a notification entry
   - Tap "👍 Helpful" button
   - **Expected:** Success message appears
   - **Expected:** Entry updates to show "Helpful" feedback

3. **Verify in Firebase Console:**
   ```
   Navigate to: Firestore → notification_feedback collection
   Find document: {userId}_{conversationId}_{messageId}

   Expected fields:
   - userId: "user123"
   - conversationId: "conv456"
   - messageId: "msg789"
   - feedback: "helpful"
   - decision: {
       shouldNotify: true/false,
       reason: "...",
       notificationText: "...",
       priority: "high/medium/low"
     }
   - timestamp: (server timestamp)
   ```

4. **Test "Not Helpful" Feedback:**
   - Repeat steps 2-3 with "👎 Not Helpful" button
   - Verify feedback changes to "not_helpful"

**Success Criteria:**
- ✅ Feedback submission completes without errors
- ✅ Decision object stored in Firestore
- ✅ UI updates to reflect submitted feedback

---

### Bug #2: User Profile Document ID Mismatch

**What Changed:**
Fixed document ID from "default" to "profile" so learned preferences load correctly.

**Test Steps:**

1. **Create Test Feedback:**
   - Submit 5+ "helpful" feedbacks (from Bug #1 test)
   - Submit 2+ "not helpful" feedbacks

2. **Manually Trigger Profile Update:**
   ```bash
   # Option A: Call function via Firebase Console
   # Navigate to: Functions → updateUserNotificationProfileManual
   # Click "Run" with empty data object

   # Option B: Call from iOS app (if implemented)
   # Settings → Notification Preferences → "Update Profile Now"
   ```

3. **Verify Profile Created in Firestore:**
   ```
   Navigate to: Firestore → users/{userId}/ai_notification_profile/profile

   Expected fields:
   - preferredNotificationRate: "high" | "medium" | "low"
   - learnedKeywords: ["urgent", "meeting", ...]
   - suppressedTopics: ["social", "emoji", ...]
   - accuracy: 0.71 (example: 5/7 = 71%)
   - totalFeedback: 7
   - helpfulCount: 5
   - notHelpfulCount: 2
   - lastUpdated: (server timestamp)
   ```

4. **Test Profile Loading in Analysis:**
   - Send a test message that should trigger notification
   - Check Cloud Function logs:
   ```bash
   firebase functions:log --only analyzeForNotification --project messageai-dev-1f2ec

   Expected log:
   "[analyzeForNotification] Loaded user profile: {preferredNotificationRate: 'high', ...}"
   ```

**Success Criteria:**
- ✅ Profile document created at correct path: `users/{userId}/ai_notification_profile/profile`
- ✅ Profile contains learned preferences from feedback
- ✅ Analysis function loads profile correctly

---

### Bug #3: Scheduled Profile Updates

**What Changed:**
Added Cloud Scheduler trigger to auto-update profiles weekly (Monday 00:00 UTC).

**Test Steps:**

1. **Verify Scheduled Function Exists:**
   ```bash
   firebase functions:list --project messageai-dev-1f2ec | grep updateUserNotificationProfileScheduled

   Expected output:
   updateUserNotificationProfileScheduled(us-central1)
   ```

2. **Check Cloud Scheduler Configuration:**
   ```
   Navigate to: Firebase Console → Functions → updateUserNotificationProfileScheduled

   Expected:
   - Trigger: Cloud Scheduler
   - Schedule: "0 0 * * 1" (every Monday at midnight UTC)
   - Memory: 1GB
   - Timeout: 540 seconds
   ```

3. **Test Manual Trigger (Immediate):**
   ```bash
   # Call the manual version
   firebase functions:call updateUserNotificationProfileManual --project messageai-dev-1f2ec

   Expected response:
   {
     "success": true,
     "message": "Profile updated successfully"
   }
   ```

4. **Monitor Next Scheduled Run:**
   - Wait until next Monday 00:00 UTC
   - Check Cloud Function logs:
   ```bash
   firebase functions:log --only updateUserNotificationProfileScheduled --project messageai-dev-1f2ec --limit 10

   Expected log pattern:
   "[Scheduled] Starting weekly profile update"
   "[Scheduled] Updating X users with feedback"
   "[Scheduled] Updated X/X user profiles"
   ```

**Success Criteria:**
- ✅ Scheduled function deploys successfully
- ✅ Manual function callable and updates profile
- ✅ Scheduled function runs automatically on Monday 00:00 UTC

---

## Phase 1: Quick Wins - Performance Optimizations

### Optimization #1: GPT-4o-mini Model Switch

**What Changed:**
Switched from `gpt-4-turbo` to `gpt-4o-mini` for 10x speed improvement and 15x cost reduction.

**Test Steps:**

1. **Baseline Measurement (Before):**
   - If you have old logs, note previous analysis times
   - Typical: 5-10 seconds total, 2-5 seconds LLM call

2. **Send Test Message Requiring LLM:**
   - Account 2 sends: "What do you think about the new feature proposal?"
   - This is ambiguous (not a direct mention), so requires LLM
   - Account 1 should be backgrounded

3. **Measure New Latency:**
   ```bash
   firebase functions:log --only analyzeForNotification --project messageai-dev-1f2ec --limit 5

   Look for:
   "[analyzeForNotification] 🤖 LLM PATH: Requires AI analysis"
   "[analyzeForNotification] Total analysis time: XXXms"

   Expected: <2000ms total (vs 5-10 seconds before)
   ```

4. **Verify Model Used:**
   ```bash
   # Check OpenAI service logs
   firebase functions:log --only analyzeForNotification --project messageai-dev-1f2ec

   Expected: No explicit model log, but latency confirms gpt-4o-mini
   ```

5. **Test Accuracy:**
   - Send 10 different test messages (mix of important/unimportant)
   - Verify notification decisions are still accurate
   - Expected accuracy: 85-90% (slight drop from 95% is acceptable)

**Success Criteria:**
- ✅ LLM analysis completes in <2 seconds (down from 5-10 seconds)
- ✅ Notification decisions remain reasonably accurate (>85%)
- ✅ No errors in Cloud Function logs

---

### Optimization #2: Fast Heuristic Pre-Filter

**What Changed:**
Added rule-based filtering to skip LLM for 70% of messages (direct mentions, acknowledgments, etc.).

**Test Steps:**

1. **Test DEFINITELY_NOTIFY Cases:**

   a) **Direct @mention:**
   ```
   Account 2 sends: "@[Account1Name] can you review this?"
   Expected: Instant notification (<100ms)
   Log: "⚡ FAST PATH: Notify (Direct @mention)"
   ```

   b) **Name mention:**
   ```
   Account 2 sends: "Hey [Account1Name], are you available?"
   Expected: Instant notification
   Log: "⚡ FAST PATH: Notify (User mentioned by name)"
   ```

   c) **Urgent keyword:**
   ```
   Account 2 sends: "URGENT: Production is down!"
   Expected: Instant notification
   Log: "⚡ FAST PATH: Notify (Urgent keyword detected)"
   ```

   d) **Direct question:**
   ```
   Account 2 sends: "Can you help me with this?"
   Expected: Instant notification
   Log: "⚡ FAST PATH: Notify (Direct question detected)"
   ```

   e) **Task assignment:**
   ```
   Account 2 sends: "This task is assigned to you"
   Expected: Instant notification
   Log: "⚡ FAST PATH: Notify (Task assignment detected)"
   ```

2. **Test DEFINITELY_SKIP Cases:**

   a) **Short acknowledgment:**
   ```
   Account 2 sends: "ok"
   Expected: No notification
   Log: "⚡ FAST PATH: Skip (Common acknowledgment/reaction)"
   ```

   b) **Emoji only:**
   ```
   Account 2 sends: "👍"
   Expected: No notification
   Log: "⚡ FAST PATH: Skip (Emoji-only message)"
   ```

   c) **Very short:**
   ```
   Account 2 sends: "k"
   Expected: No notification
   Log: "⚡ FAST PATH: Skip (Message too short)"
   ```

3. **Test NEED_LLM Cases:**

   ```
   Account 2 sends: "I think we should consider refactoring the authentication module for better maintainability"
   Expected: Goes to LLM for analysis (3-5 second delay)
   Log: "🤖 LLM PATH: Requires AI analysis"
   ```

4. **Measure Skip Rate:**
   ```bash
   # After 20+ test messages, check logs
   firebase functions:log --only analyzeForNotification --project messageai-dev-1f2ec --limit 50

   Count instances of:
   - "⚡ FAST PATH:" (should be ~70%)
   - "🤖 LLM PATH:" (should be ~30%)
   ```

5. **Verify Decision Logging:**
   ```
   Navigate to: Firestore → notification_decisions

   For fast path decisions, verify:
   - reason: "Direct @mention" | "Common acknowledgment/reaction" | etc.
   - priority: "high" | "low" (matches heuristic)
   - timestamp: (logged even for fast path)
   ```

**Success Criteria:**
- ✅ 70%+ of messages use fast path (<100ms)
- ✅ Direct mentions always notify instantly
- ✅ Acknowledgments always skip instantly
- ✅ Ambiguous messages go to LLM
- ✅ All decisions logged correctly

---

### Optimization #3: Denormalized Sender Names

**What Changed:**
Sender's displayName is now stored in message document to eliminate N+1 queries.

**Test Steps:**

1. **Send New Message:**
   ```
   Account 2 sends: "Testing denormalized sender name"
   ```

2. **Verify Sender Name Stored:**
   ```
   Navigate to: Firestore → messages → (newest message)

   Expected fields:
   - senderId: "user123"
   - senderName: "Account 2 Display Name"  ← NEW FIELD
   - text: "Testing denormalized sender name"
   - timestamp: (server timestamp)
   ```

3. **Check Old Messages:**
   ```
   Navigate to: Firestore → messages → (old message from before deployment)

   Expected:
   - senderName: (field doesn't exist) ← This is OK
   ```

4. **Test Notification with New Message:**
   ```
   Account 2 sends: "@Account1Name urgent bug"

   Check Cloud Function logs:
   "[analyzeForNotification] ⚡ FAST PATH: Notify (Direct @mention)"

   Expected: No "Error fetching sender" logs
   Expected: Notification text includes correct sender name
   ```

5. **Verify Old Messages Still Work:**
   ```
   # Trigger analysis on conversation with old messages (without senderName)

   Check logs:
   Expected: Falls back to "Unknown" for old messages
   Expected: No errors, analysis completes successfully
   ```

6. **Measure Performance Impact:**
   ```bash
   firebase functions:log --only analyzeForNotification --project messageai-dev-1f2ec

   For conversations with 30 messages:
   Before: 30 * 50ms = 1,500ms (N+1 queries)
   After: 0ms (data already in message)

   Look for improved "FORMAT MESSAGES FOR LLM" timing
   ```

**Success Criteria:**
- ✅ New messages include `senderName` field
- ✅ Old messages (without `senderName`) still work with "Unknown" fallback
- ✅ No "Error fetching sender" logs
- ✅ Message formatting step completes faster

---

## Phase 2: Architectural Improvements

### Optimization #4: Pre-computed Embeddings (Async)

**What Changed:**
New Firestore trigger generates embeddings when messages are created, eliminating on-demand embedding generation.

**Test Steps:**

1. **Send New Message:**
   ```
   Account 2 sends: "This message should get embedded automatically"
   ```

2. **Wait 5 Seconds (for trigger to complete):**
   ```
   The embedMessageOnCreate trigger runs asynchronously
   ```

3. **Verify Embedding Created:**
   ```
   Navigate to: Firestore → messages → (newest message)

   Expected fields:
   - embedding: [0.123, -0.456, 0.789, ...] ← NEW FIELD (1536 numbers)
   - embeddedAt: (server timestamp) ← NEW FIELD
   - text: "This message should get embedded automatically"
   ```

4. **Check Trigger Logs:**
   ```bash
   firebase functions:log --only embedMessageOnCreate --project messageai-dev-1f2ec --limit 10

   Expected logs:
   "[embedMessageOnCreate] Generating embedding for message msg123"
   "[embedMessageOnCreate] ✅ Embedded message msg123"
   ```

5. **Test Empty Messages (Should Skip):**
   ```
   Account 2 sends: "" (empty)

   Expected log:
   "[embedMessageOnCreate] Skipping empty message msg456"

   Firestore: No embedding field added
   ```

6. **Test RAG Indexing (Check Fallback):**
   ```bash
   # Trigger notification analysis on conversation
   Account 2 sends: "@Account1Name test"

   Check logs:
   "[indexRecentMessages] Embedding 0 old messages (fallback)"
   ← Should be 0 because all new messages already have embeddings
   ```

7. **Test Old Messages (Fallback Path):**
   ```
   # Messages sent before deployment don't have embeddings
   # Trigger analysis on conversation with old messages

   Expected log:
   "[indexRecentMessages] Embedding X old messages (fallback)"
   ← X = number of old messages without embeddings
   ```

8. **Measure Performance Impact:**
   ```bash
   # After all messages have embeddings (1 week migration period)

   Before: 1-2 seconds for RAG indexing (generate embeddings on-demand)
   After: 0ms (embeddings already exist)

   Check "INDEX MESSAGES FOR RAG" timing in logs
   ```

**Success Criteria:**
- ✅ New messages automatically get `embedding` and `embeddedAt` fields
- ✅ Empty messages skip embedding generation
- ✅ Old messages fall back to on-demand embedding
- ✅ RAG indexing becomes instant for new messages

---

## End-to-End Integration Tests

### Test Case 1: Complete Notification Flow (Fast Path)

**Scenario:** Direct mention triggers instant notification

1. **Setup:**
   - Account 1 (receiver) puts app in background
   - Account 2 (sender) ready to send message

2. **Action:**
   ```
   Account 2 sends: "@Account1Name urgent: server is down!"
   ```

3. **Expected Flow:**
   ```
   [0-50ms]   Firestore onCreate trigger: embedMessageOnCreate starts (async, doesn't block)
   [0-100ms]  Fast heuristic filter: DEFINITELY_NOTIFY (urgent + mention)
   [0-100ms]  Log decision to notification_decisions
   [0-200ms]  Send FCM notification
   [0-200ms]  Return decision

   [5s later] embedMessageOnCreate completes (async)
   ```

4. **Verify:**
   - ✅ Notification appears on Account 1's device within 1 second
   - ✅ Notification text: "Account 2: @Account1Name urgent: server is down!"
   - ✅ Priority: High
   - ✅ Cloud Function logs show fast path
   - ✅ Total time: <500ms
   - ✅ Embedding created within 5 seconds (async)

---

### Test Case 2: Complete Notification Flow (LLM Path)

**Scenario:** Ambiguous message requires AI analysis

1. **Setup:**
   - Account 1 (receiver) puts app in background
   - Account 2 (sender) ready to send message

2. **Action:**
   ```
   Account 2 sends: "I've been thinking about the architecture changes we discussed last week. What are your thoughts on implementing the new caching layer?"
   ```

3. **Expected Flow:**
   ```
   [0-50ms]   Fast heuristic filter: NEED_LLM (ambiguous message)
   [0-100ms]  Load user context (RAG)
   [0-200ms]  Semantic search for relevant past messages
   [0-500ms]  Call GPT-4o-mini for analysis
   [0-500ms]  Receive decision from LLM
   [0-600ms]  Log decision
   [0-700ms]  Send FCM notification (if shouldNotify=true)
   [0-700ms]  Return decision
   ```

4. **Verify:**
   - ✅ Notification appears within 1 second (if decided to notify)
   - ✅ Notification includes context-aware text
   - ✅ Cloud Function logs show LLM path
   - ✅ Total time: <1 second
   - ✅ Decision reason is context-aware

---

### Test Case 3: Feedback Loop (End-to-End)

**Scenario:** User feedback improves future notifications

1. **Phase 1: Initial Notifications**
   ```
   Account 2 sends: "Team lunch at noon tomorrow"
   Expected: User receives notification (baseline)
   ```

2. **Phase 2: Submit Feedback**
   ```
   Account 1 navigates to: Settings → Notification History
   Finds "Team lunch" notification
   Taps: 👎 Not Helpful
   ```

3. **Phase 3: Manual Profile Update**
   ```bash
   # Trigger profile update
   firebase functions:call updateUserNotificationProfileManual --project messageai-dev-1f2ec
   ```

4. **Phase 4: Verify Profile Updated**
   ```
   Firestore → users/{userId}/ai_notification_profile/profile

   Expected:
   - suppressedTopics: ["lunch", "social", ...]
   - accuracy: (decreased due to "not helpful" feedback)
   ```

5. **Phase 5: Test Learned Preference**
   ```
   Account 2 sends: "Team lunch tomorrow at 1pm"
   Expected: Lower priority or no notification (learned preference)
   ```

6. **Verify:**
   - ✅ Feedback stored correctly
   - ✅ Profile updated with learned preferences
   - ✅ Future notifications respect learned preferences

---

## Performance Benchmarks

### Latency Targets

Run these benchmarks after completing all tests:

| Scenario | Target | How to Measure |
|----------|--------|----------------|
| Fast path (mention) | <100ms | Check Cloud Function logs for "⚡ FAST PATH" timing |
| Fast path (skip) | <100ms | Check Cloud Function logs for "⚡ FAST PATH" timing |
| LLM path | <1000ms | Check Cloud Function logs for "🤖 LLM PATH" timing |
| Embedding generation | <5s (async) | Check embedMessageOnCreate logs |
| Profile update | <60s | Check updateUserNotificationProfileManual logs |

### Cost Reduction Verification

**Before Optimization:**
- Cost per analysis: $0.015-0.020
- 100 analyses/day = $1.50-2.00/day

**After Optimization:**
- 70% fast path (free) = 70 analyses × $0 = $0
- 30% LLM path (GPT-4o-mini) = 30 × $0.001 = $0.03
- **Total: $0.03/day** (98% cost reduction!)

```bash
# Monitor OpenAI API usage
# Navigate to: OpenAI Dashboard → Usage

Before: ~100 gpt-4-turbo calls/day
After: ~30 gpt-4o-mini calls/day
```

---

## Troubleshooting

### Issue: Feedback Submission Fails

**Symptoms:** Error when tapping "Helpful" or "Not Helpful"

**Check:**
```bash
firebase functions:log --only submitNotificationFeedback --project messageai-dev-1f2ec --limit 10

Look for:
- "invalid-argument" errors
- "decision must be a valid NotificationDecision object"
```

**Solution:**
- Verify iOS app is using latest version
- Check that decision object is being passed
- Verify Firebase Functions deployed correctly

---

### Issue: Profile Not Loading

**Symptoms:** Analysis logs show "No profile found"

**Check:**
```
Firestore path: users/{userId}/ai_notification_profile/profile
Expected document ID: "profile" (NOT "default")
```

**Solution:**
- Run manual profile update: `firebase functions:call updateUserNotificationProfileManual`
- Verify feedback exists in `notification_feedback` collection
- Check Cloud Function logs for errors

---

### Issue: Embeddings Not Generated

**Symptoms:** New messages don't have `embedding` field

**Check:**
```bash
firebase functions:log --only embedMessageOnCreate --project messageai-dev-1f2ec --limit 10

Look for:
- "Generating embedding for message..."
- OpenAI API errors
- Rate limit errors
```

**Solution:**
- Verify OpenAI API key is configured
- Check OpenAI API quota/limits
- Verify Firestore trigger is enabled

---

### Issue: Fast Path Not Working

**Symptoms:** All messages go to LLM, none use fast path

**Check:**
```bash
firebase functions:log --only analyzeForNotification --project messageai-dev-1f2ec --limit 20

Look for:
- "Heuristic decision: NEED_LLM" for ALL messages
- Missing "⚡ FAST PATH" logs
```

**Solution:**
- Verify fast-heuristic-filter.ts deployed correctly
- Test with clear patterns: "@username", "ok", "🎉"
- Check for errors in heuristic logic

---

## Test Results Template

Use this template to document your testing:

```markdown
## Test Session: [Date]

**Tester:** [Name]
**Environment:** Dev (messageai-dev-1f2ec)
**Device:** [iOS Version, Device Model]

### Phase 0 Results
- [ ] Bug #1: Feedback Submission ✅ / ❌
- [ ] Bug #2: Profile Document ID ✅ / ❌
- [ ] Bug #3: Scheduled Updates ✅ / ❌

### Phase 1 Results
- [ ] Opt #1: GPT-4o-mini ✅ / ❌ | Latency: ___ms
- [ ] Opt #2: Heuristic Filter ✅ / ❌ | Skip rate: ___%
- [ ] Opt #3: Denormalized Names ✅ / ❌

### Phase 2 Results
- [ ] Opt #4: Async Embeddings ✅ / ❌

### Integration Tests
- [ ] E2E Test 1: Fast Path ✅ / ❌
- [ ] E2E Test 2: LLM Path ✅ / ❌
- [ ] E2E Test 3: Feedback Loop ✅ / ❌

### Issues Found
1. [Issue description]
2. [Issue description]

### Performance Benchmarks
| Metric | Target | Actual | Pass? |
|--------|--------|--------|-------|
| Fast path | <100ms | ___ms | ✅/❌ |
| LLM path | <1000ms | ___ms | ✅/❌ |
| Embeddings | <5s | ___s | ✅/❌ |

### Notes
[Additional observations, recommendations, etc.]
```

---

## Next Steps

After completing all manual tests:

1. **Document Results:**
   - Fill out test results template
   - Take screenshots of key verifications
   - Save Cloud Function logs for reference

2. **Monitor for 1 Week:**
   - Check daily for errors in Cloud Function logs
   - Monitor OpenAI API costs
   - Track user feedback on notification quality

3. **Production Deployment:**
   - If all tests pass, deploy to production:
   ```bash
   firebase deploy --only functions --project messageai-prod-4d3a8
   ```

4. **Production Monitoring:**
   - Set up alerts for function errors
   - Monitor OpenAI costs vs baseline
   - Track notification accuracy via feedback

---

## Contact

For questions or issues during testing:
- **Slack:** #messageai-dev
- **Documentation:** See `docs/architecture/ai-notification-optimization-plan.md`
- **Cloud Function Logs:** `firebase functions:log --project messageai-dev-1f2ec`

---

**Document Version:** 1.0
**Last Updated:** 2025-01-24
**Status:** ✅ Ready for Testing
