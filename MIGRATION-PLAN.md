# Firestore Migration Plan

## Current Status

✅ All code updated to new structure
✅ Cloud Functions deployed
✅ Security rules deployed
✅ iOS app built
⏳ **Need to run migration to move existing data**

## Data to Migrate

Based on earlier logs, we have:
- **notification_decisions**: Multiple entries (at least 4-5 for tester2@gmail.com)
- **notification_feedback**: Multiple entries (4-5 feedback submissions)
- **rate_limits**: Likely 1-2 entries
- **user_activity**: Likely 1-2 entries
- **user_context_cache**: Unknown count

## Migration Options

### Option 1: Manual via Firestore Console (Safest)

1. Open [Firebase Console](https://console.firebase.google.com/project/messageai-dev-1f2ec/firestore)
2. **DRY RUN - Just look at what exists:**
   - Check `notification_decisions` collection - count documents
   - Check `notification_feedback` collection - count documents
   - Check `rate_limits` collection - count documents
   - Check `user_activity` collection - count documents
   - Check `user_context_cache` collection - count documents

3. **Manually copy a single document to test:**
   - Pick one notification_decision document
   - Note the `userId` field
   - Create: `/users/{userId}/notification_decisions/{same-doc-id}`
   - Copy all fields from old doc to new doc
   - Test that iOS app can read it

4. **If test works, continue manually or use function**

### Option 2: Via Cloud Function (Recommended)

The `migrateUserCollections` function is deployed at:
`https://us-central1-messageai-dev-1f2ec.cloudfunctions.net/migrateUserCollections`

**Step 1: DRY RUN**
```bash
# Call function with authentication
firebase functions:shell --project messageai-dev-1f2ec
# Then run:
migrateUserCollections({ dryRun: true, deleteOld: false })
```

**Step 2: MIGRATE (keep originals)**
```bash
migrateUserCollections({ dryRun: false, deleteOld: false })
```

**Step 3: VERIFY**
- Check new locations in Firestore
- Test iOS app
- Test feedback submission
- Test notification history

**Step 4: CLEANUP (optional)**
```bash
migrateUserCollections({ dryRun: false, deleteOld: true })
```

### Option 3: Add Test Button to iOS App

Add a button in Settings that calls `migrateUserCollections` via Firebase Functions.

## What to Check After Migration

### 1. Firestore Console
```
✅ /users/{userId}/notification_decisions/* - Should have entries
✅ /users/{userId}/notification_feedback/* - Should have entries
✅ /users/{userId}/rate_limits/default - Should exist
✅ /users/{userId}/activity/current - Should exist (if user was active)
```

### 2. iOS App Tests
- ✅ Open Notification History → Should show past decisions
- ✅ Submit feedback (thumbs up/down) → Should work
- ✅ Check feedback persists after reopening history
- ✅ Send a test message → Should trigger notification analysis

### 3. Cloud Function Logs
```bash
firebase functions:log --only analyzeForNotification --project messageai-dev-1f2ec
```
Should show successful writes to new paths like:
`users/{userId}/notification_decisions/{id}`

## Current Data Estimate

From earlier logs (approximate):
- **tester2@gmail.com** (v64FPlQvfWTblskskM9z6nkaj3b2):
  - 4-5 notification decisions
  - 4-5 feedback submissions
  - 1 rate limit entry
  - 1 activity entry

Total documents to migrate: ~10-15

## Rollback Plan (if needed)

If migration fails or causes issues:

1. **Old data is still there** (unless you used `deleteOld: true`)
2. **Revert code:**
   ```bash
   git revert HEAD  # Revert latest commit
   firebase deploy --only functions,firestore:rules --project messageai-dev-1f2ec
   ```
3. **Or just delete new subcollections** and keep using old structure

## Next Steps

**Recommendation: Start with Manual Test (Option 1)**

1. Check Firestore Console to see what exists
2. Manually copy ONE document to test
3. Verify iOS app can read it
4. If successful, run full migration via Cloud Function

**Ready to proceed?**
