# Migration Verification Checklist

## ✅ Step 1: Verify Data in Firestore Console

### Open Firestore Console
https://console.firebase.google.com/project/messageai-dev-1f2ec/firestore

### Check New Structure

**For tester2@gmail.com (v64FPlQvfWTbIskskM9z6nkaj3b2):**

Navigate to:
```
/users/v64FPlQvfWTbIskskM9z6nkaj3b2/
```

You should see these subcollections:

1. ✅ **notification_decisions** subcollection
   - Click it
   - Should see ~10+ documents
   - Each document should have fields: `conversationId`, `messageId`, `decision`, `timestamp`, etc.

2. ✅ **notification_feedback** subcollection
   - Click it
   - Should see 4 documents
   - Each document should have fields: `feedback` ("helpful" or "not_helpful"), `timestamp`, etc.

3. ✅ **rate_limits** subcollection
   - Click it
   - Should see a document called "default"
   - Contains: `count`, `resetAt`

4. ✅ **activity** subcollection
   - Click it
   - Should see a document called "current"
   - Contains: `activeConversationId`, `timestamp`

### Check Old Collections Still Exist (Backup)

At the root level, these should still be there:
- `/notification_decisions` - 29 documents
- `/notification_feedback` - 4 documents
- `/rate_limits` - 4 documents
- `/user_activity` - 1 document

---

## ✅ Step 2: Test iOS App

### Launch the App

In Xcode, press **Cmd+R** to build and run on iPhone 17 Pro Simulator.

### Test 1: Notification History View

1. **Open the app** and sign in as tester2@gmail.com
2. **Go to Settings** (bottom tab bar)
3. **Tap "Notification History"**

**Expected Results:**
- ✅ Should see list of notification decisions
- ✅ Each entry shows conversation name, timestamp, AI reasoning
- ✅ Shows "Notified" or "Suppressed" badge
- ✅ Shows your previous feedback (thumbs up/down) if you already rated

**If this works, the migration was successful!** ✅

---

### Test 2: Submit New Feedback

1. **In Notification History**, find an entry **without feedback**
2. **Tap the thumbs up** 👍 button

**Expected Results:**
- ✅ Button immediately changes to filled green thumb (optimistic UI)
- ✅ No navigation dismissal (stay on same screen)
- ✅ No error messages

3. **Close and reopen Notification History**

**Expected Results:**
- ✅ Your feedback is still there (persisted)
- ✅ Shows filled green thumb for "Helpful"

4. **Try thumbs down** 👎 on a different entry

**Expected Results:**
- ✅ Shows filled red thumb for "Not Helpful"
- ✅ Persists after reopening

---

### Test 3: New Notification Decision (Full Flow)

**This tests that NEW data is written to the correct location.**

1. **Open the app** as tester1 (different user)
2. **Send a message** to the conversation with tester2
3. **Wait 5-10 seconds** for AI to analyze

**Check Cloud Function Logs:**
```bash
firebase functions:log --only analyzeForNotification --project messageai-dev-1f2ec
```

**Expected in Logs:**
- ✅ Should see: `[analyzeForNotification] Logged decision for user v64FPlQvfWTbIskskM9z6nkaj3b2`
- ✅ Should NOT see any errors about permissions or missing collections

**Check Firestore Console:**

Navigate to: `/users/v64FPlQvfWTbIskskM9z6nkaj3b2/notification_decisions/`

**Expected Results:**
- ✅ Should see a NEW document (most recent timestamp)
- ✅ Contains the latest message analysis

**Check iOS App (tester2):**
1. **Open Notification History** again
2. **Pull to refresh** (or close and reopen)

**Expected Results:**
- ✅ New decision appears at the top of the list

---

## ✅ Step 3: Check for Errors

### iOS Console Logs

In Xcode, check the console (Cmd+Shift+Y to show console).

**Look for:**
- ❌ No permission denied errors
- ❌ No "collection not found" errors
- ✅ Should see: `✅ [NotificationHistory] Loaded X history entries`
- ✅ Should see: `✅ [NotificationHistory] Feedback submitted successfully`

### Cloud Function Logs

```bash
firebase functions:log --project messageai-dev-1f2ec
```

**Look for:**
- ❌ No "permission denied" errors
- ❌ No "document not found" errors
- ✅ Successful writes to `users/{userId}/notification_decisions`
- ✅ Successful writes to `users/{userId}/notification_feedback`

---

## ✅ Step 4: Final Verification Summary

### Checklist

Mark each as tested:

- [ ] Firestore Console shows data in new locations
- [ ] Notification History loads correctly in iOS app
- [ ] Can submit feedback (thumbs up/down)
- [ ] Feedback persists after reopening
- [ ] New notifications create decisions in correct location
- [ ] No permission errors in logs
- [ ] No errors in iOS console

### If ALL Tests Pass ✅

**The migration is successful!** You can now:

1. **Delete old collections** to clean up:
   ```bash
   curl -X POST https://us-central1-messageai-dev-1f2ec.cloudfunctions.net/migrateUserCollectionsHTTP \
     -H "Content-Type: application/json" \
     -d '{"dryRun":false,"deleteOld":true}'
   ```

2. **Delete the migration function** (no longer needed):
   ```bash
   firebase functions:delete migrateUserCollectionsHTTP --project messageai-dev-1f2ec
   ```

### If ANY Test Fails ❌

**Don't panic!** Old data is still there as backup.

1. Report what failed
2. Check the specific error messages
3. Revert if needed (old collections still work)

---

## Quick Visual Verification

### Firestore Structure (After Migration)

```
firestore/
├── conversations/              ← Shared (unchanged)
├── messages/                   ← Shared (unchanged)
├── users/
│   └── v64FPlQvfWTbIskskM9z6nkaj3b2/
│       ├── notification_decisions/     ← NEW ✅
│       ├── notification_feedback/      ← NEW ✅
│       ├── rate_limits/default         ← NEW ✅
│       └── activity/current            ← NEW ✅
│
└── [OLD - Can delete after verification]
    ├── notification_decisions/         ← OLD (backup)
    ├── notification_feedback/          ← OLD (backup)
    ├── rate_limits/                    ← OLD (backup)
    └── user_activity/                  ← OLD (backup)
```

---

## Ready to Test?

1. **Open Xcode** → Press Cmd+R
2. **Follow Test 1** (Notification History)
3. **Report back** what you see!
