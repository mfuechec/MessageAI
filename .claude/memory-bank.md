# MessageAI Development Memory Bank

## Latest Session: 2025-10-24 - Epic 6 Bug Fixes & AI Analysis Debugging

### Critical Bug Fixes

**AI Notification Analysis Not Working** - ROOT CAUSE IDENTIFIED & FIXED ✅

The AI was falling back to simple heuristics instead of using GPT-4 analysis due to **multiple Firestore query errors**:

### Bugs Fixed (6 Total)

**1. Profile Image Bug** ✅
- **Issue:** Alice's conversation with Bob showed Alice's own profile image
- **Cause:** `getParticipants()` returned ALL participants including current user
- **Fix:** Filter out current user for one-on-one conversations
- **File:** `ConversationsListViewModel.swift:280-290`

**2. Typing Indicator Layout Bug** ✅
- **Issue:** Typing indicator pushed MessageKit up, creating white space
- **Cause:** VStack layout with typing indicator below MessageKit
- **Fix:** Changed to ZStack with typing indicator overlaid
- **File:** `ChatView.swift:44-74`

**3. Offline Banner Auto-Opening Bug** ✅
- **Issue:** Offline banner appeared even when online at app launch
- **Cause:** Initial cached Firestore snapshots flagged as offline
- **Fix:** Added 3-second grace period for startup
- **File:** `NetworkMonitor.swift:208-260`

**4. NetworkMonitor Permission Error** ✅
- **Issue:** `_connection_test` collection caused Firestore permission errors
- **Cause:** Collection doesn't exist and isn't in security rules
- **Fix:** Changed to listen to `users/{userId}` document
- **File:** `NetworkMonitor.swift`

**5. Duplicate Conversation IDs** ✅
- **Issue:** SwiftUI warning about duplicate IDs in ForEach
- **Cause:** Multiple sources setting conversations array without deduplication
- **Fix:** Created centralized `setConversations()` method
- **File:** `ConversationsListViewModel.swift:178-223`

**6. Smart Notification Suppression Bug** ✅
- **Issue:** System thought user was viewing conversation when on list
- **Cause:** `currentlyViewingConversationId` not cleared when dismissing ChatView
- **Fix:** Added `.onAppear` on list and `.onDisappear` on ChatView
- **File:** `ConversationsListView.swift:363-387`

### CRITICAL: AI Analysis Firestore Query Errors (3 Queries Fixed)

**Query Error 1: Conversations Query** ✅
- **Location:** `functions/src/helpers/user-context.ts:55-58`
- **Error:** `array-contains` with inequality on different field
- **Query:**
  ```typescript
  ❌ .where("participantIds", "array-contains", userId)
     .where("lastMessageTimestamp", ">", sevenDaysAgo)
  ```
- **Fix:** Remove timestamp filter, filter in code
  ```typescript
  ✅ .where("participantIds", "array-contains", userId)
     .get()
  // Then filter by timestamp in code
  ```

**Query Error 2: Messages Query** ✅
- **Location:** `functions/src/helpers/user-context.ts:86-92`
- **Error:** `in` operator with inequality on different field
- **Query:**
  ```typescript
  ❌ .where("conversationId", "in", batch)
     .where("timestamp", ">", sevenDaysAgo)
  ```
- **Fix:** Remove timestamp filter, filter in code with limit
  ```typescript
  ✅ .where("conversationId", "in", batch)
     .orderBy("timestamp", "desc")
     .limit(200)
     .get()
  // Then filter by timestamp in code
  ```

**Query Error 3: Embeddings Query** ✅
- **Location:** `functions/src/helpers/indexConversationForRAG.ts:41-44`
- **Error:** `in` on documentId with inequality on timestamp
- **Query:**
  ```typescript
  ❌ .where(admin.firestore.FieldPath.documentId(), "in", messageIds)
     .where("timestamp", ">", sevenDaysAgo)
  ```
- **Fix:** Remove timestamp filter, filter in code
  ```typescript
  ✅ .where(admin.firestore.FieldPath.documentId(), "in", messageIds)
     .get()
  // Then filter by timestamp in code
  ```

**Query Error 4: Undefined Firestore Value** ✅
- **Location:** `functions/src/helpers/user-context.ts:155`
- **Error:** `groupName` was `undefined` for non-group conversations
- **Firestore Error:** "Cannot use 'undefined' as a Firestore value"
- **Fix:** Changed to `null` instead of `undefined`
  ```typescript
  ✅ groupName: convData.groupName || null
  ```

### Feature Removal: Quiet Hours

**Removed Quiet Hours Feature** ✅
- **Reason:** User indicated it's not needed
- **iOS Changes:**
  - Removed entire "Quiet Hours" section from settings UI
  - Removed DatePicker controls
  - Removed helper functions `timeStringToDate()` and `dateToTimeString()`
  - **File:** `SmartNotificationSettingsView.swift`
- **Cloud Function Changes:**
  - Removed `isInQuietHours()` check from notification flow
  - Removed import of `isInQuietHours` function
  - **File:** `analyzeForNotification.ts:14, 165-174`

### Notification Text Bug Fix

**Wrong Message Text in Notification** ✅
- **Issue:** When multiple messages unread, showed oldest message text instead of newest
- **Root Cause:** Fallback heuristic checked ALL unread messages, returned first match (oldest)
- **User Insight:** "I think the problem might be simply that it's hardcoded to display the first unread message"
- **Fix:** Only analyze the NEWEST message in fallback logic
  ```typescript
  // Only check first message in array (ordered DESC = newest first)
  const newestMessage = messages[0];
  ```
- **File:** `functions/src/helpers/fallback-notification-logic.ts:34-124`

### How AI Notification Analysis Works (Now Fixed!)

**The AI Flow (Working):**
1. **Fetch Messages:** Gets ALL unread messages from last 15 minutes (up to 30)
2. **Load User Context:** RAG system retrieves:
   - User's last 100 messages (past 7 days)
   - All active conversations
   - Notification preferences
   - Learned keywords/suppressed topics
3. **Semantic Search:** Finds similar past messages using embeddings
4. **GPT-4 Analysis:** LLM analyzes ALL unread messages with full context
5. **Decision:** Returns notification decision with reasoning

**The Prompt Instructs AI To:**
- Consider ALL unread messages collectively
- Look for patterns across conversation
- Understand context from user's recent activity
- Adapt based on learned preferences
- Generate notification text from most relevant message

**Why It Wasn't Working:**
- ❌ `getUserRecentContext()` was failing (query errors)
- ❌ Without user context, AI couldn't analyze
- ❌ Fell back to simple pattern matching

**Now Fixed:**
- ✅ All 3 Firestore query errors resolved
- ✅ `undefined` groupName issue fixed
- ✅ User context loads successfully
- ✅ AI analysis runs with full context

### Files Modified (7 Files)

**iOS App:**
1. `MessageAI/Presentation/ViewModels/Conversations/ConversationsListViewModel.swift`
   - Fixed `getParticipants()` to filter current user
   - Added centralized `setConversations()` with deduplication
   - Fixed state tracking for notification suppression

2. `MessageAI/Presentation/Views/Chat/ChatView.swift`
   - Changed typing indicator to ZStack overlay

3. `MessageAI/Presentation/Utils/NetworkMonitor.swift`
   - Added 3-second grace period for startup
   - Changed to listen to `users/{userId}` document

4. `MessageAI/Presentation/Views/Conversations/ConversationsListView.swift`
   - Added `.onAppear` and `.onDisappear` for state clearing
   - Fixed conversation viewing state tracking

5. `MessageAI/Presentation/Views/Settings/SmartNotificationSettingsView.swift`
   - Removed entire "Quiet Hours" section

**Cloud Functions:**
6. `functions/src/helpers/user-context.ts`
   - Fixed conversations query (removed timestamp inequality)
   - Fixed messages query (removed timestamp inequality)
   - Fixed `groupName` undefined → null

7. `functions/src/helpers/indexConversationForRAG.ts`
   - Fixed embeddings query (removed timestamp inequality)

8. `functions/src/helpers/fallback-notification-logic.ts`
   - Refactored to only check newest message
   - Inlined all pattern checks (removed helper functions)
   - Added debug logging

9. `functions/src/analyzeForNotification.ts`
   - Removed `isInQuietHours` check and import

### Firestore Query Constraint Rules (For Future Reference)

**What Doesn't Work:**
1. ❌ `array-contains` + inequality on different field
2. ❌ `in` operator + inequality on different field
3. ❌ `in` on documentId + inequality on different field
4. ❌ `undefined` values in documents (use `null` instead)

**Solution Pattern:**
- Query without the inequality filter
- Add `.limit()` to prevent fetching too much data
- Filter by timestamp in code after fetching

### Deployment Status

**Cloud Functions:** ✅ Deployed
```bash
firebase deploy --only functions:analyzeForNotification --project messageai-dev-1f2ec
```

**iOS App:** ✅ Built successfully
```bash
./scripts/build.sh
# 12 warnings (non-critical deprecations)
```

### Testing Results

**Before Fixes:**
```
❌ Firestore query errors in logs
❌ userContext is null
❌ Falling back to heuristics
❌ Wrong message text displayed
```

**After Fixes:**
```
✅ No Firestore query errors
✅ User context loads successfully
✅ AI analysis runs with GPT-4
✅ Correct message text displayed
```

### Cost Implications

**Query Optimization Benefits:**
- Reduced unnecessary timestamp filtering at database level
- Filtering in code is free vs Firestore index usage
- `.limit(200)` prevents unbounded queries
- Overall: Negligible cost impact, improved reliability

### Git Commit Message

```bash
git add MessageAI/ functions/src/
git commit -m "fix: Epic 6 - Critical AI Analysis Bug Fixes

CRITICAL: Fixed AI notification analysis falling back to heuristics
- Root cause: 3 Firestore query structure errors blocking user context
- Fixed array-contains + inequality query (conversations)
- Fixed in + inequality query (messages, embeddings)
- Fixed undefined groupName causing Firestore write errors

Bug Fixes:
- Profile image showing wrong participant (1-on-1 conversations)
- Typing indicator creating white space under message box
- Offline banner auto-opening at app launch (3s grace period)
- NetworkMonitor permission errors (_connection_test → users/{id})
- Duplicate conversation IDs in SwiftUI ForEach
- Notification suppression state not clearing on view dismiss
- Wrong message text in notifications (oldest instead of newest)

Feature Removal:
- Removed quiet hours feature (not needed per user feedback)
- Removed from settings UI and Cloud Function logic

AI Analysis Now Working:
- User context loads successfully with full RAG system
- GPT-4 analyzes ALL unread messages with conversation history
- Semantic search provides relevant past message context
- Learned user preferences integrated into LLM prompt

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Previous Session: 2025-10-23 - Stories 6.5 & 6.6 Implementation

### Stories Completed

**Story 6.5: Feedback Loop, Analytics & Continuous Improvement** ✅
- Notification feedback UI with retroactive feedback buttons
- User profile learning from feedback history (high/medium/low preference)
- LLM prompt integration with learned user preferences
- Notification history view with AI reasoning display

**Story 6.6: Push Notification Delivery & Deep Linking** ✅
- Interactive notification actions (Reply, Mark Read, Feedback)
- FCM notification delivery with priority-based presentation
- Deep linking to specific messages with highlighting
- Active conversation suppression (server-side backup)
- Rate limiting enforcement in Cloud Function

### Files Created (6 New Files)

**iOS Domain Layer:**
1. `MessageAI/Domain/Repositories/NotificationHistoryRepositoryProtocol.swift`
   - `NotificationHistoryEntry` struct with decision metadata
   - `getRecentDecisions()` - Fetch last 20 notification decisions
   - `submitFeedback()` - Submit helpful/not helpful feedback

**iOS Data Layer:**
2. `MessageAI/Data/Repositories/FirebaseNotificationHistoryRepository.swift`
   - Fetches decisions from `notification_decisions` collection
   - Enriches with conversation names (group/1-on-1)
   - Calls `submitNotificationFeedback` Cloud Function

**iOS Presentation Layer:**
3. `MessageAI/Presentation/ViewModels/NotificationHistoryViewModel.swift`
   - `@MainActor` ViewModel with feedback state management
   - Loads last 20 decisions on view appear
   - Updates local state after feedback submission

4. `MessageAI/Presentation/Views/Settings/NotificationHistoryView.swift`
   - SwiftUI view with expandable AI reasoning disclosure groups
   - Priority badges (high=red, medium=orange, low=blue)
   - Retroactive feedback buttons (thumbs up/down)
   - Empty state for no history

**iOS Services:**
5. `MessageAI/Presentation/Services/DeepLinkHandler.swift`
   - Singleton handler for notification deep links
   - Observes NotificationCenter "OpenConversation" events
   - Publishes `activeDeepLink` for navigation

6. `MessageAI/Presentation/Modifiers/MessageHighlightModifier.swift`
   - SwiftUI modifier for message highlighting animation
   - Yellow flash animation (0.3s fade in, 1s hold, 0.5s fade out)
   - Applied via `highlightedMessageId` in ChatViewModel

---

## Project Context

**Current Epic:** Epic 6 - Smart AI-Powered Notifications
**Stories Completed:** 6.1, 6.2, 6.3, 6.4, 6.5, 6.6 ✅
**Epic Status:** COMPLETE ✅

**Next Epic:** Epic 7 - Advanced Messaging Features (or Testing/Polish)

**Architecture:** Clean Architecture + MVVM
**Backend:** Firebase (Firestore, Auth, Cloud Functions, FCM)
**AI:** OpenAI GPT-4 Turbo, text-embedding-ada-002
**Language:** Swift 5.9+ (iOS), TypeScript (Cloud Functions)

**Test Coverage Target:** 70%+ (unit tests pending)

**Build Status:**
- iOS: ✅ BUILD SUCCEEDED (12 non-critical warnings)
- Cloud Functions: ✅ TypeScript compilation successful
- AI Analysis: ✅ WORKING (all Firestore query errors resolved)
