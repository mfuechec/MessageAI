# Firebase Storage Setup Guide

The profile image upload error you saw indicates Firebase Storage needs to be configured properly.

## Quick Fix: Update Firebase Storage Rules

1. **Open Firebase Console**: https://console.firebase.google.com
2. **Select your project**: MessageAI
3. **Navigate to Storage**: Left sidebar → Build → Storage
4. **Click "Rules" tab**

### Set These Rules:

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Allow authenticated users to upload their own profile images
    match /users/{userId}/profile.jpg {
      allow read: if true; // Anyone can read profile images
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Future: Allow authenticated users to upload message attachments
    match /messages/{conversationId}/{fileName} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
    
    // Deny everything else by default
    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```

### What These Rules Do:

1. **Profile Images** (`users/{userId}/profile.jpg`):
   - ✅ Anyone can read (public profile images)
   - ✅ Only the user themselves can upload their own profile image
   - ✅ Prevents users from uploading images for other users

2. **Message Attachments** (future):
   - ✅ Only authenticated users can read/write
   - ✅ Ready for Story 2.7/2.8 (image/PDF attachments)

3. **Default Deny**:
   - ❌ Everything else is blocked

## Testing After Rule Update:

1. Click **Publish** in Firebase Console
2. Wait ~10 seconds for rules to propagate
3. Try uploading a profile image in the app again
4. You should see:
   - ✅ Upload progress
   - ✅ Image appears in profile
   - ✅ Image saved to Firebase Storage
   - ✅ Download URL saved to Firestore

## Verifying Upload Success:

### In Firebase Console:

1. **Storage** → Files tab
2. Look for: `users/{your-user-id}/profile.jpg`
3. Click file to see details and download URL

### In Firestore:

1. **Firestore Database** → users collection
2. Find your user document
3. Check `profileImageURL` field has a URL like:
   ```
   https://firebasestorage.googleapis.com/v0/b/...
   ```

## Error Messages You'll See Now:

- ✅ **"Storage permissions not configured"** → Check Firebase Console rules
- ✅ **"You must be signed in to upload images"** → User not authenticated
- ✅ **"Unable to process the image"** → Image compression failed
- ✅ **"Unable to upload image. Please check your connection"** → Network error

All errors are now user-friendly! 🎉

