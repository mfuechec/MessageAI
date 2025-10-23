# Regression Test Suite - MessageAI MVP

**Version:** 1.0
**Last Updated:** 2025-10-22
**Coverage Target:** 70%+ overall (Domain: 80%, Data: 70%, Presentation: 75%)

---

## Overview

This document provides a comprehensive mapping of all Epic 1 and Epic 2 features to their corresponding automated and manual tests. Use this as a checklist to validate that no regressions have been introduced during development.

---

## Test Execution Quick Reference

### Automated Tests

```bash
# Full test suite (1-2 minutes)
./scripts/quick-test.sh

# Epic 1 tests only (20-40 seconds)
./scripts/test-epic.sh 1

# Epic 2 tests only (20-40 seconds)
./scripts/test-epic.sh 2

# Specific test class (5-20 seconds)
./scripts/test-story.sh <TestClassName>

# Integration tests (requires emulator, 2-5 minutes)
./scripts/start-emulator.sh
./scripts/quick-test.sh --with-integration

# Performance tests
./scripts/quick-test.sh --test PerformanceBaselineTests
```

### Manual Tests

Manual smoke testing checklist provided in Section 4 below.

---

## Epic 1: Core Messaging (Stories 1.0-1.9)

### Feature 1.0: User Authentication

**Story:** Users can sign up, sign in, and sign out with email/password

**Test Coverage:**

| Test File | Test Class | Test Count | Key Tests |
|-----------|------------|------------|-----------|
| `Presentation/ViewModels/AuthViewModelTests.swift` | `AuthViewModelTests` | 8 tests | `testSignIn_Success`, `testSignIn_InvalidEmail`, `testSignUp_Success`, `testSignUp_WeakPassword`, `testSignOut_Success` |
| `Data/Repositories/FirebaseAuthRepositoryTests.swift` | `FirebaseAuthRepositoryTests` | 6 tests | Integration tests for Firebase Auth SDK |

**Execution Command:**
```bash
./scripts/test-story.sh AuthViewModelTests
```

**Manual Test:**
- [ ] Sign up with new email/password
- [ ] Sign in with existing credentials
- [ ] Sign out from authenticated session
- [ ] Verify error handling (invalid email, weak password, duplicate account)

---

### Feature 1.1: Profile Management

**Story:** Users can set up and edit their display name and profile picture

**Test Coverage:**

| Test File | Test Class | Test Count | Key Tests |
|-----------|------------|------------|-----------|
| `Presentation/ViewModels/ProfileSetupViewModelTests.swift` | `ProfileSetupViewModelTests` | 5 tests | `testUpdateDisplayName_Success`, `testUpdateProfile_EmptyName`, `testProfileImageUpload` |
| `Data/Repositories/FirebaseUserRepositoryTests.swift` | `FirebaseUserRepositoryTests` | 7 tests | Integration tests for user profile updates |

**Execution Command:**
```bash
./scripts/test-story.sh ProfileSetupViewModelTests
```

**Manual Test:**
- [ ] Set display name during profile setup
- [ ] Upload profile picture
- [ ] Edit existing profile
- [ ] Verify changes reflected across conversations

---

### Feature 1.2: One-on-One Messaging

**Story:** Users can send and receive real-time messages in one-on-one conversations

**Test Coverage:**

| Test File | Test Class | Test Count | Key Tests |
|-----------|------------|------------|-----------|
| `Presentation/ViewModels/ChatViewModelTests.swift` | `ChatViewModelTests` | 20+ tests | `testSendMessage_Success`, `testReceiveMessage_RealTime`, `testOptimisticUI_MessageAppears` |
| `Data/Repositories/FirebaseMessageRepositoryTests.swift` | `FirebaseMessageRepositoryTests` | 12 tests | Integration tests for message CRUD operations |
| `Integration/RealTimeMessagingIntegrationTests.swift` | `RealTimeMessagingIntegrationTests` | 8 tests | End-to-end real-time messaging scenarios |

**Execution Command:**
```bash
./scripts/test-story.sh ChatViewModelTests
./scripts/test-story.sh FirebaseMessageRepositoryTests  # Requires emulator
```

**Manual Test:**
- [ ] Send message to another user
- [ ] Receive message in real-time (< 2 seconds)
- [ ] Verify optimistic UI (message appears immediately)
- [ ] Test offline behavior (message queues and sends on reconnect)

---

### Feature 1.3: Conversation List

**Story:** Users can view all their conversations with last message preview

**Test Coverage:**

| Test File | Test Class | Test Count | Key Tests |
|-----------|------------|------------|-----------|
| `Presentation/ViewModels/ConversationsListViewModelTests.swift` | `ConversationsListViewModelTests` | 12 tests | `testLoadConversations_Success`, `testRealTimeUpdates`, `testUnreadCounts` |
| `Data/Repositories/FirebaseConversationRepositoryTests.swift` | `FirebaseConversationRepositoryTests` | 9 tests | Integration tests for conversation queries |

**Execution Command:**
```bash
./scripts/test-story.sh ConversationsListViewModelTests
```

**Manual Test:**
- [ ] View conversations list
- [ ] Verify last message preview displayed
- [ ] Verify unread counts displayed
- [ ] Verify real-time updates when new message arrives
- [ ] Verify conversation sorting (most recent first)

---

### Feature 1.4: Online Presence Indicators

**Story:** Users can see when other users are online/offline

**Test Coverage:**

| Test File | Test Class | Test Count | Key Tests |
|-----------|------------|------------|-----------|
| `Presentation/ViewModels/ConversationsListViewModelTests.swift` | `ConversationsListViewModelTests` | 3 tests | `testOnlineStatus_UpdatesRealTime`, `testLastSeenTimestamp` |
| `Data/Repositories/FirebaseUserRepositoryTests.swift` | `FirebaseUserRepositoryTests` | 4 tests | Integration tests for presence updates |

**Execution Command:**
```bash
./scripts/test-story.sh ConversationsListViewModelTests
```

**Manual Test:**
- [ ] User A goes online - verify User B sees green indicator
- [ ] User A goes offline - verify User B sees "Last seen" timestamp
- [ ] Verify presence updates in real-time

---

### Feature 1.5: Message Timestamps

**Story:** All messages display relative timestamps (e.g., "2 minutes ago")

**Test Coverage:**

| Test File | Test Class | Test Count | Key Tests |
|-----------|------------|------------|-----------|
| `Presentation/Utils/RelativeTimestampFormatterTests.swift` | `RelativeTimestampFormatterTests` | 8 tests | `testJustNow`, `testMinutesAgo`, `testHoursAgo`, `testYesterday`, `testWeekAgo` |
| `Domain/Entities/MessageTests.swift` | `MessageTests` | 3 tests | Message entity timestamp validation |

**Execution Command:**
```bash
./scripts/test-story.sh RelativeTimestampFormatterTests
```

**Manual Test:**
- [ ] Send message - verify "Just now" appears
- [ ] Wait 2 minutes - verify "2 minutes ago" appears
- [ ] Send message yesterday - verify "Yesterday" appears

---

### Feature 1.6: Offline Persistence

**Story:** App works offline with local cached data and syncs when back online

**Test Coverage:**

| Test File | Test Class | Test Count | Key Tests |
|-----------|------------|------------|-----------|
| `Integration/OfflinePersistenceIntegrationTests.swift` | `OfflinePersistenceIntegrationTests` | 6 tests | `testOfflineRead_CachedData`, `testOfflineWrite_QueuesForSync`, `testOnlineSync_Success` |
| `Data/Persistence/OfflineQueueStoreTests.swift` | `OfflineQueueStoreTests` | 7 tests | Offline queue persistence tests |

**Execution Command:**
```bash
./scripts/test-story.sh OfflinePersistenceIntegrationTests  # Requires emulator
```

**Manual Test:**
- [ ] Load app online - view conversations
- [ ] Enable airplane mode
- [ ] View cached conversations (should still display)
- [ ] Disable airplane mode - verify sync occurs

---

## Epic 2: Advanced Features (Stories 2.0-2.11)

### Feature 2.0: Duplicate Conversation Prevention

**Story:** Creating a conversation with existing participants reuses the existing conversation

**Test Coverage:**

| Test File | Test Class | Test Count | Key Tests |
|-----------|------------|------------|-----------|
| `Presentation/ViewModels/NewConversationViewModelTests.swift` | `NewConversationViewModelTests` | 9 tests | `testCreateConversation_PreventsDuplicate`, `testSearchUsers_FiltersSelf` |
| `Data/Repositories/FirebaseConversationRepositoryTests.swift` | `FirebaseConversationRepositoryTests` | 3 tests | Duplicate detection integration tests |

**Execution Command:**
```bash
./scripts/test-story.sh NewConversationViewModelTests
```

**Manual Test:**
- [ ] Create conversation with User B
- [ ] Attempt to create another conversation with User B
- [ ] Verify existing conversation is opened instead of creating duplicate

---

### Feature 2.1: Group Chat

**Story:** Users can create group conversations with 3-10 participants

**Test Coverage:**

| Test File | Test Class | Test Count | Key Tests |
|-----------|------------|------------|-----------|
| `Presentation/ViewModels/ChatViewModelTests.swift` | `ChatViewModelTests` | 5 tests | `testGroupChat_MultipleParticipants`, `testGroupChat_MessageDelivery` |
| `Data/Repositories/FirebaseConversationRepositoryTests.swift` | `FirebaseConversationRepositoryTests` | 4 tests | Group conversation CRUD tests |

**Execution Command:**
```bash
./scripts/test-story.sh ChatViewModelTests
```

**Manual Test:**
- [ ] Create group with 3 participants
- [ ] Send message in group
- [ ] Verify all participants receive message
- [ ] Verify group name displayed
- [ ] Test max 10 participants limit

---

### Feature 2.2: Message Editing

**Story:** Users can edit sent messages with edit history preserved

**Test Coverage:**

| Test File | Test Class | Test Count | Key Tests |
|-----------|------------|------------|-----------|
| `Presentation/ViewModels/ChatViewModelTests.swift` | `ChatViewModelTests` | 6 tests | `testEditMessage_Success`, `testEditMessage_UpdatesHistory`, `testEditMessage_ShowsEditedBadge` |
| `Data/Repositories/FirebaseMessageRepositoryTests.swift` | `FirebaseMessageRepositoryTests` | 3 tests | Edit operation integration tests |

**Execution Command:**
```bash
./scripts/test-story.sh ChatViewModelTests
```

**Manual Test:**
- [ ] Send message
- [ ] Edit message text
- [ ] Verify "(edited)" badge appears
- [ ] View edit history
- [ ] Verify all participants see edited version

---

### Feature 2.3: Message Unsend/Delete

**Story:** Users can unsend messages (soft delete with "Message deleted" placeholder)

**Test Coverage:**

| Test File | Test Class | Test Count | Key Tests |
|-----------|------------|------------|-----------|
| `Presentation/ViewModels/ChatViewModelTests.swift` | `ChatViewModelTests` | 4 tests | `testDeleteMessage_Success`, `testDeleteMessage_ShowsPlaceholder` |
| `Data/Repositories/FirebaseMessageRepositoryTests.swift` | `FirebaseMessageRepositoryTests` | 2 tests | Delete operation integration tests |

**Execution Command:**
```bash
./scripts/test-story.sh ChatViewModelTests
```

**Manual Test:**
- [ ] Send message
- [ ] Delete/unsend message
- [ ] Verify "Message deleted" placeholder appears
- [ ] Verify all participants see deletion

---

### Feature 2.4: Message Retry on Failure

**Story:** Failed messages can be manually retried

**Test Coverage:**

| Test File | Test Class | Test Count | Key Tests |
|-----------|------------|------------|-----------|
| `Presentation/ViewModels/ChatViewModelTests.swift` | `ChatViewModelTests` | 5 tests | `testRetryMessage_Success`, `testRetryMessage_AfterFailure` |
| `Data/Persistence/FailedMessageStoreTests.swift` | `FailedMessageStoreTests` | 6 tests | Failed message persistence tests |
| `Data/Network/NetworkRetryPolicyTests.swift` | `NetworkRetryPolicyTests` | 8 tests | Exponential backoff retry policy tests |

**Execution Command:**
```bash
./scripts/test-story.sh ChatViewModelTests
./scripts/test-story.sh FailedMessageStoreTests
./scripts/test-story.sh NetworkRetryPolicyTests
```

**Manual Test:**
- [ ] Enable airplane mode
- [ ] Send message (will fail)
- [ ] Verify red "Failed" indicator appears
- [ ] Disable airplane mode
- [ ] Tap retry button
- [ ] Verify message sends successfully

---

### Feature 2.5: Read Receipts

**Story:** Users can see when their messages have been read by recipients

**Test Coverage:**

| Test File | Test Class | Test Count | Key Tests |
|-----------|------------|------------|-----------|
| `Presentation/ViewModels/ChatViewModelTests.swift` | `ChatViewModelTests` | 7 tests | `testReadReceipts_UpdateStatus`, `testReadReceipts_MultipleUsers` |
| `Integration/RealTimeMessagingIntegrationTests.swift` | `RealTimeMessagingIntegrationTests` | 3 tests | End-to-end read receipt tests |

**Execution Command:**
```bash
./scripts/test-story.sh ChatViewModelTests
```

**Manual Test:**
- [ ] User A sends message to User B
- [ ] User B opens conversation
- [ ] User A sees "Read" status under message
- [ ] Test group chat - verify "Read by 2/3" count

---

### Feature 2.6: Typing Indicators

**Story:** Users can see when others are typing in real-time

**Test Coverage:**

| Test File | Test Class | Test Count | Key Tests |
|-----------|------------|------------|-----------|
| `Presentation/ViewModels/ChatViewModelTypingTests.swift` | `ChatViewModelTypingTests` | 9 tests | `testTypingIndicator_AppearsOnTyping`, `testTypingIndicator_DisappearsAfter3Seconds` |
| `Integration/RealTimeMessagingIntegrationTests.swift` | `RealTimeMessagingIntegrationTests` | 2 tests | End-to-end typing indicator tests |

**Execution Command:**
```bash
./scripts/test-story.sh ChatViewModelTypingTests
```

**Manual Test:**
- [ ] User A starts typing
- [ ] User B sees "User A is typing..." indicator
- [ ] User A stops typing
- [ ] Indicator disappears after 3 seconds

---

### Feature 2.7: Image Attachments

**Story:** Users can send and receive image attachments

**Test Coverage:**

| Test File | Test Class | Test Count | Key Tests |
|-----------|------------|------------|-----------|
| `Presentation/ViewModels/ChatViewModelTests.swift` | `ChatViewModelTests` | 8 tests | `testImageUpload_Success`, `testImageUpload_ExceedsMaxSize`, `testImageDownload` |
| `Presentation/ImageCompressorTests.swift` | `ImageCompressorTests` | 6 tests | Image compression tests |

**Execution Command:**
```bash
./scripts/test-story.sh ChatViewModelTests
./scripts/test-story.sh ImageCompressorTests
```

**Manual Test:**
- [ ] Select image from photo library
- [ ] Send image (verify compression for large images)
- [ ] Verify recipient receives image
- [ ] Tap to view full-size image
- [ ] Test max 10MB size limit

---

### Feature 2.8: Document Attachments (PDF)

**Story:** Users can send and receive PDF document attachments

**Test Coverage:**

| Test File | Test Class | Test Count | Key Tests |
|-----------|------------|------------|-----------|
| `Presentation/ViewModels/ChatViewModelDocumentTests.swift` | `ChatViewModelDocumentTests` | 7 tests | `testPDFUpload_Success`, `testPDFUpload_ExceedsMaxSize`, `testPDFDownload` |
| `Presentation/Utils/DocumentValidatorTests.swift` | `DocumentValidatorTests` | 5 tests | PDF validation tests |

**Execution Command:**
```bash
./scripts/test-story.sh ChatViewModelDocumentTests
./scripts/test-story.sh DocumentValidatorTests
```

**Manual Test:**
- [ ] Select PDF from files
- [ ] Send PDF
- [ ] Verify recipient receives PDF
- [ ] Tap to view PDF
- [ ] Test max 10MB size limit

---

### Feature 2.9: Offline Message Queue

**Story:** Messages composed offline are queued and sent when connection restored

**Test Coverage:**

| Test File | Test Class | Test Count | Key Tests |
|-----------|------------|------------|-----------|
| `Presentation/ViewModels/ChatViewModelOfflineQueueTests.swift` | `ChatViewModelOfflineQueueTests` | 10 tests | `testOfflineQueue_AddsMessage`, `testOfflineQueue_SendsOnReconnect` |
| `Presentation/ViewModels/OfflineQueueViewModelTests.swift` | `OfflineQueueViewModelTests` | 8 tests | Queue review and management tests |
| `Data/Persistence/OfflineQueueStoreTests.swift` | `OfflineQueueStoreTests` | 7 tests | Persistence layer tests |
| `Integration/OfflineQueueIntegrationTests.swift` | `OfflineQueueIntegrationTests` | 5 tests | End-to-end offline queue tests |
| `Performance/OfflineQueuePerformanceTests.swift` | `OfflineQueuePerformanceTests` | 3 tests | Performance validation tests |

**Execution Command:**
```bash
./scripts/test-story.sh ChatViewModelOfflineQueueTests
./scripts/test-story.sh OfflineQueueViewModelTests
./scripts/test-story.sh OfflineQueueStoreTests
```

**Manual Test:**
- [ ] Enable airplane mode
- [ ] Compose 5 messages
- [ ] Verify messages appear in offline queue
- [ ] Disable airplane mode
- [ ] Tap "Send All" or "Send Individually"
- [ ] Verify all messages send successfully

---

### Feature 2.10/2.10a: Push Notifications

**Story:** Users receive push notifications for new messages when app is backgrounded

**Test Coverage:**

| Test File | Test Class | Test Count | Key Tests |
|-----------|------------|------------|-----------|
| `App/AppStateTests.swift` | `AppStateTests` | 5 tests | App state lifecycle and notification registration tests |

**Execution Command:**
```bash
./scripts/test-story.sh AppStateTests
```

**Manual Test:**
- [ ] Background the app
- [ ] Send message from another device
- [ ] Verify push notification appears
- [ ] Tap notification - verify opens to conversation
- [ ] Test notification suppression (foreground, viewing conversation)

---

### Feature 2.11: Performance Optimization & Network Resilience

**Story:** App meets performance baselines and handles poor network gracefully

**Test Coverage:**

| Test File | Test Class | Test Count | Key Tests |
|-----------|------------|------------|-----------|
| `Performance/PerformanceBaselineTests.swift` | `PerformanceBaselineTests` | 5 tests | `testPerformance_SendMessage`, `testPerformance_LoadConversations`, `testPerformance_Authentication` |
| `Presentation/ViewModels/ChatViewModelPaginationTests.swift` | `ChatViewModelPaginationTests` | 8 tests | Pagination tests (50 messages per page) |
| `Data/Network/NetworkRetryPolicyTests.swift` | `NetworkRetryPolicyTests` | 8 tests | Exponential backoff tests |
| `Presentation/Utils/RelativeTimestampFormatterTests.swift` | `RelativeTimestampFormatterTests` | 8 tests | Efficient timestamp formatting |

**Execution Command:**
```bash
./scripts/test-story.sh PerformanceBaselineTests
./scripts/test-story.sh ChatViewModelPaginationTests
./scripts/test-story.sh NetworkRetryPolicyTests
```

**Manual Test:**
- [ ] Measure app launch time (< 1 second)
- [ ] Measure conversation load time with 50 messages (< 1 second)
- [ ] Measure message send time (< 2 seconds)
- [ ] Enable 3G simulation (Network Link Conditioner)
- [ ] Send message - verify retry logic on timeout
- [ ] Verify memory usage < 150MB with 10 conversations loaded

---

## Test Suite Summary

### Total Test Count

| Test Category | Test Files | Total Tests |
|---------------|------------|-------------|
| **Domain Entities** | 4 files | ~15 tests |
| **Data Repositories** | 4 files | ~40 tests |
| **Presentation ViewModels** | 10 files | ~90 tests |
| **Integration Tests** | 3 files | ~20 tests |
| **Performance Tests** | 2 files | ~8 tests |
| **Utilities** | 4 files | ~27 tests |
| **Total** | **27 files** | **~200 tests** |

### Execution Time

| Test Tier | Scope | Execution Time |
|-----------|-------|----------------|
| Story-level tests | Single test class | 5-20 seconds |
| Epic 1 tests | All Epic 1 features | 20-40 seconds |
| Epic 2 tests | All Epic 2 features | 20-40 seconds |
| Full suite (unit tests only) | All unit tests | 1-2 minutes |
| Full suite + integration | All tests including emulator | 2-5 minutes |

---

## Manual Smoke Testing Checklist

Use this checklist to quickly validate all features manually. Each section should take 2-5 minutes.

### Authentication & Profile (Epic 1)
- [ ] Sign up with new account
- [ ] Sign in with existing account
- [ ] Set display name and profile picture
- [ ] Sign out

### Conversations (Epic 1)
- [ ] View conversations list
- [ ] Create new one-on-one conversation
- [ ] Create new group conversation (3+ participants)
- [ ] Verify conversation sorting (most recent first)
- [ ] Verify unread counts displayed

### Messaging - Basic (Epic 1)
- [ ] Send text message
- [ ] Receive message in real-time (< 2 seconds)
- [ ] Verify optimistic UI (message appears immediately)
- [ ] View message timestamps (relative format)
- [ ] View online/offline presence indicators

### Messaging - Advanced (Epic 2)
- [ ] Edit sent message - verify "(edited)" badge
- [ ] View edit history
- [ ] Delete/unsend message - verify "Message deleted" placeholder
- [ ] Verify read receipts update ("Read" status)
- [ ] Type message - verify typing indicator appears for recipient

### Attachments (Epic 2)
- [ ] Send image attachment (< 10MB)
- [ ] View received image
- [ ] Send PDF document (< 10MB)
- [ ] View received PDF

### Reliability (Epic 2)
- [ ] Enable airplane mode, send message - verify fails gracefully
- [ ] Tap retry - verify message sends when online
- [ ] Compose 3 messages offline - verify offline queue
- [ ] Send all from queue - verify order maintained
- [ ] Background app, receive message - verify push notification

### Performance (Epic 2)
- [ ] Measure app launch time (< 1 second target)
- [ ] Load conversation with 50+ messages (< 1 second target)
- [ ] Send message (< 2 seconds target)
- [ ] Scroll through 100+ messages (smooth scrolling, no lag)

### Offline Behavior (Epic 1 & 2)
- [ ] View conversations offline (cached data)
- [ ] Compose messages offline (queued)
- [ ] Go back online - verify sync occurs
- [ ] Verify no data loss

---

## Regression Testing Workflow

### Pre-Commit Workflow
1. Run full test suite: `./scripts/quick-test.sh`
2. All tests must pass before committing
3. No decrease in code coverage allowed

### Pre-Release Workflow
1. Run full test suite with integration tests
2. Run all 10 reliability scenarios (see `reliability-scenarios.md`)
3. Execute manual smoke testing checklist above
4. Run performance baseline tests
5. Profile with Xcode Instruments (memory, battery)
6. Deploy to TestFlight for beta validation

### Post-Story Workflow
1. Run story-level tests: `./scripts/test-story.sh <TestName>`
2. Run epic-level tests: `./scripts/test-epic.sh <epic-num>`
3. Update this document if new tests added
4. Mark story complete in `docs/stories/`

---

## Test Coverage Analysis

### Viewing Coverage in Xcode

1. Run tests with coverage enabled:
   ```bash
   xcodebuild test -scheme MessageAI \
       -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
       -enableCodeCoverage YES
   ```

2. Open Xcode → Product → Test
3. View → Navigators → Reports
4. Select latest test run → Coverage tab

### Coverage Targets

| Layer | Minimum Coverage | Current Status |
|-------|------------------|----------------|
| **Domain Layer** | 80% | ✅ TBD (Story 2.12) |
| **Data Layer** | 70% | ✅ TBD (Story 2.12) |
| **Presentation Layer** | 75% | ✅ TBD (Story 2.12) |
| **Overall** | 70% | ✅ TBD (Story 2.12) |

*Coverage percentages to be updated in Task 2 of Story 2.12*

---

## Known Test Gaps

### Features with Limited Test Coverage
- Push notification handling (manual testing only)
- Network Link Conditioner scenarios (manual 3G testing)
- Multi-device sync scenarios (requires multiple simulators)
- Large attachment uploads (> 5MB files)

### Recommended Future Test Additions
1. UI tests for critical user flows (SwiftUI testing)
2. Snapshot tests for UI regressions
3. Load tests for 100+ message conversations
4. Multi-device integration tests
5. Stress tests for 10-user group chats

---

## Maintenance

### Adding New Tests

When adding new tests to the suite:

1. Update this document with test file reference
2. Map test to corresponding Epic/Story/Feature
3. Add execution command
4. Update test count in summary table
5. Update manual smoke testing checklist if applicable

### Deprecating Tests

When removing or refactoring tests:

1. Update this document to remove references
2. Update test count in summary table
3. Ensure no coverage gaps introduced
4. Document reason in Change Log section

---

## Change Log

| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2025-10-22 | 1.0 | Initial regression test suite documentation | James (Dev) |

---

## Related Documentation

- [Testing Strategy](../architecture/testing-strategy.md) - Complete testing workflow guide
- [Testing Best Practices](../architecture/testing-best-practices.md) - Testing patterns and standards
- [Reliability Scenarios](./reliability-scenarios.md) - 10 reliability test scenarios (Story 2.12)
- [Coverage Report](./coverage-report.md) - Detailed code coverage analysis (Story 2.12)
- [Performance Benchmarks](./performance-benchmarks.md) - Performance baseline results (Story 2.12)
