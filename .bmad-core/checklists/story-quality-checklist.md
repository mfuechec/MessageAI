# Story Quality Checklist

**Purpose:** Catch architectural issues, missing edge cases, and incomplete acceptance criteria BEFORE development starts.

**When to Use:**
- SM: During story drafting (before submission to PO)
- PO: During story review (before approval for dev)

**How to Use:** Check each item. If "No" or "Unsure", add to story or create follow-up task.

---

## Section 1: Acceptance Criteria Completeness

### ✅ Core Functionality

- [ ] **AC covers happy path** - Normal user flow described
- [ ] **AC covers error cases** - What happens when operations fail
- [ ] **AC has measurable targets** - Performance metrics specified (e.g., "< 2 seconds", "< 2MB")
- [ ] **AC specifies UI feedback** - User sees clear success/failure messages
- [ ] **AC includes all states** - Loading, success, error, empty states covered

### ✅ Edge Cases & Boundary Conditions

- [ ] **Offline behavior defined** - What happens without network?
- [ ] **Account switching covered** - Multi-user device scenarios handled
- [ ] **Race conditions addressed** - Concurrent operations don't conflict
- [ ] **Empty state handling** - What if data doesn't exist yet? (e.g., deep link to conversation not loaded)
- [ ] **Quota/limit handling** - File size limits, storage quotas, rate limits
- [ ] **Timeout scenarios** - Long-running operations have timeout behavior

### ✅ Data Persistence & Cleanup

- [ ] **Data cleanup on sign-out** - User-specific data cleared (FCM tokens, cached state)
- [ ] **Temporary file cleanup** - Temp storage cleaned up after use
- [ ] **Memory management** - Large data not held in memory indefinitely
- [ ] **Database migration** - Entity changes have migration strategy

---

## Section 2: Architectural Quality

### ✅ State Management

- [ ] **No global static variables** - Or justified with clear reasoning
  - ⚠️ **Red Flag:** `static var currentState: SomeType?`
  - ✅ **Better:** AppState class or dependency injection
- [ ] **State cleared on lifecycle events** - Sign-out, app termination, view dismissal
- [ ] **Thread-safe state updates** - @MainActor or proper synchronization
- [ ] **State persists across crashes** - Critical state saved to disk, not just memory

### ✅ Error Handling & Retry Logic

- [ ] **Network errors have retry** - Exponential backoff for transient failures
- [ ] **User sees meaningful errors** - Not just "Error occurred"
- [ ] **Critical operations logged** - Failures logged for debugging
- [ ] **Fallback behavior defined** - What happens if retry fails? (queue, skip, prompt user)

### ✅ Dependency Management

- [ ] **Dependencies injected** - Not hard-coded singletons
- [ ] **Protocols used for abstraction** - ViewModels depend on protocols, not concrete classes
- [ ] **Mock repositories for testing** - All new protocols have mock implementations
- [ ] **DIContainer updated** - Factory methods added for new ViewModels

### ✅ Data Structures & Storage

- [ ] **Large data not in UserDefaults** - Use file system for >100KB data
  - ⚠️ **Red Flag:** Storing images, large JSON in UserDefaults
  - ✅ **Better:** Temporary directory + lightweight metadata in UserDefaults
- [ ] **Firestore writes batched** - Multiple related writes use batch operations
- [ ] **Query limits enforced** - No unbounded queries (use `.limit(to:)`)
- [ ] **Indexes defined** - Complex queries have composite indexes

---

## Section 3: Security & Privacy

### ✅ Authentication & Authorization

- [ ] **User identity validated** - Operations verify current user
- [ ] **Permissions checked** - Cloud Functions validate participant membership
- [ ] **Sensitive data encrypted** - Passwords, tokens handled securely
- [ ] **Data isolation enforced** - Users can't access other users' data

### ✅ Data Privacy

- [ ] **Soft delete for sensitive data** - User-generated content uses isDeleted flag
- [ ] **PII removed on deletion** - Message text cleared, not just marked deleted
- [ ] **FCM tokens removed on sign-out** - Push tokens don't leak across accounts
- [ ] **Firestore security rules match app logic** - Server-side rules mirror client-side checks

---

## Section 4: Performance & Scalability

### ✅ Performance Targets

- [ ] **Response time targets defined** - Explicit AC for operation duration
- [ ] **Network payload limits** - File uploads have size limits (e.g., 2MB images, 10MB PDFs)
- [ ] **Pagination for large datasets** - Messages, conversations, user lists paginated
- [ ] **Caching strategy defined** - When to cache, when to invalidate

### ✅ Resource Management

- [ ] **Memory usage bounded** - Caches have eviction policies (LRU, size limits)
- [ ] **Image compression applied** - Large images compressed before upload
- [ ] **Background tasks cancellable** - Long-running operations can be cancelled
- [ ] **Observers cleaned up** - Firestore listeners, Combine subscriptions cancelled on deinit

---

## Section 5: Testing Coverage

### ✅ Unit Tests

- [ ] **New methods have tests** - All public methods tested
- [ ] **Edge cases tested** - Nil values, empty arrays, boundary conditions
- [ ] **Error paths tested** - Verify error handling logic works
- [ ] **Mock repositories created** - New protocols have mock implementations
- [ ] **Test coverage target met** - 70%+ coverage for new code

### ✅ Integration Tests

- [ ] **End-to-end scenario defined** - Manual test or Firebase Emulator test
- [ ] **Multi-device testing planned** - If real-time sync, test with 2+ devices
- [ ] **Physical device testing noted** - If simulator insufficient (e.g., push notifications)

### ✅ Regression Tests

- [ ] **Regression AC included** - "Existing feature X still works"
- [ ] **Epic-level tests run** - `./scripts/test-epic.sh N` passes
- [ ] **Performance regression checks** - Ensure new features don't slow down existing features

---

## Section 6: Code Samples & Documentation

### ✅ Implementation Guidance

- [ ] **Code samples provided** - Key methods have example implementations (100+ lines for complex features)
- [ ] **File locations specified** - Exactly which files to modify
- [ ] **Import statements included** - Required framework imports listed
- [ ] **Task breakdown detailed** - Subtasks small enough for dev agent to execute

### ✅ Edge Case Handling Code

- [ ] **Retry logic code provided** - Don't just say "add retry", show how
- [ ] **Cleanup code provided** - Temp file deletion, state reset examples
- [ ] **Error mapping code provided** - How to convert framework errors to user-friendly messages

---

## Section 7: User Experience

### ✅ UI/UX Clarity

- [ ] **Loading states defined** - What user sees during async operations
- [ ] **Success feedback specified** - Confirmation messages, animations
- [ ] **Error feedback specified** - Clear error messages, retry options
- [ ] **Accessibility considered** - VoiceOver labels, color contrast

### ✅ Permissions & Onboarding

- [ ] **Permission timing optimal** - Don't ask for permissions too early
- [ ] **Permission denial handled** - App works without optional permissions
- [ ] **Settings deep link provided** - User can re-enable denied permissions
- [ ] **First-time user flow** - Onboarding clear for new users

---

## Section 8: Story Meta-Quality

### ✅ Story Document Structure

- [ ] **Status clear** - Draft / Ready for Review / Approved / In Progress / Done
- [ ] **User story format** - "As a [user], I want [feature], so that [benefit]"
- [ ] **Previous story context included** - Learnings from prior stories applied
- [ ] **"What's NEW" section clear** - Distinguishes new code from existing infrastructure
- [ ] **Change log maintained** - Version history tracked

### ✅ Dependencies & Blockers

- [ ] **Story dependencies identified** - "Blocked by Story X" if applicable
- [ ] **External dependencies noted** - TestFlight access, API keys, certificates
- [ ] **Deferred items documented** - What's intentionally postponed to post-MVP

---

## Red Flags (Auto-Fail)

If story has ANY of these, send back for revision:

- ❌ **Global static variables without justification** (high coupling, testing issues)
- ❌ **No error handling code** (every network call needs error handling)
- ❌ **No retry logic for critical operations** (FCM token save, message send)
- ❌ **UserDefaults for large data** (images, large JSON)
- ❌ **Unbounded Firestore queries** (missing `.limit(to:)`)
- ❌ **No cleanup on sign-out** (FCM tokens, static state)
- ❌ **Missing AC for edge cases** (offline, account switching, empty states)
- ❌ **No regression testing** (might break existing features)
- ❌ **Performance targets missing** (how fast is fast enough?)
- ❌ **No test plan** (unit tests or manual test checklist)

---

## Checklist Summary

**For SM (during drafting):**
- Run this checklist BEFORE submitting to PO
- Fix red flags immediately
- Document any "No" answers as follow-up tasks

**For PO (during review):**
- Run this checklist on story document
- Any red flags = send back to SM
- Minor gaps = note as enhancements, approve story

**Story is READY when:**
- ✅ All sections addressed (or consciously deferred with rationale)
- ✅ Zero red flags
- ✅ Code samples comprehensive (200+ lines for complex features)
- ✅ Test plan complete (unit + integration + manual)
- ✅ Dev agent can implement without asking clarifying questions

---

## Version History

| Date | Version | Changes |
|------|---------|---------|
| 2024-10-22 | 1.0 | Initial checklist based on Story 2.7 and 2.10 review learnings |
