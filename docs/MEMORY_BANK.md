# MessageAI Development Memory Bank

This file tracks key decisions, implementation patterns, and learnings across development sessions.

## Latest Session: UX Improvements - Priority Badges & Deleted Message Handling (Oct 24, 2024)

**Full details**: See `docs/memory-bank/ux-improvements-badges-deleted-messages.md`

**Quick Summary**:
- ✅ Added priority badges to conversation list (orange `[!N]` badge for urgent messages)
- ✅ Adaptive unread badge color (red for urgent, blue for normal)
- ✅ Fixed Cloud Function to sync priority metadata to conversation documents
- ✅ Fixed deleted message handling to show next non-deleted message instead of "[Message deleted]"
- ✅ Deployed Cloud Function updates to `messageai-dev-1f2ec`

**Key Files Modified**:
- `ConversationRowView.swift` - Badge UI components
- `functions/src/summarizeThread.ts` - Priority metadata sync
- `ChatViewModel.swift` - Smart deleted message fallback

---

## Previous Session: Story 3.2 Completion - Comprehensive AI Analysis & Test Infrastructure (Oct 23, 2024)

### What Was Built

**1. Cloud Function: Test Message Population (100% Complete)**
- ✅ `populateTestMessages` Cloud Function
  - Bypasses Firestore security rules using admin privileges
  - Creates 24 realistic multi-participant messages
  - Includes action items, priority messages, decisions, and regular conversation
  - Messages from 3 different users (current user + 2 participants)
  - Validates conversation membership before populating
  - Returns message count and timestamp
- ✅ Swift integration via `CloudFunctionsService.callPopulateTestMessages()`
- ✅ DEBUG-only flask button (🧪) in chat toolbar triggers population
- **Why Important**: Allows realistic AI testing with multi-user conversations that client-side code cannot create

**2. Comprehensive AI Analysis View (100% Complete)**
- ✅ Single unified view showing all AI insights
- ✅ Four sections in order:
  1. **📝 Summary** (Gray) - Ultra-concise 1-2 sentences (20-30 words)
  2. **⚠️ Priority Messages** (Orange) - Bullet points for urgent items
  3. **✅ Action Items** (Blue) - Bullet points with assignees/deadlines
  4. **🎯 Decisions** (Green) - Bullet points for team decisions
- ✅ Condensed bullet-point format (1-2 lines per item)
- ✅ Removed "Key Points" section (redundant)
- ✅ Compact metadata footer (participants + date range in one line)
- ✅ Changed button from "Summarize Thread" to "✨ AI Analysis"

**3. AI Prompt Optimization**
- ✅ Updated `summarizeThread` Cloud Function prompt
- ✅ Changed from "150-300 words" to "20-30 words MAXIMUM"
- ✅ System message: "Exactly 1-2 sentences (20-30 words MAXIMUM)"
- ✅ Reduced max_tokens from 500 → 200
- ✅ Removed frontend line limit (no longer needed)
- **Result**: AI generates properly sized summaries instead of frontend truncation

**4. Bug Fixes**
- ✅ **Firestore Security Rules**: Fixed read receipts permission error
  - Simplified rules to allow participant updates (transforms like `arrayUnion`, `increment`, `serverTimestamp` couldn't be validated by `diff().affectedKeys()`)
- ✅ **Avatar Blinking**: Fixed profile image flickering on new messages
  - Added URL tracking via `objc_setAssociatedObject` to skip redundant reconfiguration
  - Check Kingfisher memory cache synchronously before setting initials placeholder
- ✅ **Group Chat Titles**: Fixed showing only one participant name
  - Changed to use `NewConversationViewModel.users` (has all users) instead of `ConversationsListViewModel.users` (may not be populated yet for new conversations)
- ✅ **Auto-scroll**: Fixed conversation not scrolling to latest message
  - Bulk adds (5+ messages) now always scroll to bottom
  - Small incremental adds also scroll to bottom

### Files Created

```
✅ functions/src/populateTestMessages.ts (172 lines)
```

### Files Modified

```
✅ functions/src/summarizeThread.ts - Ultra-concise summary prompt
✅ functions/src/index.ts - Export populateTestMessages
✅ firestore.rules - Simplified participant update rules
✅ MessageAI/Data/Network/CloudFunctionsService.swift - Added callPopulateTestMessages()
✅ MessageAI/Presentation/ViewModels/Chat/ChatViewModel.swift - Updated populateTestMessages() to call Cloud Function
✅ MessageAI/Presentation/Views/Chat/ChatView.swift - Added flask button, fixed scrolling, fixed avatars, simplified AI menu
✅ MessageAI/Presentation/Views/SummaryView.swift - Comprehensive 4-section layout, condensed format
✅ MessageAI/Presentation/Views/Conversations/ConversationsListView.swift - Fixed group chat title bug
```

### Key Technical Decisions

**1. Cloud Function vs Client-Side for Test Data**
- **Decision**: Use Cloud Function with admin privileges for test message population
- **Rationale**:
  - Firestore security rules prevent creating messages from other users (correct security)
  - AI features need realistic multi-user conversations to test properly
  - Action item extraction requires knowing who said what
  - Priority detection depends on sender identity
  - Decision tracking needs to identify decision makers
- **Alternative Rejected**: Client-side test messages all from current user
  - Would show as single-sided conversation (all blue bubbles)
  - AI couldn't extract "Sarah needs to finish report" (all messages from "You")
  - No way to test sender-dependent features

**2. Comprehensive View vs Separate Screens**
- **Decision**: Single "AI Analysis" view with 4 sections
- **Rationale**:
  - Faster user workflow (one tap vs multiple taps)
  - Better context (see priorities alongside decisions)
  - More scannable (everything in one scroll)
  - Reduces navigation complexity
- **Alternative Rejected**: Separate screens for each feature
  - Would require 4 separate menu items
  - Users would need to open each individually
  - Harder to see relationships between insights

**3. Ultra-Concise Summaries (20-30 words)**
- **Decision**: Force AI to generate 20-30 word summaries
- **Rationale**:
  - Original summaries were 150-300 words (too long for mobile)
  - Frontend truncation looked bad (mid-sentence cutoff)
  - Users want quick glance, not essay
  - Other sections provide detail
- **Implementation**: Updated prompt with strict word limits, reduced max_tokens
- **Before**: "The team discussed various aspects of their project, including design mockups, quarterly reports, architecture decisions, budget finalization, and technical choices like using PostgreSQL. Immediate issues such as..."
- **After**: "Team discussed project updates including design mockups, reports, and decided to use PostgreSQL for architecture."

**4. Security Rules Simplification**
- **Decision**: Remove `diff().affectedKeys()` validation for participant updates
- **Rationale**:
  - Firestore transform operations (`arrayUnion`, `increment`, `serverTimestamp`) can't be validated by `diff()`
  - Transforms are sentinel values processed server-side
  - Security is still enforced via `isParticipant()` check
  - Application logic controls which fields get updated
- **Risk**: Participants could theoretically update any message field
- **Mitigation**: Trust application code (Clean Architecture ensures only repository updates messages)

### Test Message Content Structure

**Populated messages include clear patterns for each AI feature:**

1. **Priority Messages**:
   - "URGENT: Production server is down! Need immediate attention"
   - "Critical: Client is waiting for approval on the proposal"
   - "IMPORTANT: Security audit found vulnerabilities"

2. **Action Items**:
   - "Can you finish the quarterly report by Friday EOD?"
   - "Remember to send the contract to John before tomorrow's meeting"
   - "I need someone to review the pull request #234 before we deploy"

3. **Decisions**:
   - "After discussing with the team, we've decided to go with option B"
   - "Team agreed to postpone the launch to next Monday"
   - "We've decided to use PostgreSQL instead of MongoDB"

4. **Regular Conversation**:
   - Context messages to make conversation realistic
   - Mix of technical and project management discussion

### Deployment Status

**Cloud Functions:**
- ✅ `summarizeThread` - Deployed with ultra-concise prompt
- ✅ `populateTestMessages` - Deployed (DEBUG helper)
- ✅ Firestore security rules deployed

**iOS App:**
- ✅ Built and verified
- ✅ Flask button appears in DEBUG builds
- ✅ AI Analysis shows 4 sections with placeholder data
- ✅ Summary section shows real AI-generated content

### Next Steps

**To Complete Story 3.2:**
1. Update `summarizeThread` Cloud Function to return all 4 sections:
   - Add `priorityMessages: [{message, sender, priority}]`
   - Add `actionItems: [{task, assignee, deadline}]`
   - Add `decisions: [{decision, decisionMaker}]`
2. Update `ThreadSummary` entity to include new fields
3. Update `CloudFunctionsService` parsing to extract new fields
4. Update `SummaryView` to use real data instead of placeholders
5. Add AI prompts for priority detection, action extraction, decision tracking

**Current State**: UI is complete, only Summary section has real AI data. Other 3 sections show placeholder data demonstrating the design.

---

## Previous Session: Story 3.2 - Thread Summarization Feature (Oct 23, 2024)

### What Was Built

**Core Implementation (100% Complete):**
- ✅ `SummaryViewModel` - Full ViewModel with error handling, loading states, cache indicators
  - Marked `@MainActor` for Swift 6 concurrency safety
  - Formatted timestamp display ("Generated 5 minutes ago", "Generated 2 hours ago")
  - Handles all `AIServiceError` types with user-friendly messages
  - `loadSummary()`, `regenerateSummary()`, `clearSummary()` methods

- ✅ `SummaryView` - Polished modal UI with 3 states
  - Loading state: Progress indicator + "Analyzing conversation..." text
  - Error state: Friendly error message + "Try Again" button
  - Success state: Summary text, bulleted key points, participants, date range
  - "Regenerate" and "Close" buttons
  - Cache indicator when showing cached results
  - Full accessibility labels

- ✅ DIContainer Integration
  - Added `makeSummaryViewModel()` factory method
  - Properly wires `aiService` dependency

- ✅ Unit Tests - 12 tests, all passing ✅
  - Initial state verification
  - Successful summary loading
  - Cached result handling
  - Error handling (rate limit, service unavailable, timeout)
  - Regenerate functionality
  - Clear summary
  - Timestamp formatting (just now, minutes ago, hours ago)
  - Loading state transitions

**ChatView Integration (Blocked - See Issue Below):**
- ⚠️ AI button code written but commented out
- ⚠️ Confirmation dialog implemented but disabled
- ⚠️ Sheet presentation ready but inactive

### Critical Issue: ChatView Compiler Complexity

**Problem:**
- ChatView.swift (1361 lines) exceeds Swift compiler type-checking limits
- Adding AI button + sheet integration triggers: `error: the compiler is unable to type-check this expression in reasonable time`
- Build fails when AI integration is uncommented

**Temporary Solution:**
- All AI integration code commented out with clear markers:
  - Lines 20-24: AI state variables
  - Lines 148-161: AI toolbar button
  - Lines 188-205: Confirmation dialog + sheet
  - Lines 477-490: Helper property for sheet content

**Permanent Solution:**
- Refactor ChatView into smaller components (see `docs/stories/3.2-completion-plan.md`)
- Extract toolbar into `ChatToolbar.swift` component
- Extract toasts into separate component
- Estimated time: 30-45 minutes

### Files Created

```
✅ MessageAI/Presentation/ViewModels/SummaryViewModel.swift (153 lines)
✅ MessageAI/Presentation/Views/SummaryView.swift (318 lines)
✅ MessageAITests/Presentation/ViewModels/SummaryViewModelTests.swift (360 lines)
✅ docs/stories/3.2-completion-plan.md (comprehensive refactoring guide)
```

### Files Modified

```
✅ MessageAI/App/DIContainer.swift - Added makeSummaryViewModel() factory
⚠️ MessageAI/Presentation/Views/Chat/ChatView.swift - AI integration (commented out)
```

### Key Technical Decisions

**1. ViewModel Design Pattern**
- Decision: Create dedicated `SummaryViewModel` instead of extending `ChatViewModel`
- Rationale:
  - Follows Single Responsibility Principle
  - Easier to test in isolation
  - Can be reused from different access points (context menu, toolbar, etc.)
  - Avoids further bloating ChatViewModel

**2. Timestamp Formatting Strategy**
```swift
// User-friendly relative timestamps
< 1 min:  "Generated just now"
< 1 hour: "Generated 5 minutes ago"
< 24 hrs: "Generated 2 hours ago"
> 24 hrs: "Generated Oct 23, 8:30 AM"
```
- Rationale: Users understand recency better than absolute timestamps
- Implementation: Computed property in ViewModel, not View

**3. Error Handling Approach**
- Map all `AIServiceError` to user-friendly messages:
  - `.rateLimitExceeded` → "You've reached your daily limit of 100 AI requests"
  - `.serviceUnavailable` → "AI service is temporarily unavailable"
  - `.timeout` → "AI request took too long. Please try again with fewer messages"
- Never show raw error codes or technical details to users

**4. Loading State Management**
- Show loading immediately on tap (optimistic UI start)
- Display "Analyzing conversation..." text + spinner
- Mention "This may take up to 10 seconds" to set expectations
- Disable regenerate button while loading

**5. Cache Indication**
- Show green checkmark + "Cached result" label
- Helps users understand why some requests are instant
- Builds trust in the system

### Testing Strategy

**Unit Tests (12 tests - All Passing ✅):**
```bash
./scripts/quick-test.sh -q --test SummaryViewModelTests
```

**Test Coverage:**
- ✅ Loading state transitions
- ✅ Success scenarios (cached and fresh)
- ✅ Error scenarios (rate limit, timeout, service unavailable)
- ✅ Regenerate workflow
- ✅ Clear summary functionality
- ✅ Timestamp formatting edge cases

**Integration Tests:**
- ⚠️ Not yet implemented (requires Firebase Emulator)
- Template provided in completion plan
- Would test end-to-end: iOS app → Cloud Functions → Firestore cache

### Acceptance Criteria Status

| AC | Requirement | Status | Notes |
|----|-------------|--------|-------|
| 1 | AI button in chat toolbar | ⚠️ | Code ready, disabled due to ChatView complexity |
| 2 | Tap shows contextual menu | ⚠️ | Same as above |
| 3 | Loading modal | ✅ | Complete with progress indicator |
| 4 | Summary display | ✅ | Shows all required sections |
| 5 | Regenerate & Close buttons | ✅ | Fully functional |
| 6 | Summary persistence | ✅ | Shows timestamp and cached indicator |
| 7-10 | AI implementation | ✅ | Uses Story 3.1 infrastructure |
| 16-19 | Performance & caching | ✅ | Backend handles caching |
| 20 | Integration test | ⚠️ | Template created, needs emulator |
| 21 | Regression test | ✅ | All existing tests pass |

**Completion: ~85%** (Core feature complete, ChatView integration blocked by technical debt)

### Next Steps

**Immediate (To Complete Story 3.2):**
1. Follow `docs/stories/3.2-completion-plan.md`
2. Refactor ChatView toolbar (Phase 1 - 30-45 min)
3. Uncomment AI integration code
4. Manual testing on simulator
5. (Optional) Integration tests with Firebase Emulator

**Alternative (If Refactoring Delayed):**
- Add AI button to ConversationsListView context menu
- Allows Story 3.2 completion without ChatView changes
- Document as technical debt

### Patterns Established

**SwiftUI Modal Pattern:**
```swift
.sheet(isPresented: $showSummary) {
    if let vm = summaryViewModel {
        SummaryView(viewModel: vm)
            .onAppear {
                Task { await vm.loadSummary() }
            }
    }
}
```

**ViewModel State Pattern:**
```swift
@Published var summary: ThreadSummary?
@Published var isLoading = false
@Published var errorMessage: String?

// Computed properties for UI
var isCached: Bool { summary?.cached ?? false }
var generatedAtText: String { /* relative formatting */ }
```

**Mock Service Pattern for Testing:**
```swift
class MockAIService: AIServiceProtocol {
    var mockSummary: ThreadSummary?
    var shouldFail = false
    var summarizeThreadCallCount = 0

    func summarizeThread(...) async throws -> ThreadSummary {
        summarizeThreadCallCount += 1
        if shouldFail { throw errorToThrow }
        return mockSummary!
    }
}
```

### Known Issues

**Issue 1: ChatView Type-Checking Timeout**
- Severity: High (blocks full Story 3.2 completion)
- Impact: Cannot add AI button to ChatView toolbar
- Root Cause: ChatView.swift too large (1361 lines)
- Workaround: Code ready but commented out
- Fix: Refactor into smaller components (see completion plan)

**Issue 2: Integration Tests Skipped**
- Severity: Low
- Impact: No automated end-to-end testing yet
- Workaround: Manual testing on simulator
- Fix: Set up Firebase Emulator in CI/CD

### Dependencies

**New Imports:**
- `import Combine` in SummaryViewModel (for `@Published`)
- No new packages added (reuses Story 3.1 infrastructure)

### Code Locations

**iOS Presentation:**
- `MessageAI/Presentation/ViewModels/SummaryViewModel.swift`
- `MessageAI/Presentation/Views/SummaryView.swift`

**iOS Tests:**
- `MessageAITests/Presentation/ViewModels/SummaryViewModelTests.swift`

**Documentation:**
- `docs/stories/3.2-completion-plan.md` - Refactoring guide

### Quick Reference

**Manual Testing:**
```bash
# Build and run
./scripts/build.sh

# Run tests
./scripts/quick-test.sh -q --test SummaryViewModelTests

# Once ChatView refactored:
# 1. Open app on simulator
# 2. Sign in and open conversation
# 3. Tap ✨ sparkles button
# 4. Tap "Summarize Thread"
# 5. Verify modal appears with loading state
```

**Completion Checklist:**
- [x] SummaryViewModel implemented
- [x] SummaryView implemented
- [x] DIContainer factory added
- [x] Unit tests written (12 tests)
- [x] All tests passing
- [x] Build succeeds
- [x] Completion plan documented
- [ ] ChatView refactored (blocked)
- [ ] AI button integrated
- [ ] Manual testing complete
- [ ] Integration tests complete

---

## Previous Session: Story 3.1 - Cloud Functions Infrastructure (Oct 23, 2024)

### What Was Built

**Backend Infrastructure:**
- ✅ Three Cloud Functions deployed to `messageai-dev-1f2ec`
  - `summarizeThread` - AI thread summarization with placeholder responses
  - `extractActionItems` - Action item extraction with placeholder responses
  - `generateSmartSearchResults` - Semantic search with placeholder responses
- ✅ Security layer (Firebase Auth + participant validation)
- ✅ Caching system (Firestore `ai_cache` collection, 24-hour TTL)
- ✅ Utility modules (`utils/security.ts`, `utils/cache.ts`)

**iOS Integration:**
- ✅ Domain entities: `ThreadSummary`, `AIActionItem`, `AISearchResult`
- ✅ `AIServiceProtocol` - Clean architecture protocol (Domain layer)
- ✅ `CloudFunctionsService` - Low-level Firebase Functions wrapper (Data/Network)
- ✅ `FirebaseAIService` - High-level implementation of `AIServiceProtocol` (Data/Services)
- ✅ DIContainer updated to inject `aiService` into ChatViewModel
- ✅ Integration tests created (`CloudFunctionsIntegrationTests`)

**Infrastructure:**
- ✅ Firestore security rules for `ai_cache` (read-only for clients)
- ✅ Firestore composite index deployed (`conversationId + featureType + expiresAt`)
- ✅ Environment variable setup (`.runtimeconfig.json` for local dev)
- ✅ Documentation (`functions/README.md`, `AI-INFRASTRUCTURE-TESTING.md`)

### Key Technical Decisions

**1. Placeholder Responses for Story 3.1**
- Decision: Use placeholder AI responses in Cloud Functions
- Rationale: Allows testing infrastructure end-to-end without OpenAI API key
- Future: Story 3.5 will replace with real OpenAI GPT-4 integration

**2. Two-Layer iOS Architecture**
```
ViewModels → FirebaseAIService → CloudFunctionsService → Cloud Functions
           (business logic)      (network calls)
```
- `CloudFunctionsService`: Low-level HTTP calls, error mapping
- `FirebaseAIService`: High-level interface, domain entity mapping
- Benefit: Clean separation, easy to test, follows existing patterns

**3. Cache Key Strategy**
- Format: `${featureType}_${conversationId}_${latestMessageId}`
- Invalidation: New message = new latestMessageId = new cache key
- TTL: 24 hours for summaries/action items, 5 minutes for search

**4. Security Model**
- All functions require Firebase Auth token
- Participant validation on every request
- Users can only access conversations they're in
- Cache is read-only for clients (only Cloud Functions write)

**5. Debug UI Limitation**
- Issue: ChatView hit Swift compiler type-checking limit (~1400 lines)
- Workaround: Test via Firebase Console or dedicated test screen
- Future: Debug button will be added in Story 3.2 with dedicated AI UI

### Deployment Status

**Cloud Functions Live:**
- Project: `messageai-dev-1f2ec`
- Region: `us-central1`
- Functions: 5 total (3 new AI functions + 2 existing)
- Status: All deployed and functional

**Firestore:**
- Rules deployed: ✅
- Indexes deployed: ✅
- `ai_cache` collection ready: ✅

### Testing Approach

**For Story 3.1:**
- Firebase Console testing (immediate)
- Integration tests (requires emulator setup)
- Placeholder responses validate infrastructure

**For Story 3.5 (Real AI):**
- Same infrastructure, just replace placeholder logic
- Add rate limiting (100 requests/day per user)
- Add cost tracking with Firebase Analytics

### Code Locations

**Cloud Functions:**
- `functions/src/summarizeThread.ts`
- `functions/src/extractActionItems.ts`
- `functions/src/generateSmartSearchResults.ts`
- `functions/src/utils/security.ts`
- `functions/src/utils/cache.ts`

**iOS Domain:**
- `MessageAI/Domain/Repositories/AIServiceProtocol.swift`
- `MessageAI/Domain/Entities/ThreadSummary.swift`
- `MessageAI/Domain/Entities/AIActionItem.swift`
- `MessageAI/Domain/Entities/AISearchResult.swift`

**iOS Data:**
- `MessageAI/Data/Network/CloudFunctionsService.swift`
- `MessageAI/Data/Services/FirebaseAIService.swift`

**iOS Tests:**
- `MessageAITests/Integration/CloudFunctionsIntegrationTests.swift`

### Patterns Established

**1. Cloud Function Pattern:**
```typescript
export const functionName = functions
  .runWith({ timeoutSeconds: 60, memory: '512MB' })
  .https.onCall(async (data, context) => {
    // 1. Auth check
    // 2. Input validation
    // 3. Security (participant verification)
    // 4. Cache lookup
    // 5. Fetch data
    // 6. AI processing (placeholder in 3.1, real in 3.5)
    // 7. Store in cache
    // 8. Return structured response
  });
```

**2. iOS Service Pattern:**
```swift
// Domain Protocol
protocol AIServiceProtocol {
    func summarizeThread(...) async throws -> ThreadSummary
}

// Data Implementation
class FirebaseAIService: AIServiceProtocol {
    private let cloudFunctionsService: CloudFunctionsService

    func summarizeThread(...) async throws -> ThreadSummary {
        let response = try await cloudFunctionsService.call...()
        return ThreadSummary(...) // Map DTO to domain entity
    }
}
```

**3. Error Handling:**
- Cloud Functions: Throw `HttpsError` with user-friendly codes
- iOS: Map to `AIServiceError` enum with descriptive messages
- User sees: "AI service temporarily unavailable" not raw errors

### Dependencies Added

**Firebase:**
- ✅ `FirebaseFunctions` package added to iOS project

**Cloud Functions:**
- Already had: `firebase-functions`, `firebase-admin`
- No new packages needed for Story 3.1

### Known Issues & Future Work

**Issue 1: ChatView Complexity**
- Symptom: Swift compiler "unable to type-check expression in reasonable time"
- Cause: ~1400 lines with many chained modifiers
- Temporary Fix: Debug UI commented out
- Permanent Fix: Refactor ChatView into smaller components (future story)

**Issue 2: Integration Tests Skipped**
- Tests exist but skip by default (requires emulator)
- To run: Start emulator + change `XCTSkipIf(true, ...)` to `false`
- Future: Add to CI/CD pipeline

### Next Stories

**Story 3.2: Thread Summarization UI**
- Build dedicated AI summary screen
- Add "Summarize" button to chat toolbar
- Display summary with key points and participants
- Use infrastructure built in 3.1

**Story 3.5: Real AI Integration**
- Obtain OpenAI API key
- Replace placeholder responses with GPT-4 Turbo
- Implement rate limiting (100 req/day per user)
- Add cost tracking with Firebase Analytics
- User-friendly error messages
- Graceful fallback when AI unavailable

### Quick Reference

**Test Cloud Functions:**
```bash
# Via Firebase Console
https://console.firebase.google.com/project/messageai-dev-1f2ec/functions

# Via iOS (when UI ready)
let summary = try await aiService.summarizeThread(conversationId: id, messageIds: nil)
```

**Deploy Updates:**
```bash
# Functions only
firebase deploy --only functions --project=messageai-dev-1f2ec

# Rules + indexes
firebase deploy --only firestore:rules,firestore:indexes --project=messageai-dev-1f2ec
```

**View Logs:**
```bash
firebase functions:log --project=messageai-dev-1f2ec
firebase functions:log --only summarizeThread --project=messageai-dev-1f2ec
```

---

## Previous Sessions

_Will be populated as more stories are completed_

---

## Architecture Reminders

**Clean Architecture Layers:**
```
Presentation (ViewModels, Views)
    ↓ depends on
Domain (Entities, Protocols) ← Pure Swift, no external dependencies
    ↑ implemented by
Data (Repositories, Services, Network)
```

**Dependency Injection:**
- All dependencies flow through `DIContainer`
- ViewModels receive dependencies via initializer
- Protocols defined in Domain, implementations in Data
- Makes testing easy (mock protocols)

**Firebase Best Practices:**
- Always use `FieldValue.serverTimestamp()` (never client Date)
- Use batch writes for multi-document operations
- Always set query limits
- Security rules must match Swift logic
- Cache expensive queries (like AI results)

---

Last Updated: October 23, 2024
