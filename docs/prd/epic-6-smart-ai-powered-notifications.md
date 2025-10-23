# Epic 6: Smart AI-Powered Notifications

## Epic 6 Goal

Replace traditional "notify on every message" behavior with intelligent, context-aware AI-driven notifications. The system monitors conversation activity and triggers AI analysis during natural conversation pauses or after sustained activity. The AI analyzes full conversation context via RAG (Retrieval-Augmented Generation) to determine notification worthiness, dramatically reducing notification fatigue while ensuring users never miss truly important messages. Users must explicitly opt-in, can provide feedback to improve accuracy, and maintain full control over notification preferences. Expected timeline: 2-3 days.

## Value Proposition

**Problem:** Remote team professionals drown in notifications. Every message triggers an alert, causing users to:
- Mute all notifications (miss important messages)
- Experience constant interruption (productivity loss)
- Develop notification blindness (ignore critical updates)

**Solution:** AI acts as intelligent notification filter:
- Analyzes conversation context, not just individual messages
- Considers user's full message history and preferences
- Only notifies when truly important (mentions, urgent requests, decisions affecting user)
- Provides clear, actionable notification text summarizing why it's important

**Differentiation:** No messaging app currently uses AI at the conversation-level to filter notifications intelligently.

## Story 6.1: Conversation Activity Monitoring & Trigger Logic

As a **developer**,
I want **the app to monitor conversation activity and trigger AI analysis at appropriate times**,
so that **notifications are analyzed after conversations pause, not for every single message**.

### Acceptance Criteria

**Client-Side Activity Tracker:**
1. `ConversationActivityMonitor` service created in iOS app
2. Monitors incoming messages across all active conversations
3. Tracks conversation state: active, paused, threshold_exceeded
4. Configurable pause threshold (default: 120 seconds = 2 minutes)
5. Configurable message threshold (default: 20 messages in 10 minutes)
6. Service runs as background observer (doesn't block UI)

**Trigger Logic:**
7. **Pause Detection Trigger:** Conversation receives N messages, then pauses for X seconds → trigger analysis
8. **Active Conversation Trigger:** Conversation exceeds message threshold in time window → trigger analysis on next pause
9. **Debouncing:** Only one analysis per conversation per 5-minute window (prevent analysis spam)
10. **Current Conversation Exception:** If user is actively viewing conversation, suppress analysis (no notification needed)

**Repository Integration:**
11. New repository protocol: `NotificationAnalysisRepositoryProtocol` in Domain layer
12. Method: `analyzeConversationForNotification(conversationId: String, userId: String) async throws -> NotificationDecision`
13. Firebase implementation calls Cloud Function `analyzeForNotification`

**Testing:**
14. Unit test: Monitor tracks message timing correctly
15. Unit test: Pause detection triggers at correct threshold
16. Unit test: Active conversation suppression works
17. Integration test: Real message flow triggers analysis call
18. Performance: Monitor adds < 50ms overhead per message

## Story 6.2: RAG System for Full User Context

As a **developer**,
I want **to build a RAG (Retrieval-Augmented Generation) pipeline that provides AI with user's full conversation context**,
so that **notification decisions consider user's entire activity, not just one conversation**.

### Acceptance Criteria

**Conversation Indexing:**
1. Cloud Function: `indexConversationForRAG` triggered on new messages
2. Extracts message embeddings using OpenAI Ada (text-embedding-ada-002)
3. Stores embeddings in Firestore `message_embeddings` collection
4. Schema: { messageId, conversationId, embedding: [1536 floats], timestamp, participantIds }
5. Composite Firestore index: conversationId + timestamp (for fast queries)

**User Context Retrieval:**
6. Cloud Function helper: `getUserRecentContext(userId: String, limit: Int)`
7. Retrieves user's last 100 messages across all conversations (past 7 days)
8. Includes: messages user sent, messages in conversations user participates in, unread counts per conversation
9. Formats context for LLM: conversation summaries, user's participation level, recent topics

**Semantic Search:**
10. Cloud Function helper: `findRelevantMessages(userId: String, query: String, topK: Int)`
11. Converts query to embedding, performs cosine similarity search
12. Returns top K most relevant messages for context window
13. Used to find: past mentions of user, similar urgent requests, decision patterns

**User Preference Storage:**
14. Firestore collection: `users/{userId}/ai_notification_preferences`
15. Schema: { enabled: Bool, pauseThresholdSeconds: Int, activeHours: {start, end, timezone}, priorityKeywords: [String], maxAnalysesPerHour: Int }
16. Default preferences set on first opt-in
17. Preferences loaded into AI context for personalized decisions

**Performance:**
18. Embedding generation: < 2 seconds per message batch
19. Context retrieval: < 1 second for 100 messages
20. Semantic search: < 1 second for top 10 results
21. Total RAG overhead: < 3 seconds added to notification analysis

**Testing:**
22. Unit test: Embedding generation produces consistent results
23. Integration test: Context retrieval returns correct user messages
24. Integration test: Semantic search finds relevant past messages
25. Performance test: RAG pipeline completes within time limits

## Story 6.3: AI Notification Analysis Cloud Function

As a **user**,
I want **AI to intelligently decide which conversations deserve notifications**,
so that **I only get notified about truly important messages, not general chatter**.

### Acceptance Criteria

**Cloud Function: analyzeForNotification**
1. Function signature: `analyzeForNotification(conversationId: String, userId: String) -> NotificationDecision`
2. Returns: { shouldNotify: Bool, reason: String, notificationText: String, priority: "high" | "medium" | "low" }
3. Authentication: Validates Firebase Auth token, verifies user is conversation participant
4. Input validation: Checks conversationId exists, userId valid, conversation has unread messages

**AI Analysis Logic:**
5. Step 1: Fetch recent conversation messages (last 30 messages or 15 minutes, whichever is fewer)
6. Step 2: Filter to unread messages for this user (don't analyze already-read content)
7. Step 3: Retrieve user context via RAG (Story 6.2 dependencies)
8. Step 4: Call OpenAI GPT-4 with structured prompt (see below)
9. Step 5: Parse JSON response, validate structure

**LLM Prompt Structure:**
10. System prompt includes:
    - Role: "Notification assistant for remote team professionals"
    - Notification criteria: Mentions, urgent requests, direct questions, decisions affecting user, blockers, production issues
    - Non-notification criteria: General chat, FYI updates user isn't involved in, social/casual conversation
    - Output format: JSON with shouldNotify, reason, notificationText, priority
11. User context included: User's recent activity, preferences, active hours, priority keywords
12. Conversation context: Last N messages formatted with sender names, timestamps, message text
13. Temperature: 0.3 (more deterministic, consistent decisions)

**Notification Decision Quality:**
14. **Must notify:** Direct @mentions of user (100% notification rate)
15. **Must notify:** Direct questions to user ("Can you...", "Could you...", "Would you...")
16. **Must notify:** Decisions affecting user's work (detected via context: project names, user responsibilities)
17. **Should notify:** Urgent/time-sensitive keywords in user's priority list (default: "urgent", "ASAP", "production down", "blocker")
18. **Should not notify:** General team chat not involving user
19. **Should not notify:** Social/casual messages ("lol", "thanks!", emoji reactions)

**Notification Text Generation:**
20. Notification text clear and actionable: "Sarah mentioned you: 'Can you review the API design?'"
21. Notification text includes sender and key context
22. Notification text max 100 characters (iOS/Android limits)
23. Priority level affects iOS notification presentation (high = banner, medium = notification center, low = badge only)

**Caching & Cost Optimization:**
24. Check cache before LLM call: cacheKey = `notification_${conversationId}_${latestMessageId}`
25. Cache hit: Return cached decision (< 1 second)
26. Cache miss: Call LLM, cache result with 1-hour expiration
27. Cache invalidation: New messages in conversation clear cache

**Error Handling:**
28. OpenAI rate limit (429): Return `{ shouldNotify: false, reason: "AI temporarily unavailable" }`
29. Timeout (>10 seconds): Return fallback decision based on simple heuristics (mentions = notify)
30. Network error: Log error, return `{ shouldNotify: false }`
31. Invalid response from LLM: Retry once, then fallback to heuristics

**Fallback Heuristics (when AI unavailable):**
32. If message contains "@username" where username = current user → notify (high priority)
33. If message contains priority keywords → notify (medium priority)
34. If message is direct question (ends with "?") and mentions user → notify (medium priority)
35. Otherwise → don't notify

**Testing:**
36. Unit test: Prompt structure correct, includes required context
37. Unit test: JSON parsing handles all response formats
38. Integration test: Call with test conversation, verify decision structure
39. Integration test: Direct mention always returns shouldNotify=true
40. Integration test: General chat returns shouldNotify=false
41. Integration test: Cache hit returns instantly (< 1 second)
42. Integration test: AI unavailable falls back to heuristics
43. Performance test: Analysis completes within 8 seconds (including RAG)

## Story 6.4: User Preferences, Opt-In Controls & Fallback

As a **user**,
I want **to control smart notification settings and provide explicit consent**,
so that **I maintain privacy and can customize notification behavior to my needs**.

### Acceptance Criteria

**Opt-In Flow:**
1. New settings section: "Smart Notifications (AI-Powered)" in app Settings
2. First-time setup: Modal explaining feature when user opens settings
3. Modal content:
   - "Let AI analyze your conversations to reduce notification fatigue"
   - "Only get notified about messages that matter to you"
   - "AI considers mentions, urgent requests, and context"
   - "You can disable this anytime"
4. Explicit opt-in required: "Enable Smart Notifications" button
5. Opt-in saves preference to Firestore: `users/{userId}/ai_notification_preferences/enabled = true`

**Privacy & Consent:**
6. Privacy statement in modal: "Your messages are analyzed securely. We don't store message content, only notification decisions."
7. Link to privacy policy
8. User can opt-out anytime (disable feature, revert to standard notifications)
9. Opt-out confirmation: "Are you sure? You'll receive notifications for every message."

**Notification Preferences UI:**
10. Setting: Enable/Disable Smart Notifications (toggle)
11. Setting: Pause threshold slider (60s - 300s, default 120s)
12. Setting: Active conversation message threshold (10-50 messages, default 20)
13. Setting: Quiet hours (start time, end time, timezone) - suppress non-urgent notifications
14. Setting: Priority keywords (user-customizable list, default: "urgent", "ASAP", "production", "down", "blocker")
15. Setting: Max analyses per hour (5-20, default 10) - cost control

**Fallback Strategy:**
16. Setting: "If AI is unavailable" dropdown with options:
    - "Use simple rules (mentions, keywords)" [Default]
    - "Notify for all messages" (traditional behavior)
    - "No notifications" (suppresses notifications entirely)
17. Fallback preference stored in Firestore, used when Cloud Function fails
18. Fallback status displayed in settings: "AI Status: ✅ Active" or "⚠️ Using Fallback (AI unavailable)"

**Testing Preferences:**
19. Button: "Test Smart Notification" - triggers analysis on most recent conversation, shows result modal
20. Test result modal shows: "Decision: Notify ✅ / Don't Notify ❌", "Reason: [AI reasoning]", "Notification text: [generated text]"
21. Helps users understand how AI makes decisions

**Real-Time Preference Updates:**
22. Preferences sync via Firestore snapshot listener
23. Changes take effect immediately (no app restart required)
24. Cloud Function reads latest preferences on each analysis call

**Default Preferences:**
25. On first opt-in, create default preferences:
    - enabled: true
    - pauseThresholdSeconds: 120
    - activeConversationThreshold: 20
    - quietHoursStart: "22:00"
    - quietHoursEnd: "08:00"
    - priorityKeywords: ["urgent", "ASAP", "production down", "blocker", "help"]
    - maxAnalysesPerHour: 10
    - fallbackStrategy: "simple_rules"

**Testing:**
26. Unit test: Opt-in flow sets correct Firestore values
27. Unit test: Preference changes update Firestore
28. Integration test: Quiet hours suppress notifications correctly
29. Integration test: Priority keywords trigger notifications
30. Integration test: Fallback strategy used when AI unavailable
31. UI test: Settings UI displays current preferences accurately
32. UI test: Test notification button shows correct analysis result

## Story 6.5: Feedback Loop, Analytics & Continuous Improvement

As a **user**,
I want **to provide feedback on notification decisions**,
so that **the AI learns my preferences and improves over time**.

### Acceptance Criteria

**Notification Feedback UI:**
1. When notification delivered, notification includes action buttons: "👍 Helpful" | "👎 Not Helpful"
2. iOS: Use UNNotificationAction for interactive notifications
3. Tap feedback button sends feedback to Cloud Function: `submitNotificationFeedback`
4. Feedback stored in Firestore: `notification_feedback` collection
5. Schema: { userId, conversationId, messageId, decision: {shouldNotify, reason}, feedback: "helpful" | "not_helpful", timestamp }

**In-App Feedback:**
6. Settings section: "Notification History" shows last 20 notifications
7. Each entry shows: conversation name, notification text, timestamp, AI reasoning
8. User can provide feedback retroactively: thumbs up/down on each entry
9. Feedback syncs to Firestore immediately

**Feedback Analytics Dashboard (Cloud Function):**
10. Cloud Function: `generateNotificationAnalytics(userId: String)` (admin only)
11. Returns: { totalNotifications, helpfulCount, notHelpfulCount, accuracy: helpfulCount/total, commonFalsePositives: [...], commonFalseNegatives: [...] }
12. False positives: Notified but marked "not helpful"
13. False negatives: Didn't notify but user manually opened conversation within 5 minutes (inferred miss)

**Learning from Feedback:**
14. Cloud Function: `updateUserNotificationProfile(userId: String)` (runs weekly)
15. Analyzes user's feedback history
16. Updates user profile: `users/{userId}/ai_notification_profile`
17. Profile includes: { preferredNotificationRate: "high" | "medium" | "low", learnedKeywords: [String], suppressedTopics: [String] }
18. LLM prompt in Story 6.3 includes user profile for personalization

**Prompt Refinement:**
19. User profile injected into LLM system prompt: "User prefers fewer notifications (medium rate). User finds these topics important: [list]. User doesn't want notifications about: [list]."
20. Learned keywords added to priority detection logic
21. Suppressed topics reduce notification likelihood

**False Negative Detection:**
22. Background job: Detects when user opens conversation within 5 minutes of message arrival (possible missed notification)
23. Checks if notification was suppressed by AI decision
24. Logs as potential false negative in analytics
25. If pattern detected (multiple false negatives in conversation), adjusts user profile

**Analytics Logging:**
26. Every notification decision logged to Firestore: `notification_decisions` collection
27. Schema: { userId, conversationId, timestamp, decision, aiReasoning, wasDelivered: Bool, userFeedback: String? }
28. Used for debugging and improving prompts

**Cost Tracking:**
29. Log AI API costs per analysis: `ai_usage_logs` collection
30. Schema: { userId, timestamp, feature: "smart_notification", tokensUsed, estimatedCost }
31. Admin dashboard: View total costs, cost per user, cost trends

**Performance Metrics:**
32. Track analysis latency: p50, p95, p99
33. Track cache hit rate (target: 60%+ cache hits)
34. Track fallback usage rate (target: < 5% fallback due to errors)

**Testing:**
35. Unit test: Feedback submission stores correct data
36. Integration test: Feedback affects future notifications (learned preferences applied)
37. Integration test: False negative detection identifies missed notifications
38. Integration test: Analytics function returns accurate statistics
39. UI test: Notification history displays correctly
40. UI test: Feedback buttons work in notifications and history

## Story 6.6: Push Notification Delivery & Deep Linking

As a **user**,
I want **to receive smart notifications on my device and tap to view the conversation**,
so that **I can quickly respond to important messages**.

### Acceptance Criteria

**FCM Integration:**
1. Reuse existing FCM token registration from Story 2.10
2. Cloud Function `analyzeForNotification` sends FCM push when shouldNotify=true
3. FCM payload includes: { title: "MessageAI", body: notificationText, priority, conversationId, messageId }

**Notification Presentation:**
4. High priority: Alert banner with sound
5. Medium priority: Silent notification in notification center
6. Low priority: Badge update only (no banner/sound)
7. Notification includes sender avatar (if available)
8. Notification grouped by conversation (iOS notification grouping)

**Interactive Notification Actions:**
9. Action buttons: "👍 Helpful" | "👎 Not Helpful" (Story 6.5 feedback)
10. Quick reply action: "Reply" opens text input, sends message directly from notification
11. Mark as read action: "Mark Read" dismisses notification, marks messages as read in Firestore

**Deep Linking:**
12. Tap notification opens app to specific conversation
13. Scrolls to specific message that triggered notification (messageId in payload)
14. Highlights message briefly (yellow flash animation)
15. Deep link works when app is closed, backgrounded, or active

**Notification Suppression:**
16. If user is actively viewing conversation, suppress notification (don't send FCM)
17. Check implemented in Cloud Function: Query Firestore `user_activity` collection for active conversation
18. Update `user_activity` on conversation view appear/disappear

**Quiet Hours:**
19. Cloud Function checks user's quiet hours preference before sending notification
20. If current time within quiet hours AND priority < high: Don't send notification
21. High priority notifications bypass quiet hours (urgent messages)

**Rate Limiting:**
22. Enforce maxAnalysesPerHour limit from user preferences
23. If limit exceeded, queue analysis for later or fall back to simple rules
24. User notified: "Smart notification limit reached. Using simple rules."

**Testing:**
25. Integration test: Notification delivered with correct priority
26. Integration test: Tap notification deep links to conversation
27. Integration test: Feedback buttons send correct data
28. Integration test: Quick reply sends message successfully
29. Integration test: Active conversation suppression works
30. Integration test: Quiet hours suppress non-urgent notifications
31. UI test: Notification displays with correct text and actions

---

## Implementation Order

**CRITICAL: Complete Story 6.0 (Setup & Prerequisites) FIRST before starting any other stories.**

**Phase 1: Foundation** (can be implemented in parallel)
- **Story 6.0:** Setup & Prerequisites - OpenAI API, Firestore rules/indexes, environment config
- **Story 6.4:** User Preferences, Opt-In Controls & Fallback - Defines NotificationPreferences schema used by other stories
- **Story 6.1:** Activity Monitoring & Trigger Logic - Client-side infrastructure for detecting when to analyze

**Phase 2: AI Core** (must be sequential)
- **Story 6.2:** RAG System for Full User Context - Provides context for Story 6.3 (depends on 6.4 schema)
- **Story 6.3:** AI Notification Analysis - Core LLM decision logic (depends on 6.2 RAG, requires 6.4 preferences)

**Phase 3: Delivery & Feedback** (can be parallel after Phase 2)
- **Story 6.6:** Push Notification Delivery & Deep Linking - Sends notifications based on 6.3 decisions
- **Story 6.5:** Feedback Loop & Analytics - Enhances 6.3 with learning (integrates with 6.6 notification actions)

**Recommended Implementation Timeline:**
- **Week 1:** Story 6.0 + 6.4 + 6.1 (foundation)
- **Week 2:** Story 6.2 + 6.3 (AI core)
- **Week 3:** Story 6.6 + 6.5 (delivery and learning)

**Note:** For bootcamp demo, Story 6.5's false negative detection and cost tracking are optional (focus on explicit user feedback instead).

---

## Epic Dependencies

- **Epic 2 (Story 2.10):** Push notification infrastructure (FCM token registration, AppDelegate hooks)
- **Epic 3 (Story 3.1):** Cloud Functions infrastructure
- **Epic 3 (Story 3.5):** OpenAI API configuration (reused for Epic 6)

## Cross-Story Integration Notes

**Story 6.1 ↔ Story 6.6:** Active conversation suppression
- 6.1 implements client-side check (don't call Cloud Function if user viewing conversation)
- 6.6 implements server-side backup check (Cloud Function queries user_activity as safety net)

**Story 6.2 ↔ Story 6.3:** RAG provides context for notification decisions
- 6.2 builds embedding infrastructure (on-demand, not real-time)
- 6.3 calls 6.2 helpers to get user context before LLM decision

**Story 6.4 ↔ Stories 6.2, 6.3, 6.6:** Preferences schema ownership
- 6.4 DEFINES NotificationPreferences schema
- 6.2 loads preferences for AI context
- 6.3 uses preferences in LLM prompt
- 6.6 checks quiet hours and rate limits from preferences

**Story 6.5 ↔ Story 6.6:** Feedback collection
- 6.6 adds feedback buttons to notifications ("👍 Helpful" | "👎 Not Helpful")
- 6.5 processes feedback and updates user profile
- 6.3 includes updated profile in future LLM prompts (learning loop)

---

## Success Metrics

- **Notification Reduction:** 70%+ reduction in notification volume (measured via Firebase Analytics)
- **User Engagement:** Notification tap rate increases from 15% → 60%+ (smart notifications more relevant)
- **Accuracy:** 80%+ of delivered notifications marked "helpful" by users (via feedback)
- **Performance:** 95%+ of analyses complete within 8 seconds
- **Cost:** < $0.02 per notification analysis (with 60%+ cache hit rate)
- **Adoption:** 50%+ of active users opt-in to smart notifications within 2 weeks

## Known Limitations & Future Work

- **Language Support:** AI quality best with English conversations. Multi-language support requires additional prompt engineering.
- **Cold Start:** First few notifications may be less accurate (no user profile yet). Improves with feedback.
- **Group Conversations:** Large group chats (10+ participants) may require different heuristics.
- **Real-Time Collaboration:** Very active channels (100+ messages/hour) may hit rate limits.

## Testing Strategy

- **Unit Tests:** Each component (monitor, RAG, LLM caller) tested independently
- **Integration Tests:** End-to-end flow with Firebase Emulator
- **Manual Testing:** Real conversations tested with beta users
- **A/B Testing (Future):** Compare smart notifications vs traditional (if needed for validation)

---
