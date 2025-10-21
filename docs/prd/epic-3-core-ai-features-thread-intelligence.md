# Epic 3: Core AI Features - Thread Intelligence

## Epic 3 Goal

Integrate the first three AI-powered features for remote team professionals: thread summarization, action item extraction, and smart search. These features are accessible contextually within conversations through buttons and modals, with minimal UI complexity. Cloud Functions are implemented to securely call AI services (OpenAI or Anthropic), protecting API keys from client exposure. AI quality acceptance criteria defined upfront to validate "good enough" performance. Expected timeline: 1.5 days.

## Story 3.0: Organization/Workspace System

As a **user**,  
I want **to belong to an organization/workspace where I can message other members**,  
so that **I only see relevant contacts and can participate in team-based messaging at scale**.

### Acceptance Criteria

1. `Organization` entity created with: id, name, memberIds, createdAt, settings
2. User entity updated with `organizationIds: [String]` field (users can belong to multiple orgs)
3. Update `getAllUsers()` → `getUsersInOrganization(organizationId: String)` in UserRepository
4. Update `getOrCreateConversation()` to validate participants in same organization
5. Organization selection UI for users in multiple organizations (simple dropdown/picker)
6. Default organization auto-created for existing users (migration script)
7. Admin users can invite new users to organization (email invitation)
8. Organization settings: name, member management, permissions
9. Firestore security rules updated: Users can only query users in their organization(s)
10. Performance: User queries scoped to organization (< 100ms for 1000+ member orgs)
11. Conversation list filtered to conversations within current organization
12. Unit tests for organization-based user filtering
13. Integration test: User A in Org 1 cannot message User B in Org 2
14. Migration: Existing users assigned to "Default Organization"
15. Error handling: User without organization shown onboarding flow

**Note:** This story addresses the scalability limitation documented in Story 2.0 where `getAllUsers()` doesn't scale beyond small teams. Organizations enable multi-tenant usage and proper contact scoping.

## Story 3.1: Cloud Functions Infrastructure for AI Services

As a **developer**,  
I want **Firebase Cloud Functions that securely call AI services**,  
so that **API keys are never exposed in the client app and AI features can be triggered server-side**.

### Acceptance Criteria

1. Cloud Functions project initialized in Firebase
2. Node.js Cloud Function created: `summarizeThread` accepting conversationId and messageIds
3. Node.js Cloud Function created: `extractActionItems` accepting conversationId and messageIds
4. Node.js Cloud Function created: `generateSmartSearchResults` accepting query and conversationIds
5. Cloud Functions authenticate requests (verify Firebase Auth token)
6. API keys for OpenAI or Anthropic stored in Firebase environment variables (not in code)
7. URLSession wrapper in iOS app to call Cloud Functions with proper authentication
8. Error handling in Cloud Functions: Rate limits, API failures, timeouts
9. Cloud Functions return structured JSON responses with AI results
10. Performance: Cloud Functions respond within 10 seconds or return timeout error
11. Cost optimization: Implement caching layer for repeated requests (same messages = cached summary)
12. Unit tests for Cloud Functions logic (mocked AI API calls)
13. Deployment: Cloud Functions deployed to Firebase dev environment
14. Integration test: iOS app calls Cloud Function, receives valid response
15. Security: Cloud Functions validate user has access to requested conversation data

## Story 3.2: Thread Summarization Feature

As a **user**,  
I want **to see an AI-generated summary of long conversation threads**,  
so that **I can quickly catch up on discussions without reading every message**.

### Acceptance Criteria

**UI & Interaction:**
1. AI button added to chat view toolbar (lightning bolt or sparkle icon)
2. Tap AI button opens contextual menu showing "Summarize Thread" option
3. Tap "Summarize Thread" shows loading modal: "Analyzing conversation..."
4. Summary displayed in modal with: key points (bullets), main decisions, participants mentioned
5. Modal includes "Regenerate" and "Close" buttons
6. Summary persists: Tap AI button again shows last summary with timestamp "Generated 5 minutes ago"

**AI Implementation:**
7. ViewModel calls Cloud Function `summarizeThread` with last 100 messages (or all if fewer)
8. LLM prompt optimized for remote team context: "Summarize this team conversation, highlighting decisions, action items, and key points"
9. Summary length: 150-300 words maximum
10. Summary includes conversation participants and date range

**Quality Acceptance Criteria (Define "Good Enough"):**
11. Summary includes all explicitly stated decisions (e.g., "We decided to use Firebase")
12. Summary mentions any questions directly asked to current user
13. Summary doesn't hallucinate facts not in conversation
14. Summary readable and professional (no grammatical errors)
15. Manual validation: Test with 5 sample conversations, verify quality acceptable

**Performance & Caching:**
16. First summary generation: < 10 seconds
17. Cached summary: < 1 second load time
18. Summaries cached in Firestore collection `ai_summaries` with conversationId + messageRange key
19. Cache invalidated when new messages added (or regenerated on demand)

**Testing:**
20. Unit tests for summary ViewModel logic
21. Integration test: Generate summary, verify it contains key message content
22. Regression test: Chat functionality still works with AI button added

## Story 3.3: Action Item Extraction Feature

As a **user**,  
I want **AI to automatically extract action items from conversations**,  
so that **I don't miss tasks assigned to me or my team**.

### Acceptance Criteria

**UI & Interaction:**
1. AI button contextual menu includes "Extract Action Items" option
2. Tap "Extract Action Items" shows loading modal: "Finding action items..."
3. Action items displayed in modal with structured list:
   - Task description
   - Assigned to (person mentioned or "Unassigned")
   - Context (link to source message)
4. Each action item has checkbox to "Add to Insights Dashboard"
5. "View All Action Items" button navigates to Insights tab

**AI Implementation:**
6. ViewModel calls Cloud Function `extractActionItems` with conversation messages
7. LLM prompt: "Extract action items from this conversation. For each, identify: what needs to be done, who should do it, and any mentioned deadlines"
8. Function returns array of { task, assignee, deadline, sourceMessageId }
9. Action items stored in Firestore `action_items` collection when user saves them

**Quality Acceptance Criteria (Define "Good Enough"):**
10. Detects explicit action items: "Can you send me the report?" → Task: "Send report", Assigned to: [detected name]
11. Detects implicit commitments: "I'll handle the deployment" → Task: "Handle deployment", Assigned to: [speaker]
12. Doesn't extract questions that aren't requests ("What time is it?" ≠ action item)
13. Correctly identifies assignee from context (name mentions, "you", "I")
14. Manual validation: Test with 5 conversations containing known action items, verify 80%+ detection rate

**Performance & Caching:**
15. Action item extraction: < 8 seconds
16. Cached results load < 1 second
17. Cache key: conversationId + messageRange

**Testing:**
18. Unit tests for action item ViewModel
19. Integration test: Extract action items from test conversation with known tasks
20. Regression test: Summary feature still works after action item implementation

## Story 3.4: Smart Search Feature

As a **user**,  
I want **to search my messages using natural language**,  
so that **I can find information without remembering exact keywords**.

### Acceptance Criteria

**UI & Interaction:**
1. Search icon in conversations list navigation bar
2. Tap search opens search view with text input: "Search all conversations..."
3. Search suggestions below input: "Find decisions about...", "Messages from...", "Action items containing..."
4. User types query, AI-enhanced results appear below
5. Results show: message snippet, conversation name, timestamp, relevance score
6. Tap result navigates to conversation, scrolls to message

**AI Implementation (Hybrid Approach):**
7. Query preprocessed: Expand natural language to keywords (e.g., "when did we decide on Firebase" → keywords: "decide, decided, Firebase")
8. If query is simple keyword: Use Firestore text search (fast)
9. If query is complex/natural language: Call Cloud Function `generateSmartSearchResults` for semantic search
10. Cloud Function queries Firestore for relevant conversations, passes to LLM with query
11. LLM ranks messages by relevance and returns top 10 results

**Performance Considerations:**
12. Keyword search: < 1 second (Firestore only)
13. AI-enhanced search: < 5 seconds (Cloud Function + LLM)
14. Search results paginated (show 10, load more on scroll)
15. Recent searches cached locally for instant repeat queries

**Quality Acceptance Criteria (Define "Good Enough"):**
16. Natural language queries work: "What did Sarah say about the deadline?" returns messages from Sarah mentioning deadlines
17. Synonym handling: "meeting" also finds "call", "sync", "standup"
18. Contextual understanding: "our decision" finds messages with decision keywords near team member names
19. Manual validation: 10 test queries, verify top 3 results are relevant

**Edge Cases:**
20. No results state: "No messages found. Try different keywords."
21. Offline search: Falls back to local keyword search only (no AI)
22. Error handling: If Cloud Function fails, show basic Firestore results

**Testing:**
23. Unit tests for search ViewModel and query preprocessing
24. Integration test: Search for specific message, verify it appears in results
25. Performance test: Search across 1000+ messages completes within time limits
26. Regression test: Conversations list and chat still perform well with search added

## Story 3.5: AI Service Selection & Configuration

As a **developer**,  
I want **to finalize AI service selection (OpenAI vs Anthropic) and configure API access**,  
so that **all AI features use a consistent, reliable AI provider**.

### Acceptance Criteria

1. Decision made: OpenAI GPT-4 OR Anthropic Claude (based on API access availability)
2. API key obtained and stored in iOS Keychain (for direct testing) and Firebase env vars (for Cloud Functions)
3. Cloud Functions updated to use selected AI provider
4. Rate limiting implemented: Max 100 AI requests per user per day (configurable)
5. Cost tracking: Log AI requests to Firebase Analytics for cost monitoring
6. Error messages user-friendly: "AI service temporarily unavailable" instead of raw API errors
7. Fallback strategy: If AI service down, features gracefully disabled (not crash)
8. KeychainService wrapper created for secure API key storage in iOS
9. Documentation: README updated with AI provider details and setup instructions
10. Testing: All AI features tested with final provider, verify quality acceptable

## Story 3.6: AI Results Caching & Cost Optimization

As a **developer**,  
I want **aggressive caching of AI results**,  
so that **repeated requests don't incur unnecessary costs and users get instant responses**.

### Acceptance Criteria

1. Firestore collection `ai_cache` created with schema: { cacheKey, result, timestamp, expiresAt }
2. Cache key generation: Hash of (conversationId + messageIds + featureType)
3. Cloud Functions check cache before calling AI API
4. Cache hit: Return cached result (< 1 second response time)
5. Cache miss: Call AI API, store result in cache with 24-hour expiration
6. Cache invalidation: When new messages added, related caches marked stale
7. Stale cache UX: Show cached result with "Outdated (from 2 hours ago). [Regenerate]" option
8. Client-side caching: iOS app caches AI results locally for offline viewing
9. Cost monitoring: Dashboard in Firebase Console showing AI API usage and estimated costs
10. Performance: Cache lookups add < 100ms overhead
11. Testing: Verify cache hit/miss logic, measure cost savings (estimated 70% cache hit rate)

## Story 3.7: AI Feature Integration Testing & Quality Validation

As a **QA engineer**,  
I want **comprehensive testing of all AI features with real conversations**,  
so that **we validate quality meets acceptance criteria before moving to next epic**.

### Acceptance Criteria

1. **Test Data Created:**
   - 10 sample conversations representing remote team scenarios (product decisions, bug discussions, planning, social chat)
   - Conversations vary in length: 10 messages, 50 messages, 100+ messages
   - Include edge cases: Very short threads, emoji-heavy, code snippets

2. **Quality Validation Matrix:**
   - Thread Summarization: 8/10 summaries capture all key decisions
   - Action Item Extraction: 7/10 conversations have 80%+ action item detection
   - Smart Search: 9/10 test queries return relevant results in top 3

3. **Performance Benchmarks Met:**
   - Summarization: Average 6 seconds (< 10 second requirement)
   - Action Items: Average 5 seconds (< 8 second requirement)
   - Smart Search: Average 3 seconds (< 5 second requirement)

4. **User Acceptance Testing:**
   - 2 external beta testers use AI features with real conversations
   - Feedback collected: Quality acceptable? Any hallucinations? Useful results?
   - At least 1 tester rates features "useful" or better

5. **Error Handling Validated:**
   - AI service unavailable: Features gracefully disabled, error message shown
   - Timeout: Loading modal shows "Taking longer than expected..." after 8 seconds
   - Invalid input: Empty conversations handled without crashes

6. **Regression Testing:**
   - All Epic 1 & Epic 2 features still work correctly
   - App performance not degraded (message send still < 2 seconds)
   - Memory usage acceptable with AI features active

7. **Documentation Updated:**
   - AI feature usage documented in README
   - Known limitations documented (e.g., "Works best with English conversations")
   - Cost estimates documented (e.g., "~$0.05 per summary")

---
