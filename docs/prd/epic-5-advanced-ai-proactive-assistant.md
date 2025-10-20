# Epic 5: Advanced AI - Proactive Assistant

## Epic 5 Goal

Build the proactive scheduling assistant that detects coordination needs, auto-suggests meeting times, and delivers AI-summarized push notifications. This completes the advanced AI capability requirement for Gauntlet. Minimum viable scope defined with stretch goals for additional intelligence. Expected timeline: 1 day + buffer (Day 7 flex time).

## Story 5.1: Push Notification AI Summaries

As a **user**,  
I want **push notifications that summarize conversation activity since I last opened the app**,  
so that **I get context before diving into messages**.

### Acceptance Criteria

**Notification Content:**
1. Push notification includes AI-generated summary when user has 3+ unread messages in a conversation
2. Summary format: "[Count] new messages from [Conversation]: [Key points]. [Direct questions to user]"
3. Example: "5 messages from Design Team: Sarah shared wireframes, Mike approved v2, action item assigned to you"
4. Long conversations (10+ messages) condensed to 2-3 key points max
5. Direct questions to user always highlighted if present

**Implementation:**
6. Cloud Function `generatePushSummary` triggered when sending push notification (from Story 2.9)
7. Function retrieves messages since user's last app open (tracked in Firestore)
8. LLM prompt: "Summarize these [N] team messages in 20 words or less, highlighting decisions and questions for [User Name]"
9. Summary embedded in push notification payload
10. Fallback: If summary generation fails, send standard push with message preview

**Performance:**
11. Summary generation doesn't delay push delivery (async process with fallback)
12. Summary generated within 3 seconds or fallback triggered
13. User's last-seen timestamp updated reliably when app opened

**Quality Acceptance Criteria:**
14. Summaries are accurate (no hallucinations)
15. Direct questions to user are included 90% of the time
16. Summaries don't exceed notification character limits (iOS: ~150 chars)
17. Manual validation: 10 test scenarios, verify summaries useful and accurate

**Testing:**
18. Integration test: User receives 5 messages while app closed, verify push includes summary
19. Integration test: Summary generation fails, verify fallback push still delivered
20. Regression test: Non-AI push notifications still work

## Story 5.2: Scheduling Need Detection

As a **user**,  
I want **AI to detect when my team is trying to schedule a meeting**,  
so that **I can get proactive coordination assistance**.

### Acceptance Criteria

**Detection Signals:**
1. Cloud Function `detectSchedulingNeeds` analyzes messages for scheduling language:
   - "Let's meet", "Can we schedule", "When are you free"
   - Time/date mentions: "tomorrow", "next week", "Friday at 2pm"
   - Availability questions: "What's your availability?", "When works for you?"
2. Function triggered on message write, runs asynchronously
3. Detection result stored: `schedulingDetected: true, participants: [], context: string`

**In-App Notification:**
4. When scheduling detected, show in-app banner: "Looks like you're scheduling a meeting. [Get AI Help]"
5. Banner appears in conversation view, dismissible
6. Tap "Get AI Help" opens proactive assistant interface

**Proactive Suggestions Section (Insights Dashboard):**
7. Detected scheduling needs appear in "Proactive Suggestions" section of Insights tab
8. Card shows: conversation, participants, scheduling context, "[Help Schedule]" button
9. Tap card or button opens proactive assistant for that conversation

**Quality Acceptance Criteria:**
10. Detects explicit scheduling: "Let's meet Friday" → Detected
11. Detects implicit scheduling: "We need to sync on this" → Detected
12. Doesn't over-detect: "I'll meet you at the coffee shop" (social) → Not detected
13. Manual validation: 8/10 scheduling conversations detected
14. False positive rate < 15%

**Performance:**
15. Detection completes within 3 seconds of message
16. Doesn't impact message delivery

**Testing:**
17. Unit tests for scheduling detection logic
18. Integration test: Send scheduling message, verify detection and banner appear
19. Integration test: Non-scheduling message, verify no false detection

## Story 5.3: Meeting Time Suggestions

As a **user**,  
I want **AI to suggest meeting times based on conversation context**,  
so that **scheduling becomes faster and easier**.

### Acceptance Criteria

**Proactive Assistant Interface:**
1. When user taps "Get AI Help" from scheduling detection, open modal: "Schedule Meeting Assistant"
2. Modal shows:
   - Detected participants from conversation
   - Add/remove participants option
   - "Generate Time Suggestions" button
3. Tap "Generate Time Suggestions" calls Cloud Function

**AI Suggestion Logic:**
6. Cloud Function `suggestMeetingTimes` accepts participants and conversation context
7. LLM analyzes conversation for:
   - Mentioned time constraints ("not mornings", "afternoons only")
   - Mentioned dates/ranges ("next week", "before Friday")
   - Timezone hints if present
8. Function suggests 3-5 meeting time options with rationale
9. Suggestions formatted: "Tomorrow at 2pm ET - [Rationale]"
10. Rationale examples: "Avoids morning conflicts mentioned", "Within requested timeframe"

**Minimum Viable Scope:**
11. MVP: Suggestions based on conversation analysis only (no calendar integration)
12. Suggestions are **recommendations**, not definitive availability
13. User can copy suggestions and paste into conversation manually

**Stretch Goals (Optional, Day 7):**
14. (Stretch) Calendar integration: Check user's actual availability
15. (Stretch) Send poll to participants with suggested times
16. (Stretch) Automatically book meeting when participants agree

**Quality Acceptance Criteria:**
17. Suggestions are relevant to conversation context
18. Suggestions respect mentioned constraints 80% of the time
19. Suggestions are realistic (not suggesting "3am" unless context indicates)
20. Manual validation: 5 test scenarios, verify suggestions reasonable

**Performance:**
21. Suggestion generation < 8 seconds
22. Cached for conversation (regenerate on request)

**Testing:**
23. Unit tests for suggestion logic
24. Integration test: Request suggestions, verify they match conversation constraints
25. Regression test: All previous AI features still functional

## Story 5.4: Proactive Assistant UX Polish

As a **user**,  
I want **the proactive assistant to feel helpful, not intrusive**,  
so that **I actually use it instead of ignoring it**.

### Acceptance Criteria

**Discoverability:**
1. First time scheduling detected, show explainer tooltip: "AI can help coordinate meetings. Tap to try it."
2. Proactive Suggestions section in Insights has description: "AI detects when you're scheduling and offers help"
3. Settings toggle: "Proactive Scheduling Assistance" (on by default)

**Non-Intrusive Design:**
4. In-conversation banner is small, at bottom of screen (not blocking messages)
5. Banner auto-dismisses after 30 seconds if not interacted with
6. User can permanently dismiss: "Don't suggest for this conversation"
7. Suggestions section in Insights doesn't show old/irrelevant scheduling (auto-expire after 7 days)

**Feedback Loop:**
8. After user schedules meeting (detected by follow-up messages), ask: "Did AI suggestions help? 👍 👎"
9. Feedback stored for future improvement
10. Negative feedback reduces suggestion frequency for that user

**Visual Design:**
11. Proactive assistant uses distinct color/icon (different from other AI features)
12. Suggestion cards visually appealing, easy to read
13. Dark mode styling applied

**Testing:**
14. Usability test: 2 users try proactive assistant, note if it feels helpful or annoying
15. UI test: Verify all interactions (banner, modal, suggestions) work smoothly
16. Regression test: Doesn't interfere with core messaging

## Story 5.5: Epic 5 Final Testing & Project Completion

As a **QA engineer**,  
I want **final validation that the complete app meets all Gauntlet requirements**,  
so that **the project is ready for submission and evaluation**.

### Acceptance Criteria

1. **Advanced AI Feature Validated:**
   - ✅ Proactive Assistant: Working, detects scheduling needs, suggests times
   - ✅ Push notification summaries: Working, provide useful context
   - ✅ Minimum viable scope met (no calendar integration required)

2. **Complete Feature Set Validation:**
   - All MVP messaging features (Epic 1 & 2)
   - All 5 required AI features (Epic 3 & 4)
   - 1 advanced AI capability (Epic 5)
   - Insights dashboard aggregating everything

3. **End-to-End Final Scenarios:**
   - Scenario 1: Full day of team communication → AI summaries in push → Open app → Insights shows all important items → Use proactive assistant to schedule follow-up
   - Scenario 2: New user onboarding → Try all features → Successful without confusion
   - Scenario 3: Stress test → 100 messages across 10 conversations → All AI features remain performant

4. **Performance & Reliability Final Check:**
   - App launch < 1 second
   - Message send < 2 seconds
   - All AI features respond within documented limits
   - Zero message loss in stress testing
   - No crashes in 1 hour continuous use

5. **TestFlight Deployment #3 (Final):**
   - Complete build deployed
   - 3+ external testers validate full feature set
   - Demo-ready for Gauntlet evaluation
   - Beta feedback addressed or documented as known limitations

6. **Gauntlet Submission Readiness:**
   - **Complete Feature Checklist:**
     - ✅ One-on-one chat
     - ✅ Real-time delivery
     - ✅ Message persistence
     - ✅ Optimistic UI
     - ✅ Online/offline status
     - ✅ Timestamps
     - ✅ User authentication
     - ✅ Group chat
     - ✅ Read receipts
     - ✅ Push notifications
     - ✅ Image attachments
     - ✅ Message editing, unsend, retry
     - ✅ Offline queue with manual send
     - ✅ Thread summarization (AI)
     - ✅ Action item extraction (AI)
     - ✅ Smart search (AI)
     - ✅ Priority detection (AI)
     - ✅ Decision tracking (AI)
     - ✅ Proactive assistant (Advanced AI)

7. **Documentation Package:**
   - README with setup instructions
   - Architecture documentation
   - API key setup guide
   - Known limitations documented
   - Demo script for evaluators
   - Video demo recorded (optional but recommended)

8. **Code Quality:**
   - 70%+ test coverage maintained
   - No critical linter errors
   - Clean Architecture maintained throughout
   - Code comments where necessary

9. **Success Metrics Achieved:**
   - Zero message loss validated
   - Real-time delivery working
   - All AI features meeting quality acceptance criteria
   - App stable and performant

---

**Epic 5 Complete!**

At the end of this epic, you have:
- ✅ Complete MessageAI app with all Gauntlet requirements
- ✅ Production-quality messaging infrastructure
- ✅ 5 required AI features fully functional
- ✅ 1 advanced AI capability (proactive assistant)
- ✅ Comprehensive testing and validation
- ✅ Ready for Gauntlet submission and evaluation

**🎉 Project Complete! 🎉**

---
