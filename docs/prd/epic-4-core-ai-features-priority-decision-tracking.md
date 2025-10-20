# Epic 4: Core AI Features - Priority & Decision Tracking

## Epic 4 Goal

Implement the final two required AI features (priority message detection and decision tracking) and build the Insights dashboard that aggregates AI content across all conversations. This epic completes the 5 required AI features for Gauntlet evaluation. Regression testing ensures core messaging remains stable with all AI features active. Expected timeline: 1.5 days.

## Story 4.1: Priority Message Detection

As a **user**,  
I want **messages that require my attention to be automatically highlighted**,  
so that **I don't miss important questions or requests directed at me**.

### Acceptance Criteria

**UI & Visual Treatment:**
1. Priority messages display with subtle visual indicator (yellow accent border or icon)
2. Priority badge appears in conversations list: "2 priority messages"
3. Tap priority badge filters conversation to show only priority messages
4. Long-press priority message shows option: "Why is this priority?"
5. "Why is this priority?" displays AI explanation modal: "This message asks you a direct question about deployment timeline"

**AI Implementation:**
6. Cloud Function created: `detectPriorityMessages` accepting conversationId and userId
7. Function analyzes new messages for priority signals:
   - Direct questions to user ("Can you...", "@username", user's name mentioned)
   - Urgency keywords ("ASAP", "urgent", "blocking", "critical")
   - Decision requests ("Need your approval", "What do you think?")
   - Assigned action items detected in message
8. Function returns array of messageIds with priority score (0-1) and reason
9. Messages with score > 0.7 marked as priority
10. Priority status stored in Firestore message document: `isPriority: true, priorityReason: string`

**Real-Time Detection:**
11. Cloud Function triggered on new message write (Firestore trigger)
12. Priority detection runs asynchronously (doesn't block message delivery)
13. Priority status updates in real-time for all participants
14. Push notifications enhanced: Priority messages get different notification sound/badge

**Quality Acceptance Criteria (Define "Good Enough"):**
15. Detects direct questions: "Sarah, can you review the PR?" → Priority for Sarah
16. Detects urgency: "Need this ASAP" → Priority
17. Doesn't over-flag: "What's for lunch?" in social chat → Not priority
18. Context-aware: Understands when user's name is mentioned in relevant context
19. Manual validation: 10 test conversations, verify 80%+ precision (flagged messages are actually important)
20. False positive rate < 20% (acceptable to miss some priorities, but minimize noise)

**Performance:**
21. Priority detection completes within 5 seconds of message arrival
22. Doesn't impact message delivery speed (runs asynchronously)
23. Priority status cached, re-evaluated only when conversation context changes

**Testing:**
24. Unit tests for priority detection logic in Cloud Function
25. Integration test: Send priority message, verify it's flagged correctly
26. Integration test: Send non-priority message, verify it's not flagged
27. Regression test: Message delivery, editing, and AI features still work correctly

## Story 4.2: Decision Tracking System

As a **user**,  
I want **AI to track important decisions made in conversations**,  
so that **I can reference past agreements and understand why choices were made**.

### Acceptance Criteria

**UI & Interaction:**
1. Long-press any message shows option: "Mark as Decision"
2. Manual tagging opens modal: "What was decided?" with text input
3. User can edit AI-suggested decision summary or write custom
4. Decision saved with: summary, conversation link, participants, timestamp
5. Decisions visible in Insights tab "Recent Decisions" section
6. Each decision card shows: summary, context link, date, participants
7. Tap decision card navigates to source message in conversation
8. Decision indicator (badge or icon) on source message in chat view

**AI-Assisted Detection:**
9. Cloud Function created: `detectDecisions` analyzing conversations for decision signals
10. Decision signals detected:
    - "We decided to...", "Let's go with...", "Agreed", "Final decision:"
    - Resolution of previous debate/discussion
    - Explicit consensus statements
11. Function suggests decisions via in-app notification: "Detected decision: 'Use Firebase for backend'. [Save] [Ignore]"
12. Suggested decisions stored temporarily until user confirms or dismisses

**Data Model:**
13. Firestore collection `decisions` created with schema:
    - id, conversationId, messageId, summary, participants[], timestamp, tags[]
14. Decisions indexed by conversationId and timestamp for fast querying
15. User can add tags to decisions: "technical", "product", "urgent"

**Quality Acceptance Criteria (Define "Good Enough"):**
16. Detects explicit decisions: "We're going with option B" → Captured
17. Provides context: Decision includes preceding discussion summary
18. Doesn't hallucinate: Only suggests decisions actually stated in conversation
19. Manual validation: 8/10 explicit decisions detected and suggested correctly
20. User override: Manual tagging works even if AI doesn't detect decision

**Insights Dashboard Integration:**
21. Recent Decisions view shows last 20 decisions across all conversations
22. Filter by: conversation, date range, tags, participants
23. Search decisions: "What did we decide about the API?"
24. Export decisions as markdown or CSV (stretch goal: not MVP required)

**Performance:**
25. Decision detection runs on-demand (when user opens Insights tab) or nightly batch
26. Decision list loads < 2 seconds
27. Cached decisions with 1-hour refresh

**Testing:**
28. Unit tests for decision detection logic
29. Integration test: Make explicit decision in conversation, verify detection or manual tagging works
30. Integration test: Search decisions, verify correct results returned
31. Regression test: All previous AI features still functional

## Story 4.3: Insights Dashboard - Aggregated View

As a **user**,  
I want **a central dashboard showing AI insights across all my conversations**,  
so that **I can manage action items, review decisions, and see priority messages in one place**.

### Acceptance Criteria

**Navigation & Structure:**
1. Insights tab (second tab) in main navigation with sparkle/AI icon
2. Dashboard shows four main sections:
   - **Priority Messages Inbox** (top)
   - **All Action Items**
   - **Recent Decisions**
   - **Proactive Suggestions** (placeholder for Epic 5)
3. Empty states for each section: "No priority messages", "No action items yet"
4. Pull-to-refresh updates all sections

**Priority Messages Inbox:**
5. Card-based list showing priority messages from all conversations
6. Each card displays: message text, sender, conversation name, timestamp, priority reason
7. Tap card navigates to message in conversation
8. Swipe actions: "Mark as Read", "Respond", "Not Priority" (removes flag)
9. Badge on Insights tab shows unread priority message count

**All Action Items Section:**
10. List of action items from all conversations
11. Grouped by: Assigned to me, Assigned to others, Unassigned
12. Each item shows: task, assignee, conversation context, due date (if detected)
13. Checkbox to mark action items complete
14. Completed items archived (not deleted), viewable in "Completed" filter
15. Tap action item navigates to source message

**Recent Decisions Section:**
16. Timeline view of recent decisions (last 30 days)
17. Decision cards show: summary, date, conversation, participants
18. Search bar: "Search decisions..."
19. Filter chips: "This Week", "Technical", "Product", "All Conversations"
20. Tap decision navigates to source conversation

**Performance:**
21. Dashboard initial load < 2 seconds
22. Each section loads independently (progressive loading)
23. Cached data shown immediately, refresh in background
24. Smooth scrolling with 100+ items across all sections

**Design & UX:**
25. Clean, organized layout with clear section headers
26. Dark mode styling applied
27. Accessibility: VoiceOver support, dynamic type
28. Visual distinction between sections (subtle dividers, spacing)

**Testing:**
29. Unit tests for Insights ViewModel aggregating data from multiple repositories
30. Integration test: Create action items and decisions in multiple conversations, verify they appear in Insights
31. UI test: Navigate through all Insights sections, verify interactions work
32. Regression test: Main messaging functionality unaffected by Insights tab

## Story 4.4: Cross-Conversation AI Context

As a **developer**,  
I want **AI features to access context across multiple conversations**,  
so that **Insights dashboard can provide intelligent aggregation and suggestions**.

### Acceptance Criteria

**Architecture:**
1. Cloud Function created: `aggregateInsights` accepting userId
2. Function queries all user's conversations and AI-generated content
3. Aggregation logic:
   - Collect all priority messages from last 7 days
   - Collect all uncompleted action items
   - Collect all decisions from last 30 days
4. Function returns structured data for Insights dashboard
5. Caching: Aggregated insights cached for 15 minutes per user

**Smart Aggregation:**
6. Duplicate detection: Similar action items across conversations merged (e.g., "Deploy app" in two chats → one aggregated item)
7. Priority ranking: Most urgent/important items bubble to top
8. Relationship detection: Link related decisions and action items (e.g., decision "Use Firebase" → action item "Set up Firebase")

**Performance:**
9. Aggregation completes < 3 seconds for user with 20 conversations
10. Incremental updates: Only refresh changed conversations, not all data
11. Background refresh: Insights updated automatically every 30 minutes when app active

**Privacy & Security:**
12. Aggregation respects conversation permissions (user must be participant)
13. No cross-user data leakage (strict user ID filtering)
14. Cloud Function validates user authentication before returning data

**Testing:**
15. Unit tests for aggregation logic (mocked conversation data)
16. Integration test: User with 5 conversations, create action items in 3, verify aggregated view correct
17. Security test: Attempt to access another user's insights, verify denied
18. Performance test: User with 50 conversations, verify aggregation completes within time limit

## Story 4.5: AI Feature Discoverability & Onboarding

As a **user**,  
I want **to understand what AI features are available and how to use them**,  
so that **I don't miss valuable functionality**.

### Acceptance Criteria

**First-Time Onboarding:**
1. After completing Epic 2 MVP, first app launch shows AI onboarding
2. 3-screen carousel explaining AI features:
   - Screen 1: "Intelligent Insights - Your AI assistant helps you stay organized"
   - Screen 2: "In-Chat AI - Summarize, extract tasks, and search with natural language"
   - Screen 3: "Insights Dashboard - See everything important in one place"
3. "Got it" button dismisses onboarding, sets flag to not show again
4. "Skip" option for power users

**In-App Discovery:**
5. AI button in chat has tooltip on first tap: "Tap for AI-powered features"
6. Empty Insights dashboard includes "How it works" explainer section
7. Settings includes "AI Features" section with toggles and explanations
8. Help/FAQ section documents all AI features with examples

**Visual Cues:**
9. AI-generated content visually distinct (subtle sparkle icon or badge)
10. First time AI feature used, show confirmation: "✓ Summary generated. Find it anytime in Insights."
11. Priority messages include first-time explanation: "This message may need your attention. Long-press to see why."

**Performance:**
12. Onboarding screens lightweight (< 500KB total assets)
13. Onboarding dismissible at any time (no forced completion)

**Testing:**
14. UI test: Complete onboarding flow, verify doesn't show again
15. Usability test: 2 new users try AI features without instruction, note confusion points
16. Regression test: Onboarding doesn't interfere with core messaging

## Story 4.6: Epic 4 Regression Testing & AI Feature Validation

As a **QA engineer**,  
I want **comprehensive validation that all 5 required AI features work correctly together**,  
so that **the app is ready for Gauntlet evaluation with complete AI functionality**.

### Acceptance Criteria

1. **All 5 Required AI Features Validated:**
   - ✅ Thread Summarization: Working, quality acceptable
   - ✅ Action Item Extraction: Working, 80%+ detection rate
   - ✅ Smart Search: Working, natural language queries return relevant results
   - ✅ Priority Message Detection: Working, < 20% false positive rate
   - ✅ Decision Tracking: Working, manual and AI-assisted modes functional

2. **Insights Dashboard Integration Tested:**
   - Action items from multiple conversations appear correctly
   - Priority messages aggregated properly
   - Decisions searchable and filterable
   - Navigation from Insights to source messages works

3. **End-to-End Scenario Testing:**
   - Scenario 1: Team discussion → AI detects decision → Appears in Insights → User finds it via search
   - Scenario 2: User receives priority message → Gets push notification → Opens app → Sees in Insights → Responds
   - Scenario 3: Action items assigned in group chat → Extracted by AI → Marked complete in Insights → Status syncs across devices

4. **Performance Benchmarks Maintained:**
   - Message send still < 2 seconds (core messaging not degraded)
   - App launch still < 1 second
   - Insights dashboard loads < 2 seconds
   - All AI features respond within documented time limits

5. **Regression Test Suite Passed:**
   - All Epic 1 & 2 tests still pass
   - All Epic 3 tests still pass
   - No new crashes or critical bugs introduced

6. **TestFlight Deployment #2:**
   - Build deployed with all AI features
   - Beta testers validate AI features work as expected
   - Feedback collected and documented

7. **Gauntlet Evaluation Readiness:**
   - Demo script created showing all 5 required AI features
   - Can demonstrate each feature in < 2 minutes
   - Known issues list: Any non-critical bugs documented
   - App meets all Gauntlet MVP + AI requirements

---
