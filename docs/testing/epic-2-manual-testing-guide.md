# Epic 2: Advanced Messaging Features - Manual Testing Guide

**Version:** 1.0
**Last Updated:** 2025-10-22
**Epic Status:** In Progress
**Total Stories:** 12 (2.0 - 2.11)

---

## Overview

This guide provides comprehensive manual testing procedures for Epic 2: Advanced Messaging Features. Epic 2 builds upon the core messaging infrastructure from Epic 1, adding group chats, message editing, attachments, offline support, and push notifications.

### Epic 2 Feature Summary

| Story | Feature | Status |
|-------|---------|--------|
| 2.0 | Start New Conversation with Duplicate Prevention | Done |
| 2.1 | Group Chat Functionality | Done |
| 2.2 | Message Editing with History | Done |
| 2.3 | Message Unsend (Delete for Everyone) | Done |
| 2.4 | Message Send Retry on Failure | Done |
| 2.5 | Read Receipts | Done |
| 2.6 | Typing Indicators | Ready for Review |
| 2.7 | Image Attachments | Done |
| 2.8 | Document Attachments (PDF) | Done |
| 2.9 | Offline Message Queue with Manual Send | Approved |
| 2.10 | Push Notifications | Done |
| 2.11 | Performance Optimization & Network Resilience | Done |

---

## Test Environment Setup

### Prerequisites

- **Devices:** Minimum 2 iOS devices/simulators (for testing real-time features)
- **Recommended:** 3 devices (for group chat testing)
- **iOS Version:** iOS 15.0 or higher
- **Network Tools:** Ability to toggle airplane mode, throttle network speed
- **Test Accounts:** Minimum 3 test user accounts (test1@messageai.dev, test2@messageai.dev, test3@messageai.dev)
- **Firebase Console Access:** For backend verification
- **Firebase Emulator:** Optional (for integration testing)

### Test Data Preparation

Before starting tests, ensure:
1. Test accounts created and verified
2. Sample conversations exist
3. Sample messages exist in various states (sent, read, edited, deleted)
4. Test images and PDFs available for attachment testing
5. Network throttling tools configured (Charles Proxy, Network Link Conditioner)

---

## Story 2.0: Start New Conversation with Duplicate Prevention

### Objective
Verify users can start new conversations without creating duplicates.

### Test Scenarios

#### Scenario 2.0.1: Create New One-on-One Conversation

**Steps:**
1. Launch app, sign in as test1@messageai.dev
2. Tap "New Message" button (+ icon) in conversations list nav bar
3. Verify user selection sheet opens
4. Verify current user (test1) NOT in user list
5. Verify all other users displayed with avatar, name, email
6. Search for "test2" by name
7. Verify search results filter correctly
8. Clear search, search by email "test2@messageai.dev"
9. Tap user test2@messageai.dev
10. Verify loading indicator shown briefly
11. Verify navigation to chat view with test2
12. Send a message: "Hello from test1"
13. Navigate back to conversations list
14. Verify conversation appears in list

**Expected Results:**
- ✓ "New Message" button visible and accessible
- ✓ User list loads with avatars and online status indicators
- ✓ Search filters by both name and email (case-insensitive)
- ✓ Conversation created and appears in list
- ✓ No error messages

#### Scenario 2.0.2: Duplicate Prevention

**Steps:**
1. From conversations list, tap "New Message" again
2. Select test2@messageai.dev (same user as before)
3. Verify app navigates to EXISTING conversation (not new one)
4. Verify previous message "Hello from test1" still visible
5. Verify no duplicate conversation created

**Expected Results:**
- ✓ Same conversation opened
- ✓ Only ONE conversation with test2 exists in list
- ✓ No error messages

**Verification in Firebase:**
- Open Firebase Console → Firestore → conversations
- Verify only ONE conversation exists with participantIds: [test1_uid, test2_uid]
- Verify participantIds are sorted alphabetically

#### Scenario 2.0.3: Offline Conversation Creation

**Steps:**
1. Enable Airplane Mode
2. Tap "New Message"
3. Select test3@messageai.dev (new user)
4. Verify offline banner shows
5. Verify conversation appears in list with "queued" indicator
6. Disable Airplane Mode
7. Wait 5 seconds
8. Verify conversation syncs to Firebase

**Expected Results:**
- ✓ Conversation created locally while offline
- ✓ Syncs when connection restored
- ✓ No data loss

#### Scenario 2.0.4: Edge Cases

**Test 1: Multiple rapid taps on "New Message"**
- Tap "New Message" button 5 times rapidly
- Select same user each time
- Verify only ONE conversation created

**Test 2: Self-conversation prevention**
- Attempt to create conversation with current user (should not be possible as current user filtered from list)
- Verify current user ID never appears in user selection list

---

## Story 2.1: Group Chat Functionality

### Objective
Verify group conversations work with 3+ participants, including multi-avatar display and participant management.

### Test Scenarios

#### Scenario 2.1.1: Create Group Conversation

**Steps:**
1. Sign in as test1@messageai.dev
2. Tap "New Message" button
3. Toggle to "Group" mode (toolbar button)
4. Verify UI changes to show checkboxes next to users
5. Select test2@messageai.dev and test3@messageai.dev (total 3 participants)
6. Verify "Create Group" button appears and shows "3 users selected"
7. Tap "Create Group"
8. Verify navigation to group chat view
9. Verify navigation title shows participant names: "test2, test3" or "3 people"
10. Send message: "Hello everyone!"
11. Navigate back to conversations list
12. Verify group conversation appears with 3-person triangular avatar layout

**Expected Results:**
- ✓ Multi-select mode works correctly
- ✓ "Create Group" button enabled when 3+ users selected
- ✓ Group conversation created successfully
- ✓ Group avatar shows triangular layout (2 top, 1 bottom)
- ✓ Navigation title shows participant names

#### Scenario 2.1.2: Group Message Distribution

**Steps:**
1. Device 1 (test1): Send message in group: "Message from test1"
2. Device 2 (test2): Open same group conversation
3. Device 3 (test3): Open same group conversation
4. Verify all 3 devices show the message within 2 seconds
5. On Device 2, send message: "Reply from test2"
6. Verify Device 1 and Device 3 receive message
7. Verify sender names shown for all messages in group (not just "You" vs "Them")

**Expected Results:**
- ✓ All participants receive messages in real-time
- ✓ Sender names displayed correctly
- ✓ Message order preserved across all devices

#### Scenario 2.1.3: Group Avatar Display

**Test with 2 participants:**
- Create conversation with 2 users
- Verify avatar shows side-by-side circular layout

**Test with 3 participants:**
- Create conversation with 3 users
- Verify avatar shows triangular layout (2 top, 1 bottom)

**Test with 4+ participants:**
- Create conversation with 4 users
- Verify avatar shows 2x2 grid layout
- Create conversation with 10 users (max)
- Verify avatar still shows 2x2 grid (first 4 participants)

**Expected Results:**
- ✓ Avatar layout changes based on participant count
- ✓ Avatars show profile photos or initials correctly
- ✓ No layout issues or overlapping

#### Scenario 2.1.4: Group Member List

**Steps:**
1. Open group conversation
2. Tap navigation title
3. Verify group member list modal opens
4. Verify all participants shown with:
   - Avatar (photo or initials)
   - Display name
   - Email
   - Online status indicator (green dot if online)
5. Tap "Done" button
6. Verify modal closes

**Expected Results:**
- ✓ Member list accessible via title tap
- ✓ All participant info displayed correctly
- ✓ Online status accurate

#### Scenario 2.1.5: Accessibility Testing

**Steps:**
1. Enable VoiceOver (Cmd+Shift+V in simulator)
2. Navigate to group conversation
3. Verify VoiceOver reads group avatar as "Group conversation with [names]"
4. Tap navigation title
5. Verify VoiceOver reads "Group members"
6. Navigate through member list
7. Verify each member announced with name, email, online status

**Expected Results:**
- ✓ All group UI elements have proper accessibility labels
- ✓ VoiceOver navigation works smoothly

---

## Story 2.2: Message Editing with History

### Objective
Verify users can edit their own messages with full edit history tracking.

### Test Scenarios

#### Scenario 2.2.1: Edit Message (Basic)

**Steps:**
1. Sign in as test1@messageai.dev
2. Open conversation with test2
3. Send message: "Hello world"
4. Tap the message to edit it
5. Verify edit UI appears with "Hello world" pre-filled
6. Change text to "Hello universe"
7. Tap "Save"
8. Verify message updates to "Hello universe" immediately
9. Verify "(edited)" indicator appears next to timestamp

**Expected Results:**
- ✓ Edit UI appears with current text
- ✓ Message updates instantly (optimistic UI)
- ✓ "(edited)" indicator visible
- ✓ No error messages

#### Scenario 2.2.2: Edit History Modal

**Steps:**
1. From previous test, tap "(edited)" indicator
2. Verify edit history modal opens
3. Verify modal shows:
   - **Current Version:** "Hello universe" with "Edited [timestamp]"
   - **Previous Versions:** "Hello world" with original timestamp
4. Tap "Close"
5. Verify modal closes

**Expected Results:**
- ✓ Edit history shows all versions
- ✓ Timestamps formatted as relative time ("2 minutes ago")
- ✓ Most recent edit at top

#### Scenario 2.2.3: Real-Time Edit Sync

**Steps:**
1. Device 1 (test1): Open conversation with test2
2. Device 2 (test2): Open same conversation
3. Device 1: Edit message to "Updated text"
4. Device 2: Verify message updates to "Updated text" within 2 seconds
5. Device 2: Verify "(edited)" indicator appears

**Expected Results:**
- ✓ Edit syncs to other participants in real-time
- ✓ Both devices show same edited text
- ✓ Both devices show "(edited)" indicator

#### Scenario 2.2.4: Edit Validation

**Test 1: Empty text rejection**
1. Edit message and clear all text
2. Tap "Save"
3. Verify edit cancels (message unchanged)

**Test 2: Whitespace-only rejection**
1. Edit message and enter only spaces/newlines
2. Tap "Save"
3. Verify edit cancels

**Test 3: Max length enforcement**
1. Edit message and enter 10,001 characters
2. Tap "Save"
3. Verify error message: "Message too long (max 10,000 characters)"

**Test 4: Whitespace trimming**
1. Edit message: "  Hello  \n"
2. Tap "Save"
3. Verify saved text is "Hello" (trimmed)

**Expected Results:**
- ✓ Empty/whitespace-only edits rejected
- ✓ Max length enforced at 10,000 characters
- ✓ Whitespace trimmed from both ends

#### Scenario 2.2.5: Offline Editing

**Steps:**
1. Enable Airplane Mode
2. Edit a message to "Edited offline"
3. Verify message shows "Edited offline" immediately (optimistic UI)
4. Verify offline banner appears
5. Disable Airplane Mode
6. Wait 5 seconds
7. Open Firebase Console → Firestore → messages
8. Verify message text updated to "Edited offline"
9. Verify editHistory contains previous text

**Expected Results:**
- ✓ Edit appears immediately while offline
- ✓ Edit syncs when connection restored
- ✓ No data loss

#### Scenario 2.2.6: Edit Restrictions

**Test: Cannot edit other users' messages**
1. Open conversation with test2
2. Locate message sent by test2
3. Tap the message
4. Verify NO edit UI appears (only for own messages)

**Expected Results:**
- ✓ Edit only available for own messages

---

## Story 2.3: Message Unsend (Delete for Everyone)

### Objective
Verify users can delete their own messages within 24 hours, with text removed for privacy.

### Test Scenarios

#### Scenario 2.3.1: Delete Message (Basic)

**Steps:**
1. Sign in as test1@messageai.dev
2. Open conversation with test2
3. Send message: "Test message to delete"
4. Swipe left on message bubble (or long-press if swipe not implemented)
5. Tap "Unsend" option
6. Verify confirmation alert appears: "Delete this message for everyone?"
7. Tap "Cancel"
8. Verify message remains unchanged
9. Swipe left again, tap "Unsend"
10. Tap "Delete for Everyone"
11. Verify message immediately shows "[Message deleted]" in italic gray text

**Expected Results:**
- ✓ Confirmation alert prevents accidental deletion
- ✓ Message shows "[Message deleted]" placeholder
- ✓ Gray italic styling applied

#### Scenario 2.3.2: Real-Time Delete Sync

**Steps:**
1. Device 1 (test1): Send message: "This will be deleted"
2. Device 2 (test2): Verify message appears
3. Device 1: Delete the message
4. Device 2: Verify message changes to "[Message deleted]" within 2 seconds

**Expected Results:**
- ✓ Deletion syncs to all participants
- ✓ All devices show "[Message deleted]" placeholder

#### Scenario 2.3.3: Privacy Verification (Firebase)

**Steps:**
1. Delete a message
2. Open Firebase Console → Firestore → messages collection
3. Find deleted message document
4. Verify fields:
   - `isDeleted: true`
   - `text: ""` (empty - text removed for privacy)
   - `deletedAt: [timestamp]` (exists)
   - `deletedBy: [user_id]` (correct user ID)

**Expected Results:**
- ✓ Message text removed from database
- ✓ isDeleted flag set to true
- ✓ Metadata preserved (deletedAt, deletedBy)
- ✓ Document still exists (not hard deleted)

#### Scenario 2.3.4: 24-Hour Rule

**Test 1: Recent message (deletable)**
1. Send message now
2. Swipe left on message
3. Verify "Unsend" option appears

**Test 2: Old message (not deletable)**
1. Attempt to delete message sent > 24 hours ago
2. Swipe left on message
3. Verify "Unsend" option does NOT appear (or shows disabled)

**Note:** For manual testing, use mocked timestamps or wait 24 hours. In production, verify old messages cannot be deleted.

**Expected Results:**
- ✓ Messages within 24 hours show delete option
- ✓ Messages > 24 hours do NOT show delete option

#### Scenario 2.3.5: Conversation List Preview Update

**Steps:**
1. Open conversation and note last message text
2. Navigate to conversations list
3. Verify conversation preview shows last message text
4. Re-open conversation
5. Delete that last message
6. Navigate back to conversations list
7. Verify conversation preview shows "[Message deleted]"

**Expected Results:**
- ✓ Conversation preview updates when last message deleted
- ✓ Shows "[Message deleted]" placeholder

#### Scenario 2.3.6: Offline Deletion

**Steps:**
1. Enable Airplane Mode
2. Delete a message
3. Verify message shows "[Message deleted]" immediately
4. Disable Airplane Mode
5. Wait 5 seconds
6. Verify deletion synced to Firebase (check Console)
7. Verify other participants see deletion

**Expected Results:**
- ✓ Deletion appears immediately while offline
- ✓ Syncs when connection restored
- ✓ No data loss

---

## Story 2.4: Message Send Retry on Failure

### Objective
Verify failed messages can be manually retried or deleted.

### Test Scenarios

#### Scenario 2.4.1: Force Message Failure

**Steps:**
1. Enable Airplane Mode
2. Send message: "This will fail"
3. Verify message shows with red warning icon and "Failed" status
4. Disable Airplane Mode
5. Tap failed message
6. Verify alert appears: "Message failed to send. [Retry] [Delete]"
7. Tap "Retry"
8. Verify message attempts resend
9. Verify message changes to "sent" status (green checkmark)

**Expected Results:**
- ✓ Failed message displays with red warning icon
- ✓ Retry option available
- ✓ Successful retry changes status to sent

#### Scenario 2.4.2: Delete Failed Message

**Steps:**
1. Force message failure (airplane mode)
2. Tap failed message
3. Tap "Delete" button
4. Verify message removed from chat view
5. Verify message removed from failed message queue

**Expected Results:**
- ✓ Failed message can be deleted
- ✓ Removed from both UI and persistence

#### Scenario 2.4.3: Failed Message Persistence

**Steps:**
1. Force message failure
2. Close app completely (swipe up from app switcher)
3. Reopen app
4. Open conversation
5. Verify failed message still visible with "Failed" status
6. Retry message successfully

**Expected Results:**
- ✓ Failed messages persist across app restarts
- ✓ Can retry after app restart
- ✓ No data loss

#### Scenario 2.4.4: Network Error Handling

**Test with different network conditions:**
1. **No connection:** Airplane mode → verify failure
2. **Timeout:** Network Link Conditioner → 100% packet loss → verify timeout failure
3. **Slow 3G:** Network Link Conditioner → 3G profile → verify message sends but slower

**Expected Results:**
- ✓ All network error types handled gracefully
- ✓ User-friendly error messages displayed
- ✓ Retry available for all failure types

---

## Story 2.5: Read Receipts

### Objective
Verify read receipts show when messages have been seen by recipients.

### Test Scenarios

#### Scenario 2.5.1: Read Receipt Display (One-on-One)

**Steps:**
1. Device 1 (test1): Send message to test2: "Testing read receipts"
2. Verify message shows single checkmark ✓ (sent)
3. Device 2 (test2): Open conversation with test1
4. Device 1: Verify message checkmark changes to double blue checkmark ✓✓ (read)

**Expected Results:**
- ✓ Sent status shows single gray checkmark
- ✓ Read status shows double blue checkmarks
- ✓ Status updates in real-time (< 1 second)

#### Scenario 2.5.2: Read Receipt in Group Chat

**Steps:**
1. Device 1 (test1): Send message in 3-person group
2. Verify message shows "Sent" status
3. Device 2 (test2): Open group conversation
4. Device 1: Verify message shows "Read by 1 of 2" (test2 read, test3 has not)
5. Device 3 (test3): Open group conversation
6. Device 1: Verify message shows "Read by 2 of 2"
7. Tap read receipt indicator
8. Verify modal shows list of who has read:
   - test2 ✓
   - test3 ✓

**Expected Results:**
- ✓ Group read receipts show count
- ✓ Tapping shows list of readers
- ✓ Updates in real-time as participants read

#### Scenario 2.5.3: Read Receipt Status Progression

**Verify status never downgrades:**
1. Send message (status: sending)
2. Message sent (status: sent)
3. Recipient opens chat (status: read)
4. Close and reopen chat
5. Verify status remains "read" (does NOT downgrade to sent or delivered)

**Expected Results:**
- ✓ Status only upgrades, never downgrades
- ✓ Progression: sending → sent → delivered → read

#### Scenario 2.5.4: Offline Read Receipt Sync

**Steps:**
1. Device 1 (test1): Send message
2. Device 2 (test2): Enable Airplane Mode
3. Device 2: Open conversation (while offline)
4. Device 2: Disable Airplane Mode
5. Wait 5 seconds
6. Device 1: Verify message marked as read (within 5 seconds)

**Expected Results:**
- ✓ Read receipts queued while offline
- ✓ Sync when connection restored
- ✓ Sender sees read status update

---

## Story 2.6: Typing Indicators

### Objective
Verify typing indicators show when participants are actively typing.

### Test Scenarios

#### Scenario 2.6.1: Typing Indicator (One-on-One)

**Steps:**
1. Device 1 (test1): Open conversation with test2
2. Device 2 (test2): Open same conversation
3. Device 2: Start typing in message input
4. Device 1: Verify typing indicator appears below last message: "test2 is typing..."
5. Device 2: Stop typing for 3 seconds
6. Device 1: Verify typing indicator disappears

**Expected Results:**
- ✓ Typing indicator appears within 500ms
- ✓ Shows participant name + "is typing..."
- ✓ Disappears after 3 seconds of inactivity

#### Scenario 2.6.2: Typing Indicator (Group Chat)

**Steps:**
1. Open 3-person group conversation on all devices
2. Device 2 (test2): Start typing
3. Device 1 and Device 3: Verify "test2 is typing..."
4. Device 3 (test3): Start typing (while test2 still typing)
5. Device 1: Verify "test2, test3 are typing..."
6. Device 2 and 3: Stop typing
7. Device 1: Verify indicator disappears

**Expected Results:**
- ✓ Shows multiple typing users in groups
- ✓ Comma-separated names
- ✓ Pluralizes "are typing" for multiple users

#### Scenario 2.6.3: Typing Cleared on Send

**Steps:**
1. Device 2: Start typing
2. Device 1: Verify typing indicator appears
3. Device 2: Send message
4. Device 1: Verify typing indicator disappears immediately

**Expected Results:**
- ✓ Typing indicator cleared when message sent
- ✓ No delay

#### Scenario 2.6.4: Typing Cleared on Leave Chat

**Steps:**
1. Device 2: Start typing
2. Device 1: Verify typing indicator appears
3. Device 2: Navigate away from chat (back to conversations list)
4. Device 1: Verify typing indicator disappears immediately

**Expected Results:**
- ✓ Typing state cleared when leaving chat
- ✓ No stuck "is typing" indicators

#### Scenario 2.6.5: Performance (No Lag)

**Steps:**
1. Open conversation
2. Type rapidly in message input (20+ characters per second)
3. Verify NO lag in text input
4. Verify typing indicator updates smoothly on recipient device
5. Monitor Firestore writes (Firebase Console)
6. Verify typing updates throttled (max 1 per second)

**Expected Results:**
- ✓ No input lag while typing
- ✓ Firestore writes throttled to reduce costs
- ✓ Recipient sees smooth typing indicator updates

---

## Story 2.7: Image Attachments

### Objective
Verify users can send and view image attachments.

### Test Scenarios

#### Scenario 2.7.1: Send Image Attachment

**Steps:**
1. Open conversation
2. Tap attachment button (+ or paperclip icon)
3. Select "Photo Library"
4. Grant photo permissions if prompted
5. Select test image (2MB JPEG)
6. Verify image preview appears in message input
7. Optionally add caption: "Check out this image"
8. Tap send
9. Verify image appears in chat with loading indicator
10. Verify upload progress percentage shows (0% → 100%)
11. Verify image displays in bubble when upload complete
12. Verify caption appears below image

**Expected Results:**
- ✓ Photo library picker works
- ✓ Image compression applied (< 2MB)
- ✓ Upload progress indicator visible
- ✓ Optimistic UI (image shows before upload completes)
- ✓ Caption displayed correctly

#### Scenario 2.7.2: View Full-Screen Image

**Steps:**
1. Tap image in chat bubble
2. Verify full-screen image viewer opens
3. Pinch to zoom in and out
4. Verify zoom works smoothly
5. Tap share button
6. Verify iOS share sheet appears
7. Tap "Done" or swipe down to close viewer

**Expected Results:**
- ✓ Full-screen viewer opens on tap
- ✓ Pinch-to-zoom works
- ✓ Share functionality works

#### Scenario 2.7.3: Image Attachment Real-Time Sync

**Steps:**
1. Device 1: Send image attachment
2. Device 2: Open conversation
3. Verify image appears within 2-5 seconds (depending on network)
4. Device 2: Tap image to view full-screen
5. Verify image loads and displays correctly

**Expected Results:**
- ✓ Image syncs to recipient
- ✓ Both devices can view image
- ✓ No errors

#### Scenario 2.7.4: Failed Image Upload

**Steps:**
1. Enable Airplane Mode
2. Select and send image
3. Verify image shows in chat with upload progress
4. Verify progress stalls at 0%
5. Wait 10 seconds
6. Verify "Failed to upload" error message appears
7. Tap failed image
8. Verify retry option available
9. Disable Airplane Mode
10. Tap "Retry"
11. Verify upload completes successfully

**Expected Results:**
- ✓ Failed uploads clearly indicated
- ✓ Retry option available
- ✓ Successful retry after network restored

#### Scenario 2.7.5: Offline Image Queue

**Steps:**
1. Enable Airplane Mode
2. Send 3 images
3. Verify all 3 images show "queued" status
4. Verify offline banner shows "3 uploads queued"
5. Close app
6. Reopen app
7. Verify all 3 images still in queue
8. Disable Airplane Mode
9. Verify uploads begin automatically
10. Verify all 3 images upload successfully

**Expected Results:**
- ✓ Images queued while offline
- ✓ Queue persists across app restarts
- ✓ Automatic upload when connection restored

#### Scenario 2.7.6: Image Size Limit Enforcement

**Steps:**
1. Attempt to send image > 2MB
2. Verify compression applied automatically
3. Verify final uploaded size < 2MB
4. Open Firebase Console → Storage → images/
5. Verify uploaded file size < 2MB

**Expected Results:**
- ✓ Images automatically compressed
- ✓ 2MB limit enforced by client
- ✓ Firebase Storage rules enforce limit as backup

#### Scenario 2.7.7: Performance Testing

**Test upload time (WiFi):**
1. Send 2MB image
2. Time from tap send → image fully uploaded
3. Verify total time < 5 seconds
4. Breakdown:
   - Compression: < 1 second
   - Upload: < 4 seconds
   - Firestore write: < 1 second

**Expected Results:**
- ✓ Complete flow < 5 seconds on WiFi
- ✓ Optimistic UI makes it feel instant (< 1 second perceived)

---

## Story 2.8: Document Attachments (PDF)

### Objective
Verify users can send and view PDF document attachments.

### Test Scenarios

#### Scenario 2.8.1: Send PDF Attachment

**Steps:**
1. Open conversation
2. Tap attachment button
3. Select "Document" option
4. Select test PDF file (5MB)
5. Verify document preview appears showing:
   - File icon (PDF icon)
   - File name
   - File size (5 MB)
6. Optionally add caption: "Important document"
7. Tap send
8. Verify document appears in chat as card with loading indicator
9. Verify upload progress percentage shows
10. Verify document card displays when upload complete

**Expected Results:**
- ✓ Document picker works
- ✓ PDF validation enforces 10MB limit
- ✓ Upload progress indicator visible
- ✓ Document card displays file info correctly

#### Scenario 2.8.2: View PDF Document

**Steps:**
1. Tap document card in chat
2. Verify QuickLook viewer opens with PDF
3. Scroll through PDF pages
4. Verify all pages render correctly
5. Tap share button
6. Verify iOS share sheet appears
7. Swipe down to close QuickLook viewer

**Expected Results:**
- ✓ QuickLook opens on tap
- ✓ PDF renders correctly
- ✓ Share functionality works

#### Scenario 2.8.3: PDF Size Limit Enforcement

**Test 1: Valid size (< 10MB)**
1. Send 8MB PDF
2. Verify upload succeeds

**Test 2: Too large (> 10MB)**
1. Attempt to send 12MB PDF
2. Verify error message: "Document too large (max 10MB)"
3. Verify upload prevented

**Expected Results:**
- ✓ 10MB limit enforced
- ✓ Clear error message for oversized files

#### Scenario 2.8.4: Document Real-Time Sync

**Steps:**
1. Device 1: Send PDF document
2. Device 2: Open conversation
3. Verify document appears within 3-10 seconds (depending on size)
4. Device 2: Tap document to view
5. Verify PDF opens and displays correctly

**Expected Results:**
- ✓ Document syncs to recipient
- ✓ Both devices can view document
- ✓ No errors

#### Scenario 2.8.5: Failed Document Upload Retry

**Steps:**
1. Enable Airplane Mode
2. Send PDF document
3. Verify upload fails with error message
4. Tap failed document
5. Verify retry option available
6. Disable Airplane Mode
7. Tap "Retry"
8. Verify upload completes successfully

**Expected Results:**
- ✓ Failed uploads show retry option
- ✓ Retry works after network restored

---

## Story 2.9: Offline Message Queue with Manual Send

### Objective
Verify messages composed offline can be reviewed and manually sent when connected.

### Test Scenarios

#### Scenario 2.9.1: Queue Messages While Offline

**Steps:**
1. Enable Airplane Mode
2. Send 5 messages: "Message 1", "Message 2", ..., "Message 5"
3. Verify all 5 messages show "Queued" status (yellow warning icon)
4. Verify offline banner displays: "You're offline. 5 messages queued. [Send All]"
5. Close app
6. Reopen app
7. Verify all 5 messages still in queue
8. Verify offline banner still shows "5 messages queued"

**Expected Results:**
- ✓ Messages queued with visual indicator
- ✓ Queue persists across app restarts
- ✓ Offline banner shows accurate count

#### Scenario 2.9.2: Connectivity Restored Prompt

**Steps:**
1. With 5 messages queued, disable Airplane Mode
2. Verify toast notification appears: "Connected. Auto-send 5 queued messages? [Yes] [Review First]"
3. Tap "Review First"
4. Verify navigation to Offline Queue view
5. Verify view shows all 5 messages with:
   - Message text
   - Timestamp
   - Actions: [Send] [Edit] [Delete]

**Expected Results:**
- ✓ Connectivity restored notification appears
- ✓ "Review First" opens queue view
- ✓ All queued messages visible

#### Scenario 2.9.3: Send All Queued Messages

**Steps:**
1. Queue 5 messages while offline
2. Disable Airplane Mode
3. Tap "Yes" on connectivity prompt (or tap "Send All" in banner)
4. Verify messages sent sequentially (in order)
5. Verify sent messages removed from queue one by one
6. Verify all messages marked "sent" in chat
7. Verify offline banner disappears when queue empty

**Expected Results:**
- ✓ All messages sent in correct order
- ✓ Sequential sending (not parallel)
- ✓ Queue cleared when all sent

#### Scenario 2.9.4: Per-Message Actions in Queue View

**Test 1: Edit queued message**
1. Open Offline Queue view
2. Tap "Edit" on Message 2
3. Change text to "Message 2 edited"
4. Save changes
5. Tap "Send" on that message
6. Verify edited message sent

**Test 2: Delete queued message**
1. Tap "Delete" on Message 3
2. Verify confirmation prompt
3. Confirm deletion
4. Verify message removed from queue
5. Verify queue count updates

**Expected Results:**
- ✓ Edit functionality works for queued messages
- ✓ Delete removes message from queue
- ✓ Send sends individual message

#### Scenario 2.9.5: Failed Send Remains in Queue

**Steps:**
1. Queue 3 messages offline
2. Disable Airplane Mode briefly, then enable again (to simulate intermittent connection)
3. Attempt to send messages
4. Verify some sends fail
5. Verify failed messages remain in queue with "Failed" status
6. Verify successful sends removed from queue
7. Disable Airplane Mode fully
8. Retry failed messages
9. Verify successful send and removal from queue

**Expected Results:**
- ✓ Failed sends remain in queue
- ✓ Successful sends removed
- ✓ Retry available for failures

#### Scenario 2.9.6: Large Queue Performance

**Steps:**
1. Queue 50 messages while offline
2. Open Offline Queue view
3. Verify view loads instantly (< 1 second)
4. Scroll through entire list
5. Verify NO lag or stuttering
6. Tap "Send All"
7. Verify messages sent sequentially
8. Verify UI remains responsive during send

**Expected Results:**
- ✓ Large queues (50+ messages) handled without lag
- ✓ UI remains responsive
- ✓ Sequential sending works for large batches

---

## Story 2.10: Push Notifications

### Objective
Verify push notifications deliver when app is backgrounded or closed.

### Test Scenarios

#### Scenario 2.10.1: Notification Permissions

**Steps:**
1. Install app fresh (or clear app data)
2. Sign in for first time
3. Complete profile setup
4. Verify notification permission prompt appears
5. Tap "Allow"
6. Verify permissions granted

**Expected Results:**
- ✓ Permission prompt appears at appropriate time (after onboarding)
- ✓ Permissions granted successfully
- ✓ No permission fatigue (not shown during onboarding)

#### Scenario 2.10.2: Background Notification Delivery

**Steps:**
1. Device 1 (test1): Open app, stay on conversations list
2. Device 2 (test2): Send message to test1: "Testing background notification"
3. Device 1: Swipe up to background the app (but don't close)
4. Wait 5 seconds
5. Verify lock screen shows notification:
   - Sender: test2
   - Message preview: "Testing background notification"
   - App icon badge shows "1"
6. Tap notification
7. Verify app opens directly to conversation with test2

**Expected Results:**
- ✓ Notification delivered within 5 seconds
- ✓ Correct sender and message preview
- ✓ Badge count accurate
- ✓ Tap notification deep links to correct conversation

#### Scenario 2.10.3: Foreground Notification (Banner)

**Steps:**
1. Device 1: Open app, viewing conversations list (NOT in specific conversation)
2. Device 2: Send message to test1
3. Device 1: Verify banner notification appears at top
4. Wait 3 seconds
5. Verify banner auto-dismisses
6. Tap banner before it dismisses
7. Verify navigation to conversation

**Expected Results:**
- ✓ Foreground banner appears
- ✓ Auto-dismisses after a few seconds
- ✓ Tapping banner navigates to conversation

#### Scenario 2.10.4: Suppress Notification When Viewing Conversation

**Steps:**
1. Device 1: Open conversation with test2 (actively viewing)
2. Device 2: Send message to test1
3. Device 1: Verify NO notification appears (message just appears in chat)
4. Verify no banner, no sound, no badge increment

**Expected Results:**
- ✓ No redundant notification when actively viewing conversation
- ✓ Message still appears in real-time via listener

#### Scenario 2.10.5: Group Chat Notifications

**Steps:**
1. Device 1: Background app
2. Device 2 (test2): Send message in group: "Group message test"
3. Device 1: Verify notification shows:
   - "[test2] in [Group Name or participant names]: Group message test"
4. Tap notification
5. Verify app opens to correct group conversation

**Expected Results:**
- ✓ Group notifications show sender and group context
- ✓ Deep link opens correct conversation

#### Scenario 2.10.6: Badge Count Management

**Steps:**
1. Background app
2. Receive 5 notifications from different conversations
3. Verify badge shows "5"
4. Open app
5. Open 2 of the conversations
6. Verify badge updates to "3"
7. Mark all as read
8. Verify badge clears to "0"

**Expected Results:**
- ✓ Badge count reflects unread messages
- ✓ Updates in real-time as conversations viewed
- ✓ Clears when all read

#### Scenario 2.10.7: Notification Sound

**Steps:**
1. Enable device sound
2. Background app
3. Receive notification
4. Verify notification sound plays
5. Open app and stay in conversations list
6. Receive another notification (foreground)
7. Verify sound plays for foreground notification

**Expected Results:**
- ✓ Sound plays for both background and foreground notifications
- ✓ Default iOS sound acceptable for MVP

#### Scenario 2.10.8: Offline Notification Queue

**Steps:**
1. Device 1: Enable Airplane Mode, background app
2. Device 2: Send 3 messages to Device 1
3. Device 1: Wait 1 minute (notifications queued by APNs)
4. Device 1: Disable Airplane Mode
5. Wait 10 seconds
6. Verify all 3 notifications delivered

**Expected Results:**
- ✓ Notifications queued by APNs while offline
- ✓ Delivered when connection restored
- ✓ No data loss

---

## Story 2.11: Performance Optimization & Network Resilience

### Objective
Verify app performs well under stress: poor networks, large data volumes, and resource constraints.

### Test Scenarios

#### Scenario 2.11.1: Performance Baselines

**Test 1: App Launch**
1. Close app completely
2. Launch app
3. Time from tap icon → conversations list visible
4. Verify time < 1 second

**Test 2: Conversation Load**
1. Open conversation with 50 messages
2. Time from tap conversation → messages visible
3. Verify time < 1 second

**Test 3: Message Send**
1. Send text message
2. Time from tap send → message marked "sent"
3. Verify time < 2 seconds

**Expected Results:**
- ✓ App launch < 1 second
- ✓ Conversation load < 1 second
- ✓ Message send < 2 seconds

#### Scenario 2.11.2: Message Pagination

**Steps:**
1. Open conversation with 1000 messages
2. Verify only 50 most recent messages loaded initially
3. Scroll to top
4. Verify "Load more" appears
5. Tap "Load more" or scroll past threshold
6. Verify next 50 messages load
7. Continue scrolling and loading
8. Verify smooth scrolling throughout

**Expected Results:**
- ✓ Initial load shows 50 messages only
- ✓ Pagination loads older messages on demand
- ✓ No performance degradation with large history

#### Scenario 2.11.3: Conversation List Pagination

**Steps:**
1. Account with 100+ conversations
2. Open conversations list
3. Verify initial load shows ~50 conversations
4. Scroll to bottom
5. Verify more conversations load automatically
6. Verify smooth scrolling

**Expected Results:**
- ✓ Conversations paginated
- ✓ Smooth scrolling with large list
- ✓ No lag

#### Scenario 2.11.4: Relative Timestamp Updates

**Steps:**
1. Open conversations list
2. Note conversation with "2 minutes ago" timestamp
3. Wait 1 minute
4. Verify timestamp updates to "3 minutes ago"
5. Verify NO flicker or visual disruption
6. Background app
7. Wait 5 minutes
8. Foreground app
9. Verify timestamps updated correctly

**Expected Results:**
- ✓ Timestamps update every 60 seconds
- ✓ No flicker during updates
- ✓ Timer pauses when app backgrounded (battery optimization)

#### Scenario 2.11.5: User Cache Optimization

**Test 1: Conversation List Efficiency**
1. Open Firebase Console → Firestore
2. Monitor "read" operations count
3. Open conversations list
4. Verify participant data fetched (initial load)
5. Edit a message in one conversation
6. Return to conversations list
7. Verify < 5 user reads (cached users reused)
8. Wait 5 minutes (cache TTL)
9. Refresh conversations list
10. Verify users re-fetched (cache expired)

**Test 2: Cache Staleness**
1. Open conversations list
2. On different device, update user profile (change display name)
3. Wait 5 minutes (cache TTL)
4. Refresh conversations list on first device
5. Verify updated display name appears

**Expected Results:**
- ✓ User cache reduces Firebase reads by 90%+
- ✓ Cache expires after 5 minutes (profile data)
- ✓ Online status cache expires after 30 seconds
- ✓ Profile changes appear within 5 minutes

#### Scenario 2.11.6: Network Resilience (3G Speeds)

**Steps:**
1. Enable Network Link Conditioner
2. Set profile to "3G" (slow network)
3. Send message
4. Verify message sends (may take 5-10 seconds)
5. Verify NO crashes or errors
6. Load conversation with images
7. Verify images load (slowly but successfully)
8. Switch to "WiFi" profile
9. Verify app responds immediately with faster speeds

**Expected Results:**
- ✓ App handles slow networks gracefully
- ✓ No crashes or data loss on 3G speeds
- ✓ User sees loading indicators for slow operations

#### Scenario 2.11.7: Rapid-Fire Messaging

**Steps:**
1. Open conversation
2. Send 20 messages as fast as possible (tap send repeatedly)
3. Verify all 20 messages appear in chat
4. Verify messages maintain correct order
5. Device 2: Open conversation
6. Verify all 20 messages received in correct order
7. Verify no duplicates

**Expected Results:**
- ✓ All messages delivered
- ✓ Correct order maintained
- ✓ No duplicates or race conditions

#### Scenario 2.11.8: Airplane Mode Toggling

**Steps:**
1. Open conversation
2. Send message
3. Enable Airplane Mode
4. Send message (queued)
5. Disable Airplane Mode
6. Wait 2 seconds
7. Enable Airplane Mode again
8. Send message (queued)
9. Disable Airplane Mode
10. Verify all 3 messages sent successfully
11. Verify NO crashes

**Expected Results:**
- ✓ App handles rapid connectivity changes
- ✓ No crashes during offline/online transitions
- ✓ All messages eventually delivered

#### Scenario 2.11.9: Memory Profiling

**Steps:**
1. Open Xcode → Debug Navigator → Memory
2. Open conversations list with 10 conversations loaded
3. Note memory usage
4. Verify memory < 150MB
5. Open and close 5 conversations
6. Return to conversations list
7. Verify memory hasn't grown significantly (< 200MB)
8. Check for memory leaks

**Expected Results:**
- ✓ App uses < 150MB RAM with 10 conversations
- ✓ No memory leaks detected
- ✓ Memory remains stable over time

#### Scenario 2.11.10: Battery Usage

**Steps:**
1. Charge device to 100%
2. Use app actively for 30 minutes (messaging, viewing conversations)
3. Note battery drain
4. Verify battery drain < 10% for 30 minutes of active use
5. Background app for 1 hour
6. Verify minimal battery drain while backgrounded (< 2%)

**Expected Results:**
- ✓ Acceptable battery usage during active use
- ✓ Minimal drain when backgrounded
- ✓ No runaway background processing

#### Scenario 2.11.11: Firestore Listener Cleanup

**Steps:**
1. Open conversation (listener starts)
2. Open Memory Debugger in Xcode
3. Note active listeners
4. Navigate back to conversations list
5. Verify conversation listener removed
6. Open 5 conversations sequentially
7. Verify only current conversation has active listener
8. Check for memory leaks

**Expected Results:**
- ✓ Listeners cleaned up when views dismissed
- ✓ No memory leaks from listeners
- ✓ Only active views have listeners

---

## Cross-Story Integration Tests

These tests verify multiple stories work together correctly.

### Integration Test 1: Complete Messaging Flow

**Scenario:** End-to-end group conversation with multiple features

**Steps:**
1. Create 3-person group conversation (Story 2.1)
2. Send text message (Epic 1)
3. Edit message (Story 2.2)
4. Send image attachment (Story 2.7)
5. Send PDF document (Story 2.8)
6. Delete old message (Story 2.3)
7. Verify all participants see all changes
8. Verify read receipts update (Story 2.5)
9. Verify typing indicators work (Story 2.6)
10. Verify push notifications delivered (Story 2.10)

**Expected Results:**
- ✓ All features work together
- ✓ No conflicts or errors
- ✓ Real-time sync working for all operations

### Integration Test 2: Offline Resilience

**Scenario:** Use all features while offline, sync when online

**Steps:**
1. Enable Airplane Mode
2. Create new conversation (Story 2.0) - queued
3. Send 3 text messages (queued)
4. Send image (queued)
5. Edit message (queued)
6. Delete message (queued)
7. Disable Airplane Mode
8. Verify all operations sync successfully
9. Verify recipient sees all changes in correct order

**Expected Results:**
- ✓ All operations queued while offline
- ✓ Sync correctly when online
- ✓ No data loss
- ✓ Correct order maintained

### Integration Test 3: Performance Under Load

**Scenario:** Stress test with concurrent operations

**Steps:**
1. Open conversation with 1000 messages
2. Scroll through messages (pagination)
3. While scrolling, receive 5 new messages
4. Send message
5. Send image attachment
6. Edit message
7. Verify typing indicator for other participant
8. Verify read receipts update
9. Monitor app performance (FPS, memory, CPU)

**Expected Results:**
- ✓ Smooth performance (60 FPS)
- ✓ No lag or stuttering
- ✓ Memory usage stable
- ✓ All features work concurrently

---

## Regression Testing Checklist

After completing all Epic 2 stories, verify Epic 1 features still work:

### Epic 1 Features Regression

- [ ] **Authentication** (Story 1.1):
  - Sign in works
  - Sign up works
  - Sign out works

- [ ] **User Profiles** (Story 1.2):
  - Profile creation works
  - Profile editing works
  - Profile image upload works

- [ ] **Conversations** (Story 1.3):
  - Conversation list loads
  - Create conversation works
  - Conversations display correctly

- [ ] **Messaging** (Story 1.4):
  - Send text message works
  - Receive message works
  - Real-time updates work

- [ ] **Real-Time Listeners** (Story 1.5):
  - Firestore listeners active
  - Updates appear immediately
  - No memory leaks

- [ ] **Offline Support** (Story 1.6):
  - Offline banner appears
  - Messages queue offline
  - Sync when online

### Epic 2 Features Working Together

- [ ] Can create group conversations
- [ ] Can edit messages in groups
- [ ] Can delete messages in groups
- [ ] Can send images in groups
- [ ] Can send documents in groups
- [ ] Typing indicators work in groups
- [ ] Read receipts work in groups
- [ ] Push notifications work for all message types
- [ ] Offline queue works for all message types

---

## Accessibility Testing

### VoiceOver Testing Checklist

For all Epic 2 features:

- [ ] **Story 2.0 - New Conversation:**
  - "New Message" button announced
  - User list items announced with name, email, status
  - Search field announced

- [ ] **Story 2.1 - Group Chat:**
  - Group avatar announced as "Group conversation with [names]"
  - Group member list items announced correctly
  - Multi-select checkboxes announced

- [ ] **Story 2.2 - Message Editing:**
  - Edit UI announced
  - "(edited)" indicator announced as "Message edited, tap to view history"
  - Edit history modal announced

- [ ] **Story 2.3 - Message Delete:**
  - "Unsend" button announced
  - "[Message deleted]" placeholder announced
  - Confirmation alert announced

- [ ] **Story 2.4 - Retry:**
  - Failed message status announced
  - Retry/Delete options announced

- [ ] **Story 2.5 - Read Receipts:**
  - Read status announced ("Read by 2 of 3")
  - Read receipt modal announced

- [ ] **Story 2.6 - Typing Indicators:**
  - "X is typing..." announced

- [ ] **Story 2.7 - Images:**
  - Image attachment button announced
  - Upload progress announced
  - Image message announced

- [ ] **Story 2.8 - Documents:**
  - Document attachment button announced
  - Document info announced (name, size)
  - QuickLook viewer accessible

- [ ] **Story 2.9 - Offline Queue:**
  - Queued message status announced
  - Offline banner announced
  - Queue view items announced

- [ ] **Story 2.10 - Notifications:**
  - Notification content announced
  - Tap to open announced

### Dark Mode Testing

Verify all UI elements render correctly in dark mode:
- [ ] Conversations list
- [ ] Chat view (messages, input, buttons)
- [ ] Group avatar
- [ ] Edit UI overlay
- [ ] Delete confirmation
- [ ] Typing indicators
- [ ] Image/document attachments
- [ ] Offline queue view
- [ ] Notifications (system controlled)

---

## Test Data Cleanup

After completing manual tests:

1. **Firebase Console:**
   - Delete test conversations
   - Delete test messages
   - Delete test images/documents from Storage
   - Clear test user profiles

2. **Local App:**
   - Clear failed message queue (UserDefaults)
   - Clear offline message queue
   - Unregister FCM tokens (if needed)
   - Reset notification permissions (for fresh test)

3. **Test Accounts:**
   - Sign out all test accounts
   - Clear app data if needed (Settings → Reset)

---

## Known Issues / Limitations

Document any known issues discovered during testing:

### Story 2.6 (Typing Indicators)
- **Status:** Ready for Review
- **Notes:** Implementation complete, pending final QA sign-off

### Story 2.9 (Offline Queue)
- **Status:** Approved
- **Notes:** Implementation complete, manual testing pending

### General Notes
- Performance optimization (Story 2.11) includes user cache with 5-minute TTL
- Image attachments compress to < 2MB automatically
- Document attachments have 10MB hard limit
- Message editing only available for own messages
- Message deletion only available within 24 hours

---

## Test Execution Tracking

Use this checklist to track testing progress:

### Per-Story Completion

- [ ] Story 2.0: Start New Conversation (4 scenarios, 4 edge cases)
- [ ] Story 2.1: Group Chat (6 scenarios, accessibility)
- [ ] Story 2.2: Message Editing (6 scenarios)
- [ ] Story 2.3: Message Unsend (6 scenarios, Firebase verification)
- [ ] Story 2.4: Message Send Retry (4 scenarios)
- [ ] Story 2.5: Read Receipts (4 scenarios)
- [ ] Story 2.6: Typing Indicators (5 scenarios)
- [ ] Story 2.7: Image Attachments (7 scenarios, performance)
- [ ] Story 2.8: Document Attachments (5 scenarios)
- [ ] Story 2.9: Offline Message Queue (6 scenarios)
- [ ] Story 2.10: Push Notifications (8 scenarios)
- [ ] Story 2.11: Performance Optimization (11 scenarios)

### Integration Tests

- [ ] Complete Messaging Flow
- [ ] Offline Resilience
- [ ] Performance Under Load

### Regression Tests

- [ ] Epic 1 features still work
- [ ] Epic 2 features work together

### Accessibility Tests

- [ ] VoiceOver testing complete
- [ ] Dark mode testing complete

---

## Test Reports

### Template for Test Execution Report

**Test Date:** [Date]
**Tester:** [Name]
**Device/Simulator:** [Device details]
**iOS Version:** [Version]
**App Version:** [Version]
**Build:** [Build number]

**Stories Tested:**
- Story 2.X: [Name]

**Scenarios Executed:**
1. Scenario 2.X.1: [Pass/Fail] - [Notes]
2. Scenario 2.X.2: [Pass/Fail] - [Notes]
...

**Bugs Found:**
1. [Bug ID] - [Description] - [Severity: Critical/High/Medium/Low]
2. ...

**Overall Status:** [Pass/Fail/Blocked]

**Notes:**
- Any observations
- Performance notes
- Suggestions

---

## Contact & Support

For questions or issues with this testing guide:
- **Project Lead:** [Name]
- **QA Lead:** [Name]
- **Documentation:** docs/stories/ (individual story files)
- **Architecture:** docs/architecture/
- **Testing Standards:** docs/architecture/testing-best-practices.md

---

## Appendix: Quick Reference

### Test User Accounts
- test1@messageai.dev
- test2@messageai.dev
- test3@messageai.dev

### Firebase Projects
- **Development:** messageai-dev-1f2ec
- **Production:** messageai-prod-4d3a8

### Test Scripts
```bash
# Quick unit tests
./scripts/quick-test.sh -q

# Epic 2 tests
./scripts/test-epic.sh 2

# Full test suite
./scripts/quick-test.sh

# Firebase Emulator
./scripts/start-emulator.sh
./scripts/stop-emulator.sh
```

### Performance Targets
- App launch: < 1 second
- Conversation load: < 1 second
- Message send: < 2 seconds
- Image upload: < 5 seconds (2MB, WiFi)
- PDF upload: < 10 seconds (10MB, WiFi)
- Notification delivery: < 5 seconds
- Read receipt update: < 1 second
- Typing indicator: < 500ms

### Size Limits
- Messages: 10,000 characters max
- Images: 2MB max (auto-compressed)
- Documents: 10MB max
- Message queue: ~1000 messages (500KB UserDefaults limit)

---

**End of Manual Testing Guide for Epic 2**
