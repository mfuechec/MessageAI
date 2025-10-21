# Epic 2: Scope & Implementation Roadmap

**Epic Goal:** Complete MVP with Reliability  
**Timeline:** 1.5 days (estimated)  
**Total Stories:** 15 (2.0 through 2.12, with 2.11 split into 2.11a/b/c)  
**Status:** In Progress (3/15 stories completed)  
**Completed:** Story 2.0 ✅, Story 2.1 ✅, Story 2.2 ✅

---

## Epic 2 Overview

### What We're Building

Epic 2 transforms the basic messaging foundation from Epic 1 into a **production-ready MVP** with:

- ✅ Conversation creation (one-on-one & group)
- ✅ Advanced message features (edit, unsend, retry)
- ✅ Real-time indicators (read receipts, typing)
- ✅ Rich media (images, PDFs)
- ✅ Offline resilience (queue management)
- ✅ Push notifications
- ✅ Performance optimization
- ✅ Comprehensive testing

### What's Already Done (Epic 1)

- ✅ Authentication & profile setup
- ✅ Basic one-on-one chat view (MessageKit)
- ✅ Real-time messaging
- ✅ Offline persistence
- ✅ 94 unit tests passing
- ✅ Firebase Emulator setup complete

---

## Story Breakdown & Dependencies

### Phase 1: Foundation (Stories 2.0-2.1)
**Goal:** Enable users to start conversations

#### Story 2.0: Start New Conversation ⭐ **CRITICAL PATH** ✅ **DONE**
- **Complexity:** Medium
- **Estimated Time:** 3-4 hours
- **Dependencies:** None (blocks all other stories)
- **Key Deliverables:**
  - "New Message" button in conversations list
  - User selection view with search
  - `getOrCreateConversation()` repository method
  - Duplicate prevention logic
  - Race condition handling
- **Why Critical:** Without this, users can't create conversations (currently only test data exists)
- **Risks:** Firestore query performance with large user bases

#### Story 2.1: Group Chat Functionality ✅ **DONE**
- **Complexity:** Medium-High
- **Estimated Time:** 4-5 hours
- **Dependencies:** Story 2.0 (extends user selection for multi-select)
- **Key Deliverables:**
  - Multi-select user picker
  - Group avatar UI (2×2 grid layout)
  - Group message display (show sender names)
  - `GroupAvatarView` component
- **Risks:** MessageKit customization for group display

---

### Phase 2: Message Management (Stories 2.3-2.5)
**Goal:** Advanced message operations

#### Story 2.2: Message Editing with History ✅ **DONE**
- **Complexity:** Medium
- **Actual Time:** ~3 hours
- **Dependencies:** None (extends existing chat)
- **Key Deliverables:**
  - ✅ Tap-to-edit interaction (faster than long-press)
  - ✅ Edit mode UI with validation
  - ✅ `editHistory` array in Message entity
  - ✅ Edit history viewer modal
  - ✅ Real-time edit sync with optimistic UI
  - ✅ 12 unit tests added
- **Performance Note:** Identified caching issue (see Story 2.11)

#### Story 2.3: Message Unsend (Delete for Everyone)
- **Complexity:** Low-Medium
- **Estimated Time:** 2-3 hours
- **Dependencies:** None
- **Key Deliverables:**
  - Unsend action (24-hour limit)
  - Confirmation alert
  - "[Message deleted]" placeholder
  - Real-time deletion sync
- **Risks:** Privacy compliance (ensure data actually deleted)

#### Story 2.4: Message Send Retry on Failure
- **Complexity:** Medium
- **Estimated Time:** 3-4 hours
- **Dependencies:** None
- **Key Deliverables:**
  - Failed message UI (red warning icon)
  - Retry/Delete alert
  - Persistent failure queue
  - Network error handling
- **Risks:** Edge cases with offline queue interaction

---

### Phase 3: Real-Time Indicators (Stories 2.6-2.7)
**Goal:** Enhanced communication feedback

#### Story 2.5: Read Receipts
- **Complexity:** Medium
- **Estimated Time:** 3-4 hours
- **Dependencies:** None
- **Key Deliverables:**
  - Read status tracking (`readBy` array)
  - Checkmark indicators (✓ sent, ✓✓ delivered, ✓✓ read)
  - Group read count ("Read by 2 of 3")
  - `markMessagesAsRead()` repository method
- **Risks:** Performance with large message volumes

#### Story 2.6: Typing Indicators
- **Complexity:** Medium
- **Estimated Time:** 2-3 hours
- **Dependencies:** None
- **Key Deliverables:**
  - Typing state tracking (Firestore ephemeral data)
  - "[Name] is typing..." UI
  - 3-second inactivity timeout
  - Throttled updates (max 1/second)
- **Risks:** Firestore write cost (need throttling)

---

### Phase 4: Rich Media (Stories 2.8-2.9)
**Goal:** Support image and document sharing

#### Story 2.8: Image Attachments
- **Complexity:** High
- **Estimated Time:** 5-6 hours
- **Dependencies:** None
- **Key Deliverables:**
  - Photo library picker
  - Firebase Storage upload
  - Image compression (max 2MB)
  - MessageKit image message display
  - Full-screen image viewer
  - Progress indicators
  - Storage security rules
- **Risks:** 
  - Storage quota management
  - Image compression quality
  - Offline upload queue complexity

#### Story 2.8: Document Attachments (PDF)
- **Complexity:** Medium
- **Estimated Time:** 3-4 hours
- **Dependencies:** Story 2.7 (shares upload infrastructure)
- **Key Deliverables:**
  - Document picker (UIDocumentPickerViewController)
  - PDF upload (10MB limit)
  - Document card UI (file icon, name, size)
  - QuickLook viewer integration
  - File size validation
- **Risks:** Large file handling, mime type validation

---

### Phase 5: Offline & Notifications (Stories 2.10-2.11)
**Goal:** Production-grade reliability

#### Story 2.9: Offline Message Queue with Manual Send
- **Complexity:** Medium-High
- **Estimated Time:** 4-5 hours
- **Dependencies:** None (enhances existing offline behavior)
- **Key Deliverables:**
  - Queued message UI ("Queued" status)
  - Persistent offline banner
  - Connectivity toast ("Auto-send? [Yes] [Review First]")
  - Offline Queue view (review, edit, delete)
  - Sequential send logic
- **Risks:** Queue synchronization complexity

#### Story 2.11: Push Notifications
- **Complexity:** High
- **Estimated Time:** 6-8 hours
- **Dependencies:** None (but benefits from all previous stories)
- **Key Deliverables:**
  - APNs certificate setup
  - FCM token registration
  - Cloud Function (Firestore trigger)
  - Foreground/background notifications
  - Deep linking to conversations
  - Badge count management
- **Risks:** 
  - Cloud Function deployment
  - APNs certificate configuration
  - Notification permission flow
- **External Dependency:** Requires Firebase Cloud Functions setup

---

### Phase 6: Performance & Testing (Stories 2.11a/b/c-2.12)
**Goal:** Production-ready quality

#### Story 2.11a: Message & Conversation Pagination
- **Complexity:** Medium
- **Estimated Time:** 2-3 hours
- **Dependencies:** All previous stories (optimizes query performance)
- **Key Deliverables:**
  - Message pagination (50 most recent, load older on scroll)
  - Conversation list pagination
  - Firestore composite indexes
  - Load testing (1000 message conversation)
- **Risks:** Performance regressions from new features

#### Story 2.11b: Caching Layer (User & ChatViewModel)
- **Complexity:** Medium
- **Estimated Time:** 2-3 hours
- **Dependencies:** Story 2.11a (pagination complete)
- **Key Deliverables:**
  - User cache with staleness detection (fixes 50+ redundant reads)
  - ChatViewModel lifecycle management & caching
  - Preserve scroll position & draft state across conversation re-opens
  - Memory-efficient cache eviction (LRU, 100 users max)
- **Risks:** Memory leaks if cache not properly managed
- **Known Issue:** ConversationsListViewModel refetches all participants on every update (discovered in Story 2.2)
- **New Enhancement:** ChatContext pattern needs ViewModel caching to preserve state

#### Story 2.11c: Network Resilience & Performance Profiling
- **Complexity:** Medium
- **Estimated Time:** 2-3 hours
- **Dependencies:** Stories 2.11a, 2.11b (full app optimized)
- **Key Deliverables:**
  - Exponential backoff for failed operations
  - Network quality detection & adaptive behavior
  - Memory profiling (< 150MB RAM target)
  - Timestamp auto-updates (conversation list updates every 60s)
  - Performance regression testing suite
- **Risks:** Profiling may reveal unexpected bottlenecks

#### Story 2.12: Comprehensive Reliability Testing & Regression Suite
- **Complexity:** Medium
- **Estimated Time:** 4-6 hours
- **Dependencies:** All previous stories (tests everything)
- **Key Deliverables:**
  - 10 reliability test scenarios
  - Regression test suite
  - TestFlight deployment
  - Beta testing with 2+ testers
  - MVP checkpoint validation
- **External Dependency:** TestFlight access, beta testers

---

## Implementation Sequence

### Recommended Order

**Week 1: Core Features (Days 1-3)**

1. **Story 2.0** ⭐ (Start New Conversation) - **MUST DO FIRST**
2. **Story 2.1** (Group Chat)
3. **Story 2.2** (Message Editing)
4. **Story 2.3** (Message Unsend)
5. **Story 2.4** (Message Retry)

**Week 2: Enhancements (Days 4-6)**

6. **Story 2.5** (Read Receipts)
7. **Story 2.6** (Typing Indicators)
8. **Story 2.7** (Image Attachments)
9. **Story 2.8** (PDF Attachments)

**Week 3: Production-Ready (Days 7-9)**

10. **Story 2.9** (Offline Queue)
11. **Story 2.10** (Push Notifications) ⚠️ *Complex, allow extra time*
12. **Story 2.11a** (Message & Conversation Pagination)
13. **Story 2.11b** (Caching Layer - User & ChatViewModel)
14. **Story 2.11c** (Network Resilience & Performance Profiling)
15. **Story 2.12** (Testing & Deployment)

### Parallel Implementation Opportunities

Stories that can be implemented simultaneously (no dependencies):

- **Parallel Set 1:** Stories 2.2, 2.3, 2.4 (message operations)
- **Parallel Set 2:** Stories 2.5, 2.6 (real-time indicators)
- **Parallel Set 3:** Stories 2.11a, 2.11b (pagination & caching can be done simultaneously)
- **Sequential:** 
  - Story 2.7 must complete before 2.8 (shared infrastructure)
  - Story 2.11c must wait for 2.11a & 2.11b (profiling needs full optimizations in place)

---

## Complexity & Time Estimates

### Story Complexity Matrix

| Story | Complexity | Est. Time | Risk Level |
|-------|-----------|-----------|------------|
| 2.0 | Medium | 3-4h | Medium (query performance) |
| 2.1 | Medium-High | 4-5h | Medium (MessageKit customization) |
| 2.2 | Medium | 3h | Low (completed) |
| 2.3 | Low-Medium | 2-3h | Low |
| 2.4 | Medium | 3-4h | Medium (offline queue interaction) |
| 2.5 | Medium | 3-4h | Low |
| 2.6 | Medium | 2-3h | Low |
| 2.7 | High | 5-6h | High (storage, compression, offline) |
| 2.8 | Medium | 3-4h | Low (builds on 2.7) |
| 2.9 | Medium-High | 4-5h | Medium (sync complexity) |
| 2.10 | High | 6-8h | High (external dependencies) |
| 2.11a | Medium | 2-3h | Medium (pagination complexity) |
| 2.11b | Medium | 2-3h | Medium (cache management) |
| 2.11c | Medium | 2-3h | Low (profiling & monitoring) |
| 2.12 | Medium | 4-6h | Low (mostly testing) |

**Total Estimated Time:** 48-63 hours

### Realistic Timeline

- **Best Case:** 6 work days (8 hours/day)
- **Expected Case:** 8-9 work days (with breaks, debugging)
- **Worst Case:** 11 work days (if blockers or external dependencies delay)

**Note:** Original PRD estimate of "1.5 days" is unrealistic for 15 comprehensive stories with 200+ acceptance criteria.

---

## Technical Dependencies

### Internal (MessageAI Codebase)
- ✅ **Epic 1 Complete** - All foundation stories done
- ✅ **Firebase Emulator** - Set up and tested
- ✅ **MessageKit** - Integrated in Story 1.8
- ⚠️ **Story 2.0** - Blocks Stories 2.1+ (conversation creation)

### External (Third-Party Services)
- ⚠️ **Firebase Cloud Functions** - Required for Story 2.11 (push notifications)
- ⚠️ **APNs Certificate** - Required for Story 2.11
- ⚠️ **TestFlight Access** - Required for Story 2.12
- ⚠️ **Beta Testers** - Required for Story 2.12

### Infrastructure
- ⚠️ **Firebase Storage** - Required for Stories 2.7, 2.8
- ⚠️ **Firestore Indexes** - Required for Story 2.11 (performance)

---

## Risk Assessment

### High-Risk Stories

#### Story 2.10: Push Notifications
- **Risk:** Cloud Function deployment complexity
- **Mitigation:** Allocate extra time, test thoroughly with emulator
- **Impact if delayed:** MVP can function without push (but degrades UX)

#### Story 2.7: Image Attachments
- **Risk:** Storage quota management, offline upload complexity
- **Mitigation:** Implement compression, clear user feedback
- **Impact if delayed:** Blocks Story 2.8 (PDFs share infrastructure)

### Medium-Risk Stories

#### Story 2.0: Start New Conversation
- **Risk:** Firestore query performance with large user base
- **Mitigation:** Implement pagination in user selection, proper indexing
- **Impact if delayed:** Blocks entire Epic 2 (critical path)

#### Story 2.9: Offline Queue
- **Risk:** Synchronization complexity, edge cases
- **Mitigation:** Comprehensive unit tests, clear queue state management
- **Impact if delayed:** Degrades offline experience

---

## Success Metrics

### Technical Metrics
- ✅ Zero message loss (even under adverse network conditions)
- ✅ Message send latency < 2 seconds (online)
- ✅ App launch time < 1 second
- ✅ Memory usage < 150MB RAM
- ✅ 70%+ code coverage maintained

### Feature Completion
- ✅ All 13 stories implemented
- ✅ 10 reliability scenarios pass
- ✅ Regression tests pass
- ✅ TestFlight build deployed
- ✅ 2+ beta testers validate

### Quality Gates
- ✅ No critical bugs
- ✅ All acceptance criteria met
- ✅ Performance benchmarks achieved
- ✅ Accessibility compliance (WCAG AA)

---

## Blockers & Prerequisites

### Before Starting Epic 2
- ✅ **Epic 1 Complete** - Done (Stories 1.1-1.10)
- ✅ **94 Unit Tests Passing** - Verified
- ✅ **Firebase Emulator Working** - Tested
- ⚠️ **Cloud Functions Setup** - Not yet done (needed for Story 2.10)
- ⚠️ **APNs Certificate** - Not yet done (needed for Story 2.10)

### Story-Specific Blockers
- **Story 2.8** - Blocked by Story 2.7 (shared upload infrastructure)
- **Story 2.10** - Blocked by Cloud Functions deployment
- **Story 2.12** - Blocked by TestFlight access

---

## Next Steps

### Immediate Actions

1. **Review & Approve Scope** ← *You are here*
   - Validate story sequence
   - Confirm timeline expectations
   - Identify any missing features

2. **Prepare External Dependencies**
   - Set up Firebase Cloud Functions project
   - Generate APNs certificate
   - Configure TestFlight access

3. **Draft Story 2.0** ← *Next SM task*
   - Create detailed story document
   - Include full code examples
   - Specify all acceptance criteria
   - Run validation checklist

4. **Begin Development**
   - Dev Agent implements Story 2.0
   - QA validates against acceptance criteria
   - Iterate until story complete

### Questions to Resolve

1. **Timeline:** Is 7-8 days realistic for your schedule?
2. **Priorities:** Any stories you want to defer to post-MVP?
3. **Cloud Functions:** Do you have access to set up Firebase Cloud Functions?
4. **TestFlight:** Do you have Apple Developer Program membership?

---

## Recommended Approach

### Option 1: Sequential (Safest)
Implement stories 2.0 → 2.12 in order. Ensures no missed dependencies.

**Pros:** Clear path, no confusion, lower risk  
**Cons:** Slower overall progress

### Option 2: Phased (Balanced) ⭐ **RECOMMENDED**
Implement in phases (Foundation → Enhancements → Production).

**Pros:** Logical grouping, allows parallelization, clear milestones  
**Cons:** Requires careful dependency management

### Option 3: Priority-Driven (Aggressive)
Implement highest-value stories first, defer lower-priority.

**Pros:** Fastest path to usable MVP  
**Cons:** May skip important reliability features

---

## Summary

Epic 2 is **ambitious but achievable** with:
- 15 well-defined stories (including 2.11a/b/c split for manageability)
- Clear dependencies mapped
- Realistic 8-9 day timeline
- Comprehensive testing plan
- Production-ready quality standards

**Critical Path:** Story 2.0 must be completed first (blocks all conversation-related features).

**High-Risk Items:** Push notifications (Story 2.10) requires external setup and extra time.

**Performance Stories Split:** Story 2.11 split into three focused stories (pagination, caching, profiling) for better dev handoffs and testability.

**Ready to proceed?** Let me know if you want to:
1. Start drafting Story 2.0
2. Adjust the scope/sequence
3. Discuss external dependencies
4. Review any specific stories in detail


