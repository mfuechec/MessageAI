# Manual Testing: Per-User AI Summary Storage

**Date:** October 24, 2025
**Feature:** Per-user conversation summary storage in Firestore
**Environment:** messageai-dev-1f2ec

---

## Overview

This test verifies that AI conversation summaries are now stored per-user in Firestore at:
```
/users/{userId}/conversation_summaries/{conversationId}
```

This enables:
- ✅ Personalized summaries for each participant
- ✅ Privacy (users can't see each other's summaries)
- ✅ Future personalization features

---

## Prerequisites

- ✅ Cloud Function deployed: `summarizeThread`
- ✅ Firestore security rules deployed
- ✅ Two test users logged in:
  - **tester1@gmail.com** (User A)
  - **tester2@gmail.com** (User B)
- ✅ Shared conversation between both users

---

## Test 1: Generate Summary as User A

### Steps:

1. **Open app as tester1@gmail.com**
2. **Navigate to a conversation** with tester2
3. **Tap "AI Summary" button**
4. **Wait for summary to generate** (~5-10 seconds)
5. **Verify summary displays** with:
   - Summary text
   - Key points
   - Priority messages (if any)
   - Participants
   - Date range

### Expected Results:

✅ Summary loads successfully
✅ No errors in app console
✅ Summary makes sense for conversation content

### Verify in Firestore Console:

**Navigate to:**
```
https://console.firebase.google.com/project/messageai-dev-1f2ec/firestore
```

**Path:**
```
users → {tester1-userId} → conversation_summaries → {conversationId}
```

**Expected Fields:**
- ✅ `summary` (string) - The summary text
- ✅ `keyPoints` (array) - Array of key points
- ✅ `priorityMessages` (array) - Priority messages with IDs
- ✅ `participants` (array) - Participant names
- ✅ `dateRange` (string) - Date range of messages
- ✅ `generatedAt` (timestamp) - When summary was created
- ✅ `lastMessageId` (string) - ID of latest message
- ✅ `messageCount` (number) - Number of messages analyzed
- ✅ `expiresAt` (date) - Expiration date (24 hours)
- ✅ `conversationId` (string) - Reference to conversation

---

## Test 2: Generate Summary as User B

### Steps:

1. **Sign out of User A**
2. **Sign in as tester2@gmail.com** (User B)
3. **Navigate to the SAME conversation**
4. **Tap "AI Summary" button**
5. **Wait for summary to generate**
6. **Verify summary displays**

### Expected Results:

✅ User B can generate their own summary
✅ Summary is independent of User A's summary
✅ No errors

### Verify in Firestore Console:

**Path:**
```
users → {tester2-userId} → conversation_summaries → {conversationId}
```

**Expected:**
- ✅ User B has their own summary document
- ✅ Different document than User A's summary
- ✅ Same structure as User A's summary

---

## Test 3: Verify Isolation (User A Cannot See User B's Summary)

### Manual Console Check:

1. **Open Firestore Console**
2. **View User A's summaries:**
   ```
   users → {tester1-userId} → conversation_summaries
   ```
3. **View User B's summaries:**
   ```
   users → {tester2-userId} → conversation_summaries
   ```

### Expected Results:

✅ User A's summary exists under User A's subcollection
✅ User B's summary exists under User B's subcollection
✅ They are stored in SEPARATE locations
✅ No shared summary document

---

## Test 4: Check Cloud Function Logs

### Command:

```bash
firebase functions:log --only summarizeThread --project messageai-dev-1f2ec | grep "Stored summary" | tail -10
```

### Expected Output:

```
[summarizeThread] Stored summary in Firestore: users/{tester1-userId}/conversation_summaries/{conversationId}
[summarizeThread] Stored summary in Firestore: users/{tester2-userId}/conversation_summaries/{conversationId}
```

### Verification:

✅ Log shows per-user storage path
✅ Different user IDs for User A and User B
✅ Same conversation ID for both

---

## Test 5: Verify Security Rules (User A Cannot Read User B's Summary)

### Using Firebase Console (Manual Check):

1. **Sign in as User A** in the app
2. **Try to access User B's summary path** via console:
   ```
   users → {tester2-userId} → conversation_summaries
   ```

### Expected:

✅ User A can read their own summaries
❌ User A CANNOT read User B's summaries (permission denied if attempted via SDK)

**Note:** Security rules prevent cross-user access. This is enforced server-side, not visible in Console UI.

---

## Test 6: Regenerate Summary (Cache Hit)

### Steps:

1. **As User A, open the same conversation**
2. **Tap "AI Summary" again** (should hit cache)
3. **Verify summary loads faster** (~1-2 seconds instead of 5-10)

### Expected Results:

✅ Summary loads from cache quickly
✅ Firestore document is updated with cached version

### Check Logs:

```bash
firebase functions:log --only summarizeThread --project messageai-dev-1f2ec | grep "cached summary" | tail -5
```

**Expected:**
```
[summarizeThread] Updated Firestore with cached summary for user {userId}
```

---

## Test 7: Staleness Detection Data

### Verify Fields for Future Staleness Detection:

In User A's summary document:

✅ `lastMessageId` - Matches latest message in conversation
✅ `messageCount` - Matches total messages analyzed
✅ `expiresAt` - Set to 24 hours from now

**Purpose:** These fields will be used in Phase 2 to detect if summary needs refresh.

---

## Test 8: Old Summaries Still Exist (Backward Compatibility)

### Check Old Location:

Navigate to:
```
conversations → {conversationId} → ai_summary → latest
```

### Expected:

⚠️ **Old shared summary may still exist** (if generated before this update)
✅ **New summaries are NOT created here**
✅ **New summaries are only created in per-user locations**

**Note:** Old summaries won't be used, but can be left for historical data or manually deleted.

---

## Test 9: Multiple Conversations

### Steps:

1. **Generate summaries for 3 different conversations** as User A
2. **Verify all 3 summaries are stored** under:
   ```
   users → {userId} → conversation_summaries →
     ├── {conversationId-1}
     ├── {conversationId-2}
     └── {conversationId-3}
   ```

### Expected:

✅ Each conversation has its own summary document
✅ All summaries stored under User A's subcollection
✅ Document ID = conversation ID (easy to query)

---

## Test 10: Error Handling

### Scenario A: Generate Summary Without Authentication

**Expected:** ❌ Function returns "unauthenticated" error

### Scenario B: Generate Summary for Conversation User Isn't In

**Expected:** ❌ Function returns "permission-denied" error

### Scenario C: Network Failure During Generation

**Expected:** ✅ App shows error message, no partial data stored

---

## Success Criteria

All tests must pass:

- [x] Test 1: User A generates summary successfully
- [x] Test 2: User B generates independent summary
- [x] Test 3: Summaries are isolated per user
- [x] Test 4: Logs show correct per-user paths
- [x] Test 5: Security rules prevent cross-user access
- [x] Test 6: Cache hits work correctly
- [x] Test 7: Staleness detection fields populated
- [x] Test 8: Backward compatibility maintained
- [x] Test 9: Multiple conversations handled correctly
- [x] Test 10: Error handling works properly

---

## Known Issues / Limitations

**Current Limitations:**
- ⚠️ iOS app does not yet READ from Firestore cache (Phase 2)
- ⚠️ Summary always calls Cloud Function (Phase 2 will optimize)
- ⚠️ No staleness detection UI yet (Phase 2)
- ⚠️ No "Regenerate" button yet (Phase 2)

**Next Phase (Phase 2):**
- iOS reads from Firestore first (instant load)
- Staleness detection based on messageCount/lastMessageId
- "Regenerate" button for explicit refresh
- Optimistic loading with background verification

---

## Rollback Plan (If Needed)

If issues are found:

1. **Revert Cloud Function:**
   ```bash
   git revert HEAD
   firebase deploy --only functions:summarizeThread --project messageai-dev-1f2ec
   ```

2. **Revert Security Rules:**
   ```bash
   git checkout HEAD~1 -- firestore.rules
   firebase deploy --only firestore:rules --project messageai-dev-1f2ec
   ```

3. **Data Cleanup (if needed):**
   - Per-user summaries can be safely deleted
   - Old shared summaries can be restored as primary

---

## Questions or Issues?

Contact: Check Firebase logs and Firestore Console for debugging.

**Logs:**
```bash
firebase functions:log --project messageai-dev-1f2ec
```

**Firestore Console:**
https://console.firebase.google.com/project/messageai-dev-1f2ec/firestore
