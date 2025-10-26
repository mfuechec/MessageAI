# NetworkMonitor: False Offline Banner Fix (Oct 26, 2024)

## Session Overview

Fixed critical bug where offline banner incorrectly appeared after login despite being online. Root cause was improper handling of Firestore's initial cached snapshot and state not being reset between authentication sessions.

## Problem Description

### Symptoms
- User logs in → offline banner appears immediately
- User was online (verified network connection working)
- Logs showed `isOffline=true` even though network was available
- Issue occurred both on first login AND when logging out/in with different accounts

### Root Cause Analysis

**Three interconnected bugs:**

1. **Time-based grace period started too early**
   - `appLaunchTime` set when app launched (before authentication)
   - Firestore monitoring couldn't start until after login (requires authenticated user)
   - By the time user completed profile setup and reached ConversationsListView, grace period had expired
   - First cached snapshot processed as real "offline" event

2. **First snapshot not treated specially**
   - Firestore's first snapshot is ALWAYS from cache when offline
   - This is expected behavior (offline persistence)
   - Grace period logic used time-based check, but timing varies based on user actions
   - Should have been snapshot-count-based: "First snapshot ever? Ignore if cached."

3. **State not reset on account switching**
   - `hasReceivedFirstSnapshot` flag never reset when logging out and back in
   - Old Firestore listener not removed when setting up new one
   - Second login reused same `NetworkMonitor` instance but flag was `true` from previous session
   - New user's first snapshot wasn't treated as "first" → false offline detection

## What Was Built

### 1. Snapshot-Count-Based First Snapshot Handling (100% Complete)

**Old Logic** (time-based):
```swift
// If within 3 seconds of app launch, ignore offline states
let timeSinceLaunch = Date().timeIntervalSince(appLaunchTime)
if timeSinceLaunch < 3.0 {
    // Ignore offline
}
```

**New Logic** (snapshot-count-based):
```swift
// First snapshot EVER? Unconditionally ignore if offline
if !hasReceivedFirstSnapshot {
    hasReceivedFirstSnapshot = true
    if isConnected {
        isFirestoreConnected = true  // Update immediately
    } else {
        // IGNORE - always cached on first snapshot
    }
    return
}

// Subsequent snapshots: use time-based grace period
```

**Why This Works:**
- First snapshot timing varies (depends on user actions: profile setup, etc.)
- Cached snapshots are EXPECTED on initial connection
- Only real connectivity changes after first snapshot matter

**Location**: `MessageAI/Presentation/Utils/NetworkMonitor.swift:264-281`

### 2. State Reset on Authentication (100% Complete)

**Problem**: Same `NetworkMonitor` instance used across logout/login sessions

**Solution**: Reset monitoring state when setting up Firestore listener
```swift
private func setupFirestoreMonitoring() {
    // Remove existing listener (handles account switching)
    if let existingListener = firestoreListener {
        existingListener.remove()
        firestoreListener = nil
    }

    // Reset state for THIS monitoring session
    hasReceivedFirstSnapshot = false  // ✅ NEW: Reset flag
    appLaunchTime = Date()            // ✅ Reset grace period timer

    // Set up new listener for current user...
}
```

**Location**: `MessageAI/Presentation/Utils/NetworkMonitor.swift:213-237`

### 3. Updated Retry Logic (100% Complete)

**Old Behavior**: Only set up listener if none existed
```swift
guard firestoreListener == nil, Auth.auth().currentUser != nil else {
    return  // Exit if listener already exists
}
```

**New Behavior**: Always set up when called (cleanup handled in setup)
```swift
guard Auth.auth().currentUser != nil else {
    return  // Only check for authenticated user
}
setupFirestoreMonitoring()  // Will clean up old listener if exists
```

**Why**: Supports account switching. Each login needs fresh listener for new user's document.

**Location**: `MessageAI/Presentation/Utils/NetworkMonitor.swift:322-330`

## Files Modified

```
✅ MessageAI/Presentation/Utils/NetworkMonitor.swift
   - setupFirestoreMonitoring() - Added listener cleanup and state reset (lines 216-237)
   - Snapshot listener handler - Unconditional first snapshot ignore (lines 264-281)
   - retryFirestoreMonitoring() - Removed listener existence guard (lines 322-330)
```

## Key Technical Decisions

### 1. Snapshot-Count-Based vs Time-Based Grace Period

**Decision**: Use snapshot-count for first snapshot, time-based for subsequent

**Rationale**:
- First snapshot timing is unpredictable (depends on user actions)
- Cached first snapshot is EXPECTED behavior, not an error condition
- Subsequent snapshots during grace period are also likely cached
- Two-tier approach gives best of both: reliable first snapshot + startup protection

**Alternative Rejected**: Pure time-based grace period
- Can't account for variable user behavior (profile setup time)
- Grace period would need to be very long (10+ seconds)
- Would delay legitimate offline detection

### 2. State Reset Location

**Decision**: Reset state in `setupFirestoreMonitoring()`, not `retryFirestoreMonitoring()`

**Rationale**:
- `setupFirestoreMonitoring()` is single source of truth for listener creation
- Keeps state reset logic co-located with listener setup
- Works for both initial setup AND retry scenarios

**Alternative Rejected**: Reset in `retryFirestoreMonitoring()`
- Would miss initial setup case (if user already authenticated)
- Duplicates logic across multiple code paths

### 3. Listener Cleanup Strategy

**Decision**: Remove old listener at START of setup, not in separate cleanup method

**Rationale**:
- Ensures no overlapping listeners (prevents duplicate events)
- Atomic operation: remove old, create new
- No window where both listeners exist
- No window where no listener exists

**Alternative Rejected**: Separate `cleanupFirestoreMonitoring()` method
- Adds complexity (when to call it?)
- Risk of forgetting to call cleanup before setup

## Testing Strategy

### Manual Testing

**Test Case 1: Fresh Login**
1. Clean app install (or logout)
2. Login with user account
3. Complete profile setup
4. Navigate to conversations list
5. **Expected**: No offline banner appears
6. **Expected Logs**:
   ```
   🔥 [NetworkMonitor] Reset monitoring state (first snapshot flag + grace period timer)
   🔥 [NetworkMonitor] 🎯 FIRST SNAPSHOT RECEIVED (fromCache: true)
   🔥 [NetworkMonitor] 🚫 First snapshot shows OFFLINE - ignoring unconditionally
   ```

**Test Case 2: Account Switching**
1. Login with user A
2. Navigate to conversations
3. Logout
4. Login with user B
5. Navigate to conversations
6. **Expected**: No offline banner on user B's session
7. **Expected Logs**: Should see "Removed existing Firestore listener"

**Test Case 3: Real Offline Detection**
1. Login normally (should work without banner)
2. Turn off WiFi/network
3. **Expected**: Offline banner appears after ~2 seconds
4. Turn network back on
5. **Expected**: "Back online" toast appears

### Automated Testing

**Note**: Existing `NetworkMonitorTests.swift` covers basic functionality. Should add:
- Test for `hasReceivedFirstSnapshot` reset on `setupFirestoreMonitoring()`
- Test for listener cleanup when calling setup twice
- Test for grace period timing after state reset

## Known Limitations

1. **Simulator Network Quirks**
   - iOS Simulator has unreliable network status reporting
   - NWPathMonitor may show incorrect states during development
   - Testing on real device recommended for network edge cases

2. **Grace Period Still Time-Based for Subsequent Snapshots**
   - After first snapshot, still uses 3-second grace period
   - Could theoretically miss rapid offline/online transitions during this window
   - Acceptable tradeoff for preventing false positives

3. **No Explicit Logout Handling**
   - `NetworkMonitor` doesn't listen for logout events
   - Relies on next login to trigger cleanup
   - Old listener stays active until app termination or re-login
   - Could add observer for auth state changes to proactively clean up

## Architecture Patterns Established

### Two-Tier Grace Period Pattern
```swift
// Tier 1: First snapshot EVER - unconditional ignore if offline
if !hasReceivedFirstSnapshot {
    if offline { return }  // ALWAYS ignore
}

// Tier 2: Subsequent snapshots - time-based grace period
if withinGracePeriod {
    if offline { return }  // Ignore during startup window
}

// Normal operation: trust all snapshots
```

### Stateful Monitoring with Reset Pattern
```swift
class NetworkMonitor {
    private var hasReceivedFirstSnapshot = false
    private var appLaunchTime = Date()

    private func setupFirestoreMonitoring() {
        // 1. Clean up old state
        firestoreListener?.remove()

        // 2. Reset tracking variables
        hasReceivedFirstSnapshot = false
        appLaunchTime = Date()

        // 3. Create new listener
        firestoreListener = db.collection("users").document(userId)
            .addSnapshotListener { ... }
    }
}
```

### Listener Lifecycle Management Pattern
```swift
// Always clean up before creating new listener
if let existingListener = firestoreListener {
    existingListener.remove()
    firestoreListener = nil
}

// Now safe to create new listener
firestoreListener = db.collection(...)
```

## Future Enhancements

1. **Explicit Logout Handler**
   - Listen for auth state changes
   - Proactively remove Firestore listener on logout
   - Clean up state immediately instead of waiting for next login

2. **Network Quality Indicator**
   - Beyond binary online/offline
   - Show "slow connection" warning
   - Use NWPathMonitor's `isExpensive` and `isConstrained` properties

3. **Adaptive Grace Period**
   - Shorter grace period on app resume (user expects fast updates)
   - Longer grace period on cold start (more cache loading)
   - Track app lifecycle events

4. **Comprehensive Logging Mode**
   - Toggle verbose network logs in DEBUG builds
   - Export network status history for debugging
   - Timeline view of connectivity changes

## Related Stories

- **Story 2.11: Performance Optimization & Network Resilience** - Network monitoring implementation
- **Story 2.9: Offline Message Queue** - Offline state handling
- **Epic 2: Complete MVP with Reliability** - Network resilience requirements

## Success Metrics

- ✅ Build successful (no compilation errors)
- ✅ Offline banner no longer appears incorrectly on login
- ✅ Account switching works without false offline detection
- ✅ Real offline events still trigger banner correctly
- ✅ Detailed logging for debugging connectivity issues

## Verification Steps

1. **Build & Run**
   ```bash
   ./scripts/build.sh
   # Expected: Build succeeds
   ```

2. **Fresh Login Test**
   - Clean install → Login → No offline banner

3. **Account Switch Test**
   - Login user A → Logout → Login user B → No offline banner

4. **Real Offline Test**
   - Turn off WiFi → Banner appears → Turn on WiFi → Banner disappears

5. **Log Verification**
   - Check for "🎯 FIRST SNAPSHOT RECEIVED" log
   - Check for "🚫 First snapshot shows OFFLINE - ignoring unconditionally"
   - Check for "Reset monitoring state" on each login
