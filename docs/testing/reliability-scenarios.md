# Reliability Test Scenarios - MessageAI MVP

**Version:** 1.0
**Last Updated:** 2025-10-22 (Story 2.12)
**Purpose:** Validate app reliability under stress, poor network, and edge case scenarios

---

## Overview

This document defines 10 comprehensive reliability test scenarios to validate MessageAI's production readiness. Each scenario tests the app's behavior under challenging conditions that users may encounter in real-world usage.

**Test Environment:**
- **Simulator:** iPhone 17 Pro (iOS 17.0+)
- **Firebase:** Development environment (`messageai-dev-1f2ec`)
- **Network Tools:** Network Link Conditioner, Airplane Mode
- **Duration:** ~3-4 hours for all 10 scenarios

---

## Scenario Execution Template

Each scenario follows this structure:

### Scenario N: [Name]
**Objective:** [What this test validates]

**Setup:**
- Prerequisites and initial conditions
- Required tools or configurations

**Actions:**
1. Step-by-step instructions
2. Include specific data (counts, timings)
3. Note when to observe behavior

**Expected Result:**
- What should happen
- Success criteria
- Performance targets

**Actual Result:**
- ⏳ **Status:** Not yet executed
- **Findings:** [To be filled during execution]
- **Pass/Fail:** ⏳ Pending

**Evidence:**
- Screenshot file paths
- Console log excerpts
- Firestore query results

---

## Scenario 1: Message Loss During Network Instability

**Objective:** Verify zero message loss when network connection toggles repeatedly during message sending.

### Setup
- User A and User B accounts created in Firebase Auth
- Both users have active conversation
- iPhone 17 Pro Simulator
- Firebase Dev environment connected
- System Settings app accessible for airplane mode

### Actions
1. Sign in as User A
2. Open conversation with User B
3. Rapidly send 50 messages using this pattern:
   - Send 10 messages normally
   - Enable airplane mode (Settings → Airplane Mode ON)
   - Attempt to send 10 messages (should queue)
   - Disable airplane mode
   - Repeat pattern 5 times total
4. Wait 30 seconds for all messages to synchronize
5. Query Firestore console to count messages in conversation
6. Open conversation on User B's device to verify receipt

### Expected Result
- ✅ All 50 messages delivered to Firestore
- ✅ All 50 messages visible to User B
- ✅ Messages displayed in correct send order
- ✅ No duplicate messages
- ✅ Offline queue correctly handles queued messages
- ⏱️ All messages delivered within 2 minutes of connectivity restore

### Actual Result
- ⏳ **Status:** Not yet executed
- **Messages Sent:** [Count]
- **Messages Delivered:** [Count]
- **Messages Lost:** [Count]
- **Duplicates:** [Count]
- **Order Preserved:** [Yes/No]
- **Pass/Fail:** ⏳ Pending

### Evidence
- [ ] Screenshot: Firestore messages collection query
- [ ] Screenshot: User A's message list
- [ ] Screenshot: User B's message list
- [ ] Console logs: Message send attempts during offline periods

---

## Scenario 2: App Kill Mid-Send

**Objective:** Verify message completes sending after app is force-killed during transmission.

### Setup
- User A signed in
- Active conversation with User B
- Firebase Dev environment connected

### Actions
1. Sign in as User A
2. Open conversation with User B
3. Compose a long message (500+ characters)
4. Tap "Send" button
5. **Immediately** force-quit the app (swipe up from app switcher)
6. Wait 10 seconds
7. Re-launch the app
8. Check message status in conversation
9. Verify message appears for User B

### Expected Result
- ✅ Message is queued in offline queue or shows "sending" status
- ✅ On app restart, message automatically resumes sending
- ✅ Message successfully delivered within 10 seconds of restart
- ✅ User B receives the complete message
- ⏱️ Total time from app restart to delivery: < 15 seconds

### Actual Result
- ⏳ **Status:** Not yet executed
- **Message Queued:** [Yes/No]
- **Auto-Resume on Restart:** [Yes/No]
- **Message Delivered:** [Yes/No]
- **Delivery Time After Restart:** [X seconds]
- **Message Integrity:** [Complete/Truncated/Lost]
- **Pass/Fail:** ⏳ Pending

### Evidence
- [ ] Screenshot: Message status before kill
- [ ] Screenshot: Message status after app restart
- [ ] Screenshot: User B's received message
- [ ] Console logs: Offline queue behavior

---

## Scenario 3: Edit-Unsend Flow

**Objective:** Verify message edit history and unsend functionality work correctly through multiple operations.

### Setup
- User A and User B in active conversation
- Both users viewing conversation in real-time

### Actions
1. User A sends message: "Original message"
2. Wait 5 seconds, verify User B sees it
3. User A edits message to: "First edit"
4. Wait 5 seconds, verify User B sees edited version with "(edited)" badge
5. User A edits message to: "Second edit"
6. Wait 5 seconds, verify User B sees updated version
7. User A edits message to: "Third edit"
8. Wait 5 seconds, verify User B sees final version
9. User A taps "View Edit History" - verify 4 versions shown
10. User A unsends the message
11. Wait 5 seconds, verify both users see "Message deleted" placeholder

### Expected Result
- ✅ All 3 edits delivered to User B in real-time
- ✅ "(edited)" badge appears after first edit
- ✅ Edit history shows all 4 versions (original + 3 edits)
- ✅ Edit history includes timestamps
- ✅ Unsend replaces message with "Message deleted" for both users
- ✅ Edit history still accessible after unsend (for User A only)
- ⏱️ Each edit delivers within 2 seconds

### Actual Result
- ⏳ **Status:** Not yet executed
- **Edit 1 Delivered:** [Yes/No, Xsec]
- **Edit 2 Delivered:** [Yes/No, Xsec]
- **Edit 3 Delivered:** [Yes/No, Xsec]
- **Edit Badge Shown:** [Yes/No]
- **Edit History Complete:** [Yes/No]
- **Unsend Successful:** [Yes/No]
- **Final State Correct:** [Yes/No]
- **Pass/Fail:** ⏳ Pending

### Evidence
- [ ] Screenshot: Original message
- [ ] Screenshot: Message after edit 3 with "(edited)" badge
- [ ] Screenshot: Edit history modal
- [ ] Screenshot: "Message deleted" placeholder
- [ ] Video: Real-time edit delivery (optional)

---

## Scenario 4: Group Chat Stress Test

**Objective:** Verify system handles simultaneous message sending in group chat with 10 participants.

### Setup
- Create 10 test user accounts (User A through User J)
- Create group conversation with all 10 users
- Sign in on 10 separate simulator instances OR coordinate with testers
- Ensure Firebase Dev environment can handle concurrent writes

### Actions
1. All 10 users join the same group conversation
2. On a countdown, all 10 users simultaneously send message: "Test message from [UserName]"
3. Repeat step 2 five times (50 total messages)
4. Wait 30 seconds for all messages to settle
5. Each user checks their message list
6. Count total messages received by each user

### Expected Result
- ✅ All 50 messages delivered to all participants
- ✅ No messages lost or duplicated
- ✅ Messages may arrive out of order (acceptable)
- ✅ Conversation remains stable (no crashes)
- ✅ All users see consistent final state
- ⏱️ All messages delivered within 1 minute

### Actual Result
- ⏳ **Status:** Not yet executed
- **Messages Sent:** [50]
- **Messages Received (User A):** [Count]
- **Messages Received (User B):** [Count]
- **...** [All users]
- **Duplicates:** [Count]
- **Lost Messages:** [Count]
- **App Crashes:** [Count]
- **Pass/Fail:** ⏳ Pending

### Evidence
- [ ] Screenshot: Final message list (one representative user)
- [ ] Screenshot: Firestore messages count query
- [ ] Console logs: Concurrent write handling

---

## Scenario 5: Offline Queue Order Validation

**Objective:** Verify offline message queue maintains correct send order when sent as batch.

### Setup
- User A signed in
- Conversation with User B open
- Network connectivity available

### Actions
1. Enable airplane mode (Settings → Airplane Mode ON)
2. Compose and "send" 20 messages with distinct content:
   - Message 1: "First message"
   - Message 2: "Second message"
   - ... (continue pattern)
   - Message 20: "Twentieth message"
3. Verify all 20 messages appear in offline queue with "Queued" status
4. Open offline queue review screen
5. Verify messages listed in correct order (1-20)
6. Disable airplane mode
7. Tap "Send All" button
8. Wait for all messages to send
9. Verify messages appear in conversation in correct order
10. Check User B's conversation to verify order

### Expected Result
- ✅ All 20 messages queued offline in correct order
- ✅ Offline queue UI shows accurate count and preview
- ✅ "Send All" successfully transmits all 20 messages
- ✅ Messages delivered to conversation in original compose order
- ✅ User B receives all 20 messages in correct sequence
- ⏱️ All messages sent within 30 seconds of going online

### Actual Result
- ⏳ **Status:** Not yet executed
- **Messages Queued:** [Count]
- **Queue Order Correct:** [Yes/No]
- **Messages Delivered:** [Count]
- **Delivery Order Correct:** [Yes/No]
- **User B Order Correct:** [Yes/No]
- **Send Duration:** [X seconds]
- **Pass/Fail:** ⏳ Pending

### Evidence
- [ ] Screenshot: Offline queue with 20 messages
- [ ] Screenshot: Final conversation list
- [ ] Screenshot: User B's received messages
- [ ] Console logs: Batch send operations

---

## Scenario 6: Rapid-Fire Messaging

**Objective:** Verify system stability when sending 100 messages in < 30 seconds.

### Setup
- User A signed in
- Conversation with User B open
- Prepare script or rapid tapping method
- Monitor app memory usage (Xcode Debug Navigator)

### Actions
1. Open Xcode Debug Navigator to monitor memory
2. Open conversation with User B
3. Rapidly send 100 messages as fast as possible:
   - Use copy/paste for speed: "Rapid message [N]"
   - Aim to complete in < 30 seconds
4. Monitor for app crashes, memory leaks, or UI freezes
5. Wait 1 minute for all messages to sync
6. Verify all messages delivered to User B
7. Check final memory usage

### Expected Result
- ✅ App remains stable throughout rapid sending
- ✅ No crashes or UI freezes
- ✅ All 100 messages delivered successfully
- ✅ Memory usage remains under 200MB
- ✅ Optimistic UI shows all messages immediately
- ⏱️ All messages delivered within 2 minutes

### Actual Result
- ⏳ **Status:** Not yet executed
- **Messages Sent:** [Count]
- **Send Duration:** [X seconds]
- **Messages Delivered:** [Count]
- **App Crashes:** [Count]
- **UI Freezes:** [Yes/No]
- **Peak Memory Usage:** [X MB]
- **Final Memory Usage:** [X MB]
- **Pass/Fail:** ⏳ Pending

### Evidence
- [ ] Screenshot: Xcode memory graph during sending
- [ ] Screenshot: Final message count
- [ ] Video: Rapid message sending (optional)
- [ ] Console logs: Performance metrics

---

## Scenario 7: Background Push Notifications

**Objective:** Verify push notifications delivered correctly when app is backgrounded.

### Setup
- User A device with push notifications enabled
- User B sending messages
- Physical device OR simulator with APNs sandbox configured
- App fully backgrounded (not active)

### Actions
1. User A: Sign in, enable push notifications, then background the app (press home button)
2. Wait 5 minutes to ensure app is truly backgrounded
3. User B: Send 50 messages to User A over the course of 1 hour:
   - Send 10 messages immediately
   - Wait 10 minutes
   - Send 10 more messages
   - Repeat pattern until 50 messages sent
4. User A: Monitor for push notifications (should receive for each message)
5. After 1 hour, User A: Open app and check conversation
6. Verify all 50 messages displayed

### Expected Result
- ✅ User A receives push notification for each message (50 total)
- ✅ Notifications display correct message preview
- ✅ Tapping notification opens app to correct conversation
- ✅ All 50 messages visible when app reopened
- ✅ Unread count badge accurate
- ✅ No duplicate notifications

### Actual Result
- ⏳ **Status:** Not yet executed
- **Notifications Received:** [Count/50]
- **Notification Delivery Latency:** [X seconds average]
- **Notifications with Correct Preview:** [Count]
- **Messages Displayed After Open:** [Count]
- **Unread Badge Accurate:** [Yes/No]
- **Duplicate Notifications:** [Count]
- **Pass/Fail:** ⏳ Pending

### Evidence
- [ ] Screenshot: Notification on lock screen
- [ ] Screenshot: Multiple notification stack
- [ ] Screenshot: App after opening from notification
- [ ] Console logs: FCM token registration

---

## Scenario 8: Large Image Upload on 3G

**Objective:** Verify large image uploads complete successfully on slow network with retry capability.

### Setup
- User A signed in
- 10MB test image prepared (use sample PDF or high-res photo)
- Network Link Conditioner installed and configured to "3G" profile
- Conversation with User B open

### Actions
1. Open Network Link Conditioner system preferences
2. Enable "3G" network profile (slow upload: 80 Kbps)
3. User A: Open conversation with User B
4. Tap attachment button → Select 10MB image
5. Observe upload progress indicator
6. Monitor for upload timeout or failure
7. If failure occurs, tap retry
8. Wait for upload to complete (may take 5-10 minutes on 3G)
9. Verify image appears in conversation for User A
10. Verify User B receives and can view image
11. Disable Network Link Conditioner

### Expected Result
- ✅ Upload progress indicator displays during upload
- ✅ Upload completes successfully (or retries on failure)
- ✅ Image appears in conversation after upload
- ✅ User B can view full-resolution image
- ✅ App remains responsive during upload
- ⏱️ Upload completes within 15 minutes on 3G

### Actual Result
- ⏳ **Status:** Not yet executed
- **Upload Started:** [Yes/No]
- **Progress Indicator Shown:** [Yes/No]
- **Upload Completed:** [Yes/No]
- **Upload Duration:** [X minutes]
- **Retries Needed:** [Count]
- **Image Viewable (User A):** [Yes/No]
- **Image Viewable (User B):** [Yes/No]
- **App Responsive During Upload:** [Yes/No]
- **Pass/Fail:** ⏳ Pending

### Evidence
- [ ] Screenshot: Upload progress bar
- [ ] Screenshot: Uploaded image in conversation
- [ ] Screenshot: Network Link Conditioner settings
- [ ] Console logs: Upload retry attempts

---

## Scenario 9: Concurrent Message Editing

**Objective:** Verify conflict resolution when two users edit the same message simultaneously.

### Setup
- User A and User B in conversation
- Message sent by User A (editable by User A only in current design)
- NOTE: This scenario may need adjustment based on permission model

**Adjusted Scenario (User Edits Own Message Twice Quickly):**

### Actions
1. User A sends message: "Original message"
2. Wait 2 seconds
3. User A: Start editing message on Device 1
4. User A: Start editing SAME message on Device 2 (simulator + physical OR two simulators)
5. Device 1: Save edit → "Edit from Device 1"
6. Device 2: Save edit → "Edit from Device 2" (within 1 second of Device 1)
7. Wait 5 seconds for Firestore to resolve
8. Check both devices to see which edit won
9. Check Firestore console for edit history

### Expected Result
- ✅ Firestore "last write wins" resolves conflict
- ✅ Both devices eventually show same final state
- ✅ Edit history includes both edit attempts
- ✅ No data corruption or crashes
- ✅ User sees consistent state after refresh

### Actual Result
- ⏳ **Status:** Not yet executed
- **Concurrent Edits Attempted:** [Yes/No]
- **Conflict Resolution:** [Last write wins / Other]
- **Final State Device 1:** [Text]
- **Final State Device 2:** [Text]
- **States Consistent:** [Yes/No]
- **Edit History Complete:** [Yes/No]
- **Pass/Fail:** ⏳ Pending

### Evidence
- [ ] Screenshot: Device 1 final state
- [ ] Screenshot: Device 2 final state
- [ ] Screenshot: Edit history
- [ ] Screenshot: Firestore document state

---

## Scenario 10: Offline-Online Sync

**Objective:** Verify app correctly syncs when returning online after data changes occurred on server.

### Setup
- User A with active conversations
- User B has access to delete conversations via Firestore Console OR second device
- Offline cached data loaded on User A's device

### Actions
1. User A: Open app, load 10 conversations, ensure all cached locally
2. User A: Enable airplane mode
3. User A: While offline, navigate around app (view cached conversations)
4. User B: Using Firestore Console OR second device, delete 5 conversations that User A can see
5. Wait 2 minutes
6. User A: Disable airplane mode (go back online)
7. Wait 30 seconds for sync to occur
8. Observe conversation list on User A's device
9. Verify deleted conversations removed from list

### Expected Result
- ✅ User A sees 10 conversations while offline (cached)
- ✅ User A can view cached messages in those conversations
- ✅ When online, sync detects 5 conversations deleted
- ✅ Deleted conversations removed from User A's list
- ✅ Remaining 5 conversations still accessible
- ✅ No crashes or data corruption
- ⏱️ Sync completes within 1 minute of going online

### Actual Result
- ⏳ **Status:** Not yet executed
- **Offline Conversations Visible:** [Count]
- **Conversations Deleted by User B:** [Count]
- **Sync Detected Deletions:** [Yes/No]
- **Final Conversation Count:** [Count]
- **Remaining Conversations Accessible:** [Yes/No]
- **Sync Duration:** [X seconds]
- **Pass/Fail:** ⏳ Pending

### Evidence
- [ ] Screenshot: Conversation list before sync (10 conversations)
- [ ] Screenshot: Firestore console after deletions (5 conversations)
- [ ] Screenshot: Conversation list after sync (5 conversations)
- [ ] Console logs: Sync operations

---

## Test Execution Summary

### Scenario Results Overview

| Scenario | Status | Pass/Fail | Critical Issues | Notes |
|----------|--------|-----------|----------------|-------|
| 1. Network Instability | ⏳ Pending | - | - | - |
| 2. App Kill Mid-Send | ⏳ Pending | - | - | - |
| 3. Edit-Unsend Flow | ⏳ Pending | - | - | - |
| 4. Group Chat Stress | ⏳ Pending | - | - | - |
| 5. Offline Queue Order | ⏳ Pending | - | - | - |
| 6. Rapid-Fire Messaging | ⏳ Pending | - | - | - |
| 7. Push Notifications | ⏳ Pending | - | - | - |
| 8. 3G Image Upload | ⏳ Pending | - | - | - |
| 9. Concurrent Editing | ⏳ Pending | - | - | - |
| 10. Offline-Online Sync | ⏳ Pending | - | - | - |

### Overall Assessment

- **Scenarios Passed:** 0/10
- **Scenarios Failed:** 0/10
- **Scenarios Pending:** 10/10
- **Critical Issues Found:** 0
- **MVP Readiness:** ⏳ Pending manual execution

---

## Critical Issues Log

_No critical issues found yet - scenarios not yet executed._

### Issue Template

**Issue #N: [Title]**
- **Scenario:** [Which scenario revealed the issue]
- **Severity:** [Critical / High / Medium / Low]
- **Description:** [What happened]
- **Impact:** [User-facing impact]
- **Workaround:** [Temporary solution, if any]
- **Recommended Fix:** [How to resolve]
- **Status:** [Open / In Progress / Resolved]

---

## Testing Tips & Best Practices

### Before You Begin

1. **Use Clean Test Data:** Start with fresh Firebase data to avoid pollution
2. **Document Everything:** Take screenshots and notes in real-time
3. **Use Screen Recording:** Record complex scenarios for later review
4. **Monitor Console Logs:** Keep Xcode console open to catch errors
5. **Test on Physical Device:** For push notifications and realistic performance

### During Testing

- Be patient with slow network scenarios (Scenario 8)
- Use airplane mode consistently (Settings app, not Control Center)
- Give sufficient time for async operations to complete (30 seconds minimum)
- Verify from both sender and receiver perspectives

### After Testing

- Document all findings immediately while fresh
- File bugs for any failures in issue tracker
- Re-run failed scenarios after fixes
- Update this document with actual results

---

## Related Documentation

- [Regression Test Suite](./regression-test-suite.md) - Complete test mapping
- [Coverage Report](./coverage-report.md) - Automated test results
- [Performance Benchmarks](./performance-benchmarks.md) - Performance validation
- [Testing Strategy](../architecture/testing-strategy.md) - Testing workflow

---

## Change Log

| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2025-10-22 | 1.0 | Initial reliability scenarios defined (awaiting manual execution) | James (Dev) |

---

**Status:** 📋 Documentation Complete - Awaiting Manual Execution
**Total Estimated Time:** 3-4 hours
**Recommended Tester:** QA Engineer or Project Lead
