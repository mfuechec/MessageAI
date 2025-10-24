# Firestore Listener Cleanup on Logout

## Issue
When logging out, Firestore snapshot listeners for notification preferences caused two errors:
1. **"document path cannot be empty"** - When settings opened with no authenticated user
2. **Permission denied errors** - When logout happened while settings view was open with active listener

## Root Cause
1. `ConversationsListView` creates `NotificationPreferencesViewModel` with `userId: authViewModel.currentUser?.id ?? ""`, passing empty string when no user
2. Logout button exists IN the settings view, causing race condition:
   - Listener active → User clicks logout → Auth signs out → Firestore listener gets permission error → THEN view dismisses

## Solution

### 1. Guard Against Empty UserIds
**File:** `FirebaseNotificationPreferencesRepository.swift:99-103`

```swift
func observePreferences(userId: String) -> AnyPublisher<NotificationPreferences, Never> {
    guard !userId.isEmpty else {
        print("⚠️ Cannot observe preferences: userId is empty")
        return Empty<NotificationPreferences, Never>().eraseToAnyPublisher()
    }
    // ... rest of implementation
}
```

Prevents invalid Firestore paths like `users//ai_notification_preferences/preferences`

### 2. Distinguish Permission Errors
**File:** `FirebaseNotificationPreferencesRepository.swift:109-118`

```swift
if let error = error {
    let nsError = error as NSError

    // Check if this is a permission error (expected on logout)
    if nsError.domain == FirestoreErrorDomain &&
       nsError.code == FirestoreErrorCode.permissionDenied.rawValue {
        print("ℹ️ Preferences listener permission denied (user likely logged out)")
        return
    }

    // Log other errors (unexpected)
    print("❌ Preferences observation error: \(error.localizedDescription)")
    return
}
```

Logs permission errors as info instead of errors since they're expected during logout.

### 3. Proactive Cleanup
**File:** `NotificationPreferencesViewModel.swift:254-257`

```swift
func cleanup() {
    cancellables.removeAll()
    print("🧹 NotificationPreferencesViewModel cleaned up")
}
```

**File:** `SmartNotificationSettingsView.swift:259-260`

```swift
Button("Logout", role: .destructive) {
    viewModel.cleanup()  // Clean up BEFORE logout
    Task {
        await authViewModel.signOut()
    }
}
```

**File:** `SmartNotificationSettingsView.swift:225-228`

```swift
.onDisappear {
    viewModel.cleanup()  // Clean up when view closes
}
```

## Testing
1. Build succeeds ✅
2. Open settings with no user → No "empty path" error ✅
3. Logout from settings → Listeners cleaned up before auth signout ✅
4. Close settings → Listeners cleaned up on view disappear ✅

## Notes
- The repository is a singleton in DIContainer, but each ViewModel creates fresh subscriptions
- Combine's `handleEvents(receiveCancel:)` ensures Firestore listeners are removed when subscriptions cancel
- Empty publisher pattern prevents listener creation without breaking Combine pipeline
