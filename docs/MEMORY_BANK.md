# MessageAI Development Memory Bank

This file tracks key decisions, implementation patterns, and learnings across development sessions.

## Latest Session: Story 3.1 - Cloud Functions Infrastructure (Oct 23, 2024)

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
