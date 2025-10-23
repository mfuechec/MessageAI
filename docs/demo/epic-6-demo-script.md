# Epic 6: Smart AI-Powered Notifications - Demo Script

## Overview

This demo script showcases **Epic 6: Smart AI-Powered Notifications** for bootcamp evaluation. The demo highlights:
1. **RAG (Retrieval-Augmented Generation)** for personalized notification decisions
2. **LLM-based intelligence** to reduce notification fatigue
3. **User feedback loop** for continuous learning
4. **Clean Architecture** patterns throughout

**Demo Duration:** 10-15 minutes

---

## Demo Setup (Before Presenting)

### Prerequisites Checklist

- [ ] **User Accounts:** Create 3 test users (Alice, Bob, Charlie)
- [ ] **Conversations:** Set up test conversations with varied content:
  - Conversation 1: Technical discussion (direct mentions, urgent keywords)
  - Conversation 2: Social chat (casual, no urgent content)
  - Conversation 3: Decision-making (affects user's work)
- [ ] **Preferences:** Alice has smart notifications enabled, Bob does not
- [ ] **Test Messages:** Prepare messages to send during demo
- [ ] **Firebase Console:** Open to show real-time Firestore updates
- [ ] **Xcode:** App running on simulator or device
- [ ] **OpenAI Usage:** Check API quota is sufficient

### Demo Environment

**Use development environment:**
- `firebase use messageai-dev-1f2ec`
- iOS Simulator: iPhone 17 Pro
- Xcode with console output visible
- Firebase Console open in browser

---

## Demo Flow

### Part 1: The Problem (2 minutes)

**Script:**
> "Remote teams drown in notifications. Every message triggers an alert. Users either mute everything and miss important updates, or suffer constant interruption."
>
> "Let me show you the problem..."

**Demo Actions:**
1. Show Bob (user without smart notifications)
2. Send 5 messages to Bob's conversation:
   - "Hey team, how's everyone doing?"
   - "I'm good, thanks!"
   - "Anyone up for lunch?"
   - "@Bob can you review the API design?" (IMPORTANT)
   - "Great weather today 🌞"

3. Show Bob's notification center:
   - **5 notifications** - all treated equally
   - Bob misses the important @mention in the noise

**Key Points:**
- Traditional notifications: one-size-fits-all
- Important messages get lost in social chatter
- Users develop "notification blindness"

---

### Part 2: The Solution - Smart Notifications (3 minutes)

**Script:**
> "Now let's see Smart Notifications with Alice. Alice has AI analyzing her conversations to only notify about truly important messages."

**Demo Actions:**

**2.1 - Opt-In Flow (Story 6.4)**
1. Open Alice's Settings → Notifications
2. Show "Smart Notifications (AI-Powered)" section
3. Tap "Enable Smart Notifications" button
4. Show opt-in modal:
   - Privacy statement
   - Feature explanation
   - User control emphasized

5. Alice opts in → defaults saved to Firestore
6. Show Firebase Console: `users/alice/ai_notification_preferences` created

**Key Points:**
- Explicit user consent required
- Privacy-first approach
- User maintains full control

---

**2.2 - Activity Monitoring (Story 6.1)**

**Script:**
> "The system monitors conversation activity and detects natural pauses. It doesn't analyze every message - only when appropriate."

**Demo Actions:**
1. Send 3 messages rapidly to Alice's conversation:
   - "Hey team"
   - "Quick update on the project"
   - "We're on track for Friday's deadline"

2. Show Xcode console: `ConversationActivityMonitor` tracking messages
3. Wait 2 minutes (conversation pauses)
4. Console shows: `"Pause detected, triggering analysis..."`

**Key Points:**
- Client-side activity monitoring (Story 6.1)
- Debouncing prevents analysis spam
- Waits for natural conversation pauses

---

**2.3 - RAG Context Retrieval (Story 6.2)**

**Script:**
> "Before deciding, the AI retrieves full context about Alice: her recent activity, preferences, and past conversations. This is RAG - Retrieval-Augmented Generation."

**Demo Actions:**
1. Show Firebase Console: `message_embeddings` collection
   - Embeddings generated on-demand (lazy loading)
   - Show embedding vector (1536 dimensions)

2. Show Cloud Function logs: `getUserRecentContext` called
   - Retrieves last 100 messages across Alice's conversations
   - Loads user preferences
   - Performs semantic search for relevant past mentions

3. Highlight RAG advantages:
   - **Temporal context:** What Alice discussed recently
   - **Semantic context:** Similar past urgent requests
   - **Preference context:** Alice's notification preferences

**Key Points:**
- RAG provides rich context beyond just current conversation
- On-demand embedding (cost-efficient)
- Semantic search finds relevant past messages

---

**2.4 - AI Decision Making (Story 6.3)**

**Script:**
> "Now the AI analyzes these messages with full context. It uses GPT-4 to decide: Should Alice be notified?"

**Demo Actions:**
1. Show Cloud Function: `analyzeForNotification` executing
2. Show LLM prompt structure:
   ```
   System: You are a notification assistant...
   User context: Alice prefers moderate notifications...
   Recent activity: [Alice's last 100 messages]
   Conversation: [3 messages about project status]

   Decision: Should notify?
   ```

3. Show AI decision returned:
   ```json
   {
     "shouldNotify": false,
     "reason": "General project update not requiring Alice's action",
     "notificationText": "",
     "priority": "low"
   }
   ```

4. Result: **No notification sent** to Alice (correct decision - just a status update)

**Key Points:**
- LLM makes intelligent decision with full context
- Explains reasoning (transparency)
- This saves Alice from unnecessary interruption

---

**2.5 - Testing Different Message Types**

**Script:**
> "Let's test with different message types to show how the AI adapts."

**Test 1: Direct Mention (SHOULD notify)**
1. Send: "@Alice can you review the API design by EOD?"
2. Show AI decision:
   ```json
   {
     "shouldNotify": true,
     "reason": "Direct mention with action requested",
     "notificationText": "Bob mentioned you: Can you review the API design by EOD?",
     "priority": "high"
   }
   ```
3. **Alice receives notification** ✅
4. Tap notification → deep links to exact message (Story 6.6)
5. Message highlighted briefly (yellow flash)

**Test 2: Urgent Keyword (SHOULD notify)**
1. Send: "Production down! Database connection failing"
2. Show AI decision:
   ```json
   {
     "shouldNotify": true,
     "reason": "Urgent priority keyword detected",
     "notificationText": "Bob: Production down! Database connection failing",
     "priority": "high"
   }
   ```
3. **Alice receives notification** ✅
4. Bypasses quiet hours (high priority)

**Test 3: Social Chat (should NOT notify)**
1. Send: "Great job on the demo! 🎉"
2. Show AI decision:
   ```json
   {
     "shouldNotify": false,
     "reason": "Social conversation not involving Alice",
     "notificationText": "",
     "priority": "low"
   }
   ```
3. **No notification** ✅

**Key Points:**
- AI correctly distinguishes important vs. casual messages
- Personalized to Alice's preferences
- Transparent reasoning for each decision

---

### Part 3: User Preferences & Customization (2 minutes)

**Script:**
> "Users have full control. Let's customize Alice's preferences."

**Demo Actions:**

**3.1 - Preference Settings (Story 6.4)**
1. Open Alice's Settings → Smart Notifications
2. Show preference controls:
   - Enable/Disable toggle
   - Pause threshold slider (60-300 seconds)
   - Quiet hours time pickers
   - Priority keywords (add "urgent", "ASAP", "blocker")
   - Fallback strategy dropdown

3. Add "demo" as priority keyword
4. Save → preferences sync via Firestore snapshot listener
5. Show Firebase Console: preferences updated immediately

**3.2 - Test Notification Feature**
1. Tap "Test Smart Notification" button
2. App calls `analyzeForNotification` with Alice's recent conversation
3. Show test result modal:
   - Decision: ✅ Will Notify / ❌ Won't Notify
   - Priority badge
   - AI reasoning
   - Notification text preview
   - Note: "This is a test - no actual notification sent"

4. Helps Alice understand how AI makes decisions

**Key Points:**
- Full user control and transparency
- Real-time preference sync
- Test feature for understanding AI behavior

---

### Part 4: Feedback Loop & Learning (2 minutes)

**Script:**
> "The AI learns from Alice's feedback. If Alice marks a notification as 'Not Helpful', the system adapts."

**Demo Actions:**

**4.1 - Providing Feedback (Story 6.5)**
1. Alice receives notification with action buttons:
   - 👍 Helpful
   - 👎 Not Helpful

2. Alice taps "👍 Helpful" on important notification
3. Show Firebase Console: `notification_feedback` entry created
4. Show feedback stored:
   ```json
   {
     "userId": "alice",
     "conversationId": "conv123",
     "feedback": "helpful",
     "decision": { ... },
     "timestamp": "2025-10-23T..."
   }
   ```

**4.2 - Profile Updates (Learning)**
1. Show Cloud Function: `updateUserNotificationProfile` (runs weekly)
2. Analyzes Alice's feedback history:
   - 85% marked "helpful" → `preferredNotificationRate: "high"`
   - Extract learned keywords from helpful notifications
   - Extract suppressed topics from not-helpful notifications

3. Show updated profile:
   ```json
   {
     "userId": "alice",
     "preferredNotificationRate": "high",
     "learnedKeywords": ["API", "production", "review"],
     "suppressedTopics": ["lunch", "weather", "social"],
     "accuracy": 0.85
   }
   ```

4. Future notifications use this profile in LLM prompt:
   > "User prefers frequent notifications. User finds these topics important: API, production, review. User doesn't want notifications about: lunch, weather, social."

**4.3 - Notification History**
1. Open Settings → Notification History
2. Show last 20 notification decisions
3. Each entry shows:
   - Conversation name
   - Notification text
   - AI reasoning
   - Thumbs up/down for retroactive feedback

**Key Points:**
- Continuous learning from user feedback
- AI personalizes over time
- Full transparency (history + reasoning)

---

### Part 5: Architecture Highlights (3 minutes)

**Script:**
> "Let me show the architecture that makes this possible. This follows Clean Architecture and MVVM patterns."

**Demo Actions:**

**5.1 - Clean Architecture Layers**

Show Xcode project structure:

```
MessageAI/
├── Domain/                        # Pure Swift - NO Firebase
│   ├── Entities/
│   │   ├── NotificationDecision.swift
│   │   └── NotificationPreferences.swift
│   └── Repositories/
│       └── NotificationAnalysisRepositoryProtocol.swift
│
├── Data/                          # Firebase implementations
│   └── Repositories/
│       └── FirebaseNotificationAnalysisRepository.swift
│
└── Presentation/                  # SwiftUI + ViewModels
    ├── ViewModels/
    │   ├── NotificationPreferencesViewModel.swift
    │   └── NotificationHistoryViewModel.swift
    └── Services/
        └── ConversationActivityMonitor.swift
```

**Key Points:**
- **Domain layer:** Pure Swift, no external dependencies
- **Data layer:** Firebase implementations (hidden from ViewModels)
- **Presentation layer:** MVVM with @MainActor for Swift 6 concurrency

**5.2 - Cloud Functions Architecture**

Show `functions/` directory:

```
functions/src/
├── analyzeForNotification.ts      # Main decision function
├── helpers/
│   ├── indexConversationForRAG.ts # On-demand embedding
│   ├── user-context.ts             # RAG context retrieval
│   └── semantic-search.ts          # Cosine similarity search
├── prompts/
│   └── notification-analysis-prompt.ts
└── services/
    └── openai-service.ts           # OpenAI client wrapper
```

**Key Points:**
- Modular Cloud Functions
- RAG helpers reusable across features
- Clear separation of concerns

**5.3 - Testing Approach**

Show test files:

```
MessageAITests/
├── Presentation/Services/
│   └── ConversationActivityMonitorTests.swift
├── Data/Repositories/
│   └── FirebaseNotificationAnalysisRepositoryTests.swift
└── Integration/
    └── SmartNotificationIntegrationTests.swift
```

Open `ConversationActivityMonitorTests.swift`:
- Mock repositories for unit tests
- Firebase Emulator for integration tests
- **LLM tests use recorded fixtures** (not live API calls)

Example test:
```swift
func testPauseDetectionTriggersAnalysis() async throws {
    // Given: Messages sent
    monitor.onNewMessage(conversationId: "conv1")

    // When: Pause exceeds threshold
    try await Task.sleep(nanoseconds: 121_000_000_000) // 121 seconds

    // Then: Analysis triggered
    XCTAssertTrue(mockRepository.analyzeWasCalled)
}
```

**Key Points:**
- 70%+ test coverage maintained
- Mock repositories for fast unit tests
- Integration tests use Firebase Emulator (no production impact)
- LLM testing uses fixtures (deterministic, no API costs)

---

### Part 6: Cost Optimization & Caching (2 minutes)

**Script:**
> "RAG and LLM calls are expensive. We implemented aggressive caching."

**Demo Actions:**

**6.1 - Cache Strategy**
1. Show first notification analysis (cache miss):
   - Time: 7.5 seconds
   - Cost: ~$0.08 (RAG + GPT-4 call)

2. Show second analysis (same unread messages):
   - Time: 0.8 seconds ⚡
   - Cost: ~$0.0004 (just Firestore read)
   - **Cache hit!**

3. Show cache key generation:
   ```typescript
   // Hash of unread message IDs (not all messages)
   const cacheKey = `notification_${conversationId}_${unreadMessagesHash}`;
   ```

4. Show Firebase Console: `ai_notification_cache` collection
   - Cache entry with 1-hour TTL
   - Invalidates only when NEW unread messages arrive

**6.2 - On-Demand Embedding**
1. Show `message_embeddings` collection
2. Explain: Embeddings generated **on-demand**, not for every message
3. Check existing embeddings before calling OpenAI
4. Reuse embeddings if < 7 days old

**Key Points:**
- Improved cache hit rate: 60% → 75%+ (better cache key strategy)
- On-demand embedding reduces cost by 80%
- Cost-effective for production at scale

---

## Demo Wrap-Up (1 minute)

**Script:**
> "To summarize what we built:
>
> **1. Intelligent Notification Filtering:** RAG + LLM analyze conversations with full user context to decide what's important.
>
> **2. User-Centric Design:** Explicit opt-in, full transparency, complete control over preferences.
>
> **3. Continuous Learning:** AI learns from user feedback and adapts over time.
>
> **4. Clean Architecture:** Domain, Data, Presentation layers with strict boundaries and 70%+ test coverage.
>
> **5. Production-Ready:** Aggressive caching, on-demand embedding, cost-optimized RAG pipeline.
>
> This is the future of notification intelligence. Thank you!"

---

## Q&A Preparation

**Expected Questions:**

**Q: How accurate is the AI?**
A: Target is 80%+ accuracy (measured via user feedback "helpful" rate). Fallback heuristics ensure critical messages (mentions, urgent keywords) are never missed.

**Q: What happens if OpenAI API is down?**
A: Automatic fallback to simple heuristics:
- Direct mentions → notify
- Priority keywords → notify
- Otherwise → don't notify
Fallback triggers < 5% of the time, users can configure fallback behavior.

**Q: How much does this cost at scale?**
A: With 60% cache hit rate: ~$0.03 per analysis. For 1000 users with 10 analyses/day: ~$900/month. With improved caching (75% hit rate): ~$600/month. Production optimizations (batch processing, lighter models for simple cases) can reduce further.

**Q: Can users disable smart notifications?**
A: Yes, anytime. Settings → Smart Notifications → Toggle off. Reverts to traditional notifications immediately.

**Q: How is this different from Epic 3 (AI Summaries)?**
A: Epic 3 summarizes conversations on-demand. Epic 6 decides **whether to interrupt the user**. Different goals:
- Summaries: "What was discussed?"
- Notifications: "Should I interrupt this specific user?"
RAG in Epic 6 focuses on user personalization, not conversation content.

**Q: Does the AI store message content?**
A: No. We store:
- Message embeddings (mathematical vectors)
- Notification decisions (metadata)
- User feedback
Message text is only processed during analysis, not stored long-term. Privacy statement in opt-in modal explains this.

---

## Technical Demo Tips

**If something breaks during demo:**

**Plan B - Cache Issue:**
- Clear cache: Delete `ai_notification_cache` collection entries
- Re-run analysis to regenerate

**Plan C - OpenAI Rate Limit:**
- Use fallback heuristics (already in code)
- Show fallback decision instead

**Plan D - Firebase Emulator:**
- Have emulator running as backup
- Can switch to local testing if Firebase Console unreachable

**Always have:**
- Backup video recording of working demo
- Screenshots of key Firebase Console states
- Xcode project with pre-configured test data

---

## After Demo

**Follow-up Materials:**
- GitHub repo link with code
- Architecture diagrams
- Epic 6 PRD document
- Story breakdown (6.0-6.6)
- Cost analysis spreadsheet

**Bootcamp Evaluation Rubric:**
- ✅ RAG implementation (Story 6.2)
- ✅ LLM integration (Story 6.3)
- ✅ Clean Architecture maintained
- ✅ User feedback loop (Story 6.5)
- ✅ 70%+ test coverage
- ✅ Production-ready error handling
- ✅ Privacy & user control (Story 6.4)

---

**Good luck with your demo! 🚀**
