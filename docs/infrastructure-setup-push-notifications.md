# Infrastructure Setup: Push Notifications & Storage

**Purpose:** Pre-work for Story 2.10 (Push Notifications) that can be completed in parallel with Stories 2.3-2.9.

**Timeline:** 3-5 hours  
**Dependencies:** Firebase project already configured (✅ from Epic 1)  
**Bonus:** Also sets up Firebase Storage for Stories 2.7 & 2.8 (Image/PDF attachments)

---

## Overview

This guide covers **external infrastructure setup** that doesn't touch the iOS codebase. Complete these tasks in parallel with ongoing story development to accelerate Story 2.10 implementation.

### What This Covers
- ✅ Firebase Cloud Functions setup and deployment
- ✅ APNs certificate generation and configuration
- ✅ Firebase Storage setup (bonus for attachment stories)
- ✅ Testing and validation

### What This Does NOT Cover
- ❌ iOS notification permission requests (Story 2.10)
- ❌ FCM token registration in iOS app (Story 2.10)
- ❌ iOS notification handling code (Story 2.10)
- ❌ Deep linking implementation (Story 2.10)

When you reach Story 2.10, the iOS integration will plug into this infrastructure.

---

## Part 1: Firebase Cloud Functions Setup

### Prerequisites
- Node.js 18+ installed
- Firebase CLI installed (`npm install -g firebase-tools`)
- Firebase project already exists (✅ from Epic 1)
- Logged into Firebase CLI (`firebase login`)

### Step 1: Initialize Cloud Functions (15 minutes)

```bash
# Navigate to project root
cd /Users/mfuechec/Desktop/Gauntlet\ Projects/MessageAI

# Initialize Cloud Functions
firebase init functions

# Select:
# - Use existing project (select your MessageAI project)
# - Language: TypeScript
# - ESLint: Yes
# - Install dependencies: Yes
```

This creates:
```
functions/
  ├── src/
  │   └── index.ts
  ├── package.json
  ├── tsconfig.json
  └── .eslintrc.js
```

### Step 2: Install Dependencies (5 minutes)

```bash
cd functions
npm install firebase-admin firebase-functions
```

### Step 3: Write Cloud Function Code (30-45 minutes)

Replace `functions/src/index.ts` with:

```typescript
import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();

/**
 * Cloud Function: Send push notification when new message is created
 * 
 * Triggers on: /messages/{messageId} document creation
 * Action: Sends FCM push notification to all conversation participants except sender
 */
export const sendMessageNotification = functions.firestore
  .document("messages/{messageId}")
  .onCreate(async (snapshot, context) => {
    const message = snapshot.data();
    const messageId = context.params.messageId;

    try {
      // Extract message data
      const senderId = message.senderId;
      const conversationId = message.conversationId;
      const messageText = message.text || "[Media]";
      const timestamp = message.timestamp;

      console.log(`Processing notification for message ${messageId} from ${senderId}`);

      // Fetch conversation to get participants
      const conversationDoc = await admin.firestore()
        .collection("conversations")
        .doc(conversationId)
        .get();

      if (!conversationDoc.exists) {
        console.error(`Conversation ${conversationId} not found`);
        return;
      }

      const conversation = conversationDoc.data();
      const participantIds: string[] = conversation?.participantIds || [];

      // Fetch sender info for notification
      const senderDoc = await admin.firestore()
        .collection("users")
        .doc(senderId)
        .get();

      const senderName = senderDoc.data()?.displayName || "Someone";

      // Determine recipients (all participants except sender)
      const recipientIds = participantIds.filter((id: string) => id !== senderId);

      if (recipientIds.length === 0) {
        console.log("No recipients for notification");
        return;
      }

      // Fetch recipient FCM tokens
      const recipientTokens: string[] = [];
      for (const recipientId of recipientIds) {
        const userDoc = await admin.firestore()
          .collection("users")
          .doc(recipientId)
          .get();

        const userData = userDoc.data();
        
        // Only send notification if user is offline or not in this conversation
        const isOnline = userData?.isOnline || false;
        const currentConversationId = userData?.currentConversationId || null;
        
        // Skip if user is online AND currently viewing this conversation
        if (isOnline && currentConversationId === conversationId) {
          console.log(`Skipping notification for ${recipientId} - already viewing conversation`);
          continue;
        }

        const fcmToken = userData?.fcmToken;
        if (fcmToken) {
          recipientTokens.push(fcmToken);
        }
      }

      if (recipientTokens.length === 0) {
        console.log("No FCM tokens available for recipients");
        return;
      }

      // Build notification payload
      const notificationTitle = conversation.isGroup 
        ? `${senderName} in ${conversation.name || "Group"}`
        : senderName;

      const notificationBody = messageText.length > 100 
        ? `${messageText.substring(0, 97)}...` 
        : messageText;

      // Send notification to all recipients
      const payload = {
        notification: {
          title: notificationTitle,
          body: notificationBody,
          sound: "default",
        },
        data: {
          conversationId: conversationId,
          messageId: messageId,
          senderId: senderId,
          timestamp: timestamp.toString(),
          type: "new_message",
        },
      };

      const response = await admin.messaging().sendToDevice(recipientTokens, payload);

      console.log(`Successfully sent notification to ${recipientTokens.length} devices`);
      console.log(`Success count: ${response.successCount}`);
      console.log(`Failure count: ${response.failureCount}`);

      // Log any failures
      if (response.failureCount > 0) {
        response.results.forEach((result, index) => {
          if (result.error) {
            console.error(`Error sending to token ${recipientTokens[index]}:`, result.error);
          }
        });
      }

      return response;

    } catch (error) {
      console.error("Error sending notification:", error);
      throw error;
    }
  });

/**
 * Cloud Function: Clean up stale typing indicators
 * 
 * Scheduled to run every minute
 * Action: Sets typing status to false for users inactive > 5 seconds
 */
export const cleanupTypingIndicators = functions.pubsub
  .schedule("every 1 minutes")
  .onRun(async (context) => {
    const fiveSecondsAgo = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() - 5000)
    );

    const staleTypingQuery = await admin.firestore()
      .collection("conversations")
      .where("typingUsers", "!=", {})
      .get();

    const batch = admin.firestore().batch();
    let updateCount = 0;

    staleTypingQuery.forEach((doc) => {
      const data = doc.data();
      const typingUsers = data.typingUsers || {};

      // Filter out stale typing indicators
      const updatedTypingUsers: Record<string, any> = {};
      let hasChanges = false;

      for (const [userId, typingData] of Object.entries(typingUsers)) {
        const lastTyping = (typingData as any).lastTyping;
        if (lastTyping && lastTyping > fiveSecondsAgo) {
          updatedTypingUsers[userId] = typingData;
        } else {
          hasChanges = true;
        }
      }

      if (hasChanges) {
        batch.update(doc.ref, { typingUsers: updatedTypingUsers });
        updateCount++;
      }
    });

    if (updateCount > 0) {
      await batch.commit();
      console.log(`Cleaned up ${updateCount} stale typing indicators`);
    }

    return null;
  });
```

### Step 4: Deploy Cloud Functions (10 minutes)

```bash
# From functions/ directory
npm run build

# Deploy to Firebase
firebase deploy --only functions

# Expected output:
# ✔ functions[sendMessageNotification]: Successful create operation.
# ✔ functions[cleanupTypingIndicators]: Successful create operation.
```

### Step 5: Test Cloud Function (15 minutes)

**Option A: Test with Firebase Emulator**

```bash
# Terminal 1: Start emulator with functions
firebase emulators:start --only functions,firestore

# Terminal 2: Trigger test message creation
# (Use Firebase Console or script to create test message)
```

**Option B: Test in Dev Environment**

1. Open Firebase Console → Firestore
2. Manually create a message document in `messages` collection:
   ```json
   {
     "id": "test-message-123",
     "conversationId": "test-conversation-456",
     "senderId": "test-user-1",
     "text": "Testing notifications!",
     "timestamp": <current timestamp>,
     "status": "sent"
   }
   ```
3. Check Cloud Functions logs:
   ```bash
   firebase functions:log
   ```
4. Verify function executed successfully

### Step 6: Configure Environment Variables (Optional, 5 minutes)

If you need environment-specific config:

```bash
firebase functions:config:set notifications.enabled=true
firebase functions:config:set notifications.sound=default

# Deploy with new config
firebase deploy --only functions
```

---

## Part 2: APNs Certificate Configuration

### Prerequisites
- Apple Developer Program membership ($99/year)
- Access to Apple Developer Portal
- Firebase Console access

### Step 1: Generate APNs Auth Key (15 minutes)

1. Go to [Apple Developer Portal](https://developer.apple.com/account)
2. Navigate to **Certificates, Identifiers & Profiles**
3. Select **Keys** from sidebar
4. Click **+** to create new key
5. Name: "MessageAI Push Notifications"
6. Check **Apple Push Notifications service (APNs)**
7. Click **Continue**, then **Register**
8. **Download the .p8 file** (you can only download once!)
9. Note the **Key ID** and **Team ID**

**IMPORTANT:** Store the `.p8` file securely. You cannot re-download it.

### Step 2: Upload APNs Key to Firebase (10 minutes)

1. Open [Firebase Console](https://console.firebase.google.com)
2. Select your MessageAI project
3. Navigate to **Project Settings** (gear icon) → **Cloud Messaging** tab
4. Scroll to **Apple app configuration**
5. Click **Upload** under "APNs Authentication Key"
6. Upload your `.p8` file
7. Enter **Key ID** and **Team ID** from Step 1
8. Click **Upload**

### Step 3: Configure App Bundle ID (5 minutes)

1. In Firebase Console → Cloud Messaging
2. Under "Apple app configuration", click **Add app**
3. Enter your iOS app **Bundle ID**: `com.messageai.MessageAI` (or your actual bundle ID)
4. Download **GoogleService-Info.plist** (if prompted) - you may need to update your iOS app with new version

### Step 4: Verify Configuration (5 minutes)

In Firebase Console → Cloud Messaging:
- ✅ APNs Authentication Key should show "Configured"
- ✅ iOS app should be listed
- ✅ Status should be green checkmark

---

## Part 3: Firebase Storage Setup (Bonus)

*This also unblocks Stories 2.7 (Images) and 2.8 (PDFs)*

### Step 1: Enable Firebase Storage (5 minutes)

1. Open Firebase Console → Storage
2. Click **Get Started**
3. Select **Start in production mode** (we'll configure rules next)
4. Choose storage location (use same region as Firestore for consistency)
5. Click **Done**

### Step 2: Configure Storage Security Rules (10 minutes)

Update `storage.rules` in project root:

```javascript
rules_version = '2';

service firebase.storage {
  match /b/{bucket}/o {
    
    // Helper function: Check if user is authenticated
    function isAuthenticated() {
      return request.auth != null;
    }
    
    // Helper function: Check if user is participant in conversation
    function isParticipant(conversationId) {
      return request.auth.uid in firestore.get(/databases/(default)/documents/conversations/$(conversationId)).data.participantIds;
    }
    
    // Image attachments: /images/{conversationId}/{messageId}/{filename}
    match /images/{conversationId}/{messageId}/{filename} {
      // Allow upload if authenticated and participant
      allow write: if isAuthenticated() && isParticipant(conversationId);
      
      // Allow read if authenticated and participant
      allow read: if isAuthenticated() && isParticipant(conversationId);
    }
    
    // Document attachments: /documents/{conversationId}/{messageId}/{filename}
    match /documents/{conversationId}/{messageId}/{filename} {
      // Allow upload if authenticated and participant
      allow write: if isAuthenticated() && isParticipant(conversationId);
      
      // Allow read if authenticated and participant
      allow read: if isAuthenticated() && isParticipant(conversationId);
    }
    
    // Profile images: /profile-images/{userId}/{filename}
    match /profile-images/{userId}/{filename} {
      // Allow user to upload their own profile image
      allow write: if isAuthenticated() && request.auth.uid == userId;
      
      // Allow any authenticated user to read profile images
      allow read: if isAuthenticated();
    }
    
    // Default: deny all
    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```

### Step 3: Deploy Storage Rules (5 minutes)

```bash
# From project root
firebase deploy --only storage

# Expected output:
# ✔ Deploy complete!
# ✔ storage: released rules storage.rules to firebase.storage
```

### Step 4: Test Storage Access (15 minutes)

**Option A: Test with Firebase Console**

1. Firebase Console → Storage
2. Manually upload test file
3. Try to access via URL (should require authentication)

**Option B: Test with curl (if you have auth token)**

```bash
# Get auth token from iOS app or Firebase Auth REST API
AUTH_TOKEN="your-token-here"

# Try to upload file
curl -X POST \
  -H "Authorization: Bearer $AUTH_TOKEN" \
  -F "file=@test-image.jpg" \
  "https://firebasestorage.googleapis.com/v0/b/YOUR_BUCKET/o?name=images%2Ftest-conversation%2Ftest-message%2Ftest.jpg"
```

### Step 5: Configure Storage Limits (Optional, 5 minutes)

Firebase Console → Storage → Rules:

Add file size limits to rules:

```javascript
// In storage.rules, add to image match block:
match /images/{conversationId}/{messageId}/{filename} {
  allow write: if isAuthenticated() 
    && isParticipant(conversationId)
    && request.resource.size < 2 * 1024 * 1024; // 2MB limit
  
  allow read: if isAuthenticated() && isParticipant(conversationId);
}

// For documents:
match /documents/{conversationId}/{messageId}/{filename} {
  allow write: if isAuthenticated() 
    && isParticipant(conversationId)
    && request.resource.size < 10 * 1024 * 1024; // 10MB limit
  
  allow read: if isAuthenticated() && isParticipant(conversationId);
}
```

Deploy updated rules:
```bash
firebase deploy --only storage
```

---

## Part 4: Update Firebase Configuration (iOS)

### Step 1: Update GoogleService-Info.plist Files (10 minutes)

If you downloaded new `GoogleService-Info.plist` files from Firebase Console (with updated Cloud Messaging config):

1. **For Development:**
   - Replace `MessageAI/Resources/GoogleService-Info-Dev.plist`
   - Verify `GCM_SENDER_ID` is present

2. **For Production:**
   - Replace `MessageAI/Resources/GoogleService-Info-Prod.plist`
   - Verify `GCM_SENDER_ID` is present

3. **Verify in Xcode:**
   - Ensure files have target membership checked
   - Build project to confirm no configuration errors

### Step 2: Verify Firebase Project Settings (5 minutes)

Check `MessageAI/App/Config.swift`:

```swift
// Should already have environment detection from Epic 1
// Verify it's loading correct GoogleService-Info.plist per environment
```

No changes needed if Epic 1 setup was correct.

---

## Validation Checklist

Before considering infrastructure setup complete, verify:

### Cloud Functions
- [ ] `sendMessageNotification` function deployed successfully
- [ ] `cleanupTypingIndicators` function deployed successfully
- [ ] Functions visible in Firebase Console → Functions dashboard
- [ ] Test message creation triggers function (check logs)
- [ ] Function logs show no errors

### APNs Configuration
- [ ] APNs Authentication Key uploaded to Firebase
- [ ] Key shows "Configured" status in Firebase Console
- [ ] iOS app Bundle ID registered
- [ ] No error messages in Cloud Messaging tab

### Firebase Storage
- [ ] Storage enabled in Firebase Console
- [ ] Security rules deployed
- [ ] Test upload succeeds (via console or script)
- [ ] Unauthorized access denied (test with no auth token)
- [ ] File size limits enforced

### Project Configuration
- [ ] GoogleService-Info.plist files updated (if needed)
- [ ] GCM_SENDER_ID present in both Dev and Prod plists
- [ ] iOS app builds without configuration errors

---

## Troubleshooting

### Cloud Functions Won't Deploy

**Error:** `Error: HTTP Error: 403, Unknown Error`

**Solution:**
```bash
# Enable required APIs
gcloud services enable cloudfunctions.googleapis.com
gcloud services enable cloudbuild.googleapis.com

# Retry deployment
firebase deploy --only functions
```

### APNs Key Upload Fails

**Error:** "Invalid Key ID or Team ID"

**Solution:**
- Double-check Key ID from Apple Developer Portal → Keys
- Team ID is your Apple Developer Team ID (10 characters)
- Ensure `.p8` file is unmodified from download

### Storage Rules Deployment Fails

**Error:** `Unexpected token` or syntax error

**Solution:**
- Validate JSON-like syntax (no trailing commas)
- Ensure `rules_version = '2';` at top
- Test rules in Firebase Console → Storage → Rules before deploying

### Cloud Function Not Triggering

**Symptoms:** Message created but no function execution in logs

**Solution:**
1. Check function name matches deployed function: `sendMessageNotification`
2. Verify trigger path: `messages/{messageId}`
3. Check Cloud Functions logs: `firebase functions:log`
4. Ensure Firestore document path is correct: `/messages/message-id`

---

## Next Steps

### When Infrastructure Is Complete

1. ✅ **Mark this document complete** - all validation checkboxes checked
2. ✅ **Document any issues encountered** - add to "Known Issues" section below
3. ✅ **Continue with story sequence** - Stories 2.3-2.9 can proceed
4. ✅ **Story 2.10 ready** - When you reach it, iOS integration will be much faster

### Story 2.10 Will Handle

- iOS notification permission requests
- FCM token registration
- Foreground/background notification handling
- Deep linking from notification to conversation
- Badge count management
- End-to-end testing

### Bonus: Stories 2.7 & 2.8 Ready

Firebase Storage setup also enables:
- Story 2.7: Image attachments (upload/download infrastructure ready)
- Story 2.8: PDF attachments (same infrastructure)

---

## Known Issues

*Document any issues encountered during setup here for future reference:*

- [ ] Issue: ___________
  - Solution: ___________
  - Date: ___________

---

## Time Tracking

Track actual time spent on each part:

| Part | Estimated | Actual | Notes |
|------|-----------|--------|-------|
| Cloud Functions | 1-1.5h | _____ | _____ |
| APNs Config | 30min-1h | _____ | _____ |
| Storage Setup | 30min-1h | _____ | _____ |
| Testing | 30min-1h | _____ | _____ |
| **TOTAL** | **3-5h** | _____ | _____ |

---

## Resources

- [Firebase Cloud Functions Documentation](https://firebase.google.com/docs/functions)
- [APNs Setup Guide](https://developer.apple.com/documentation/usernotifications)
- [Firebase Cloud Messaging](https://firebase.google.com/docs/cloud-messaging)
- [Firebase Storage Security Rules](https://firebase.google.com/docs/storage/security)

---

**Status:** 🔄 In Progress  
**Last Updated:** October 21, 2025  
**Completed By:** ___________  
**Sign-off Date:** ___________

