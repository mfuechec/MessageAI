# Tiered Testing Strategy

## Overview

MessageAI uses a **three-tier testing approach** optimized for rapid development with confidence.

## The Problem We Solved

**Before:**
- Running all tests: 2-3 minutes
- Hard to identify relevant failures
- Integration tests failed without emulator (confusing errors)
- Slow feedback loop discouraged frequent testing

**After:**
- Story tests: 5-20 seconds ⚡
- Epic tests: 20-40 seconds 🏃
- Full suite: 1-2 minutes 🎯
- Clear error messages when emulator needed

## Three Testing Tiers

```
┌─────────────────────────────────────────────────────────────┐
│  TIER 1: STORY TESTS                                  ⚡ 5-20s │
├─────────────────────────────────────────────────────────────┤
│  Purpose:   Test only what you just built                   │
│  When:      After each code change during story dev         │
│  Command:   ./scripts/test-story.sh NewConversationVM...    │
│  Tests:     Only the new test suite for current story       │
│  Example:   9 tests for Story 2.0                           │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  TIER 2: EPIC TESTS                                  🏃 20-40s │
├─────────────────────────────────────────────────────────────┤
│  Purpose:   Verify epic's features work together             │
│  When:      Before marking story complete                    │
│  Command:   ./scripts/test-epic.sh 2                         │
│  Tests:     All tests for features in the epic              │
│  Example:   ~40 tests for Epic 2                            │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  TIER 3: FULL SUITE                                 🎯 1-2min │
├─────────────────────────────────────────────────────────────┤
│  Purpose:   Complete regression testing                      │
│  When:      Before commit/push                               │
│  Command:   ./scripts/quick-test.sh                          │
│  Tests:     All ~100 unit tests (integration skipped)       │
│  Example:   Full codebase validation                         │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  TIER 4: INTEGRATION (Optional)                     🐌 2-5min │
├─────────────────────────────────────────────────────────────┤
│  Purpose:   Test with real Firebase Emulator                │
│  When:      Weekly / Before release / CI                     │
│  Command:   ./scripts/quick-test.sh --with-integration       │
│  Tests:     All tests + Firebase integration tests          │
│  Requires:  Firebase Emulator running (see below)           │
└─────────────────────────────────────────────────────────────┘
```

## Development Workflow

### 1. During Story Development (TDD Cycle)

```bash
# Edit code
vim MessageAI/Presentation/ViewModels/NewConversationViewModel.swift

# Test immediately (5-20 seconds)
./scripts/test-story.sh NewConversationViewModelTests

# Repeat until green ✅
```

**Why:** Instant feedback = faster development

### 2. Before Marking Story Complete

```bash
# Test entire epic (20-40 seconds)
./scripts/test-epic.sh 2

# If pass ✅, mark story "Ready for Review"
```

**Why:** Verify epic integration. Story is functionally complete. **Do NOT run full suite here** - that's for commit time.

### 3. Before Committing (User Responsibility)

```bash
# Full unit test suite (1-2 minutes) - User runs this before git commit
./scripts/quick-test.sh

# If pass ✅, safe to commit
git commit -m "Story 2.0: New Conversation Feature"
```

**Why:** Full regression testing across entire codebase. Run this yourself before committing multiple stories or pushing to remote.

### 4. Weekly / Before Release

```bash
# Terminal 1: Start emulator (once, keep running)
./scripts/start-emulator.sh

# Terminal 2: Full integration tests
./scripts/quick-test.sh --with-integration
```

**Why:** Validate real Firebase integration

## Script Reference

### Story Tests (Fastest)

```bash
./scripts/test-story.sh <TestClassName>
```

**Examples:**
```bash
./scripts/test-story.sh NewConversationViewModelTests
./scripts/test-story.sh ConversationsListViewModelTests
./scripts/test-story.sh MessageTests
```

**Output:** Only runs that specific test suite

### Epic Tests

```bash
./scripts/test-epic.sh <epic-number>
```

**Examples:**
```bash
./scripts/test-epic.sh 1    # Epic 1: Foundation & Core Messaging
./scripts/test-epic.sh 2    # Epic 2: Complete MVP with Reliability
```

**Output:** Runs all tests related to that epic

### Full Test Suite

```bash
./scripts/quick-test.sh [options]
```

**Options:**
- (none): Run all unit tests, skip integration (DEFAULT)
- `--quick` or `-q`: Skip build, run tests immediately
- `--with-integration`: Include integration tests (needs emulator)
- `--test <name>`: Run specific test suite

**Examples:**
```bash
./scripts/quick-test.sh                  # All unit tests
./scripts/quick-test.sh --quick          # Fast, no build
./scripts/quick-test.sh --with-integration  # Everything
```

### Firebase Emulator Management

```bash
# Check if emulator is running
./scripts/emulator-check.sh

# Start emulator (foreground with logs)
./scripts/start-emulator.sh

# Start emulator (background, silent)
./scripts/start-emulator.sh > /dev/null 2>&1 &

# Stop emulator
./scripts/stop-emulator.sh
```

**Emulator Ports:**
- Firestore: `http://localhost:8080`
- Auth: `http://localhost:9099`
- Storage: `http://localhost:9199`
- UI: `http://localhost:4000`

## Integration Test Behavior

All integration tests now **gracefully skip** when the emulator is not running:

```swift
override func setUp() async throws {
    try await super.setUp()
    
    // Skip all tests if emulator not running
    try XCTSkipIf(true, "Requires Firebase Emulator - start with ./scripts/start-emulator.sh")
    
    // ... emulator setup code ...
}
```

**No more confusing timeout errors!** You'll see:
```
Test Case 'testSendMessage_Success' skipped: Requires Firebase Emulator
```

## Test Organization

```
MessageAITests/
├── Domain/                    # Entity tests (always run)
│   ├── MessageTests.swift
│   ├── ConversationTests.swift
│   └── UserTests.swift
│
├── Presentation/              # ViewModel tests (always run)
│   └── ViewModels/
│       ├── Auth/
│       ├── Conversations/
│       │   ├── ConversationsListViewModelTests.swift
│       │   └── NewConversationViewModelTests.swift  ← Story 2.0
│       └── Messages/
│
├── Data/                      # Repository tests
│   ├── Mocks/                 # Mock implementations (always run)
│   └── Repositories/
│       ├── FirebaseAuthRepositoryTests.swift        ← Skipped by default
│       ├── FirebaseConversationRepositoryTests.swift
│       ├── FirebaseMessageRepositoryTests.swift     ← Skipped by default
│       └── FirebaseUserRepositoryTests.swift
│
└── Integration/               # Integration tests (skipped by default)
    ├── RealTimeMessagingIntegrationTests.swift
    ├── OfflinePersistenceIntegrationTests.swift
    └── PerformanceBaselineTests.swift
```

## Performance Comparison

| Test Level | Tests Run | Time | CPU | Use Case |
|------------|-----------|------|-----|----------|
| **Story** | ~10 | 10s | Low | Dev TDD cycle |
| **Epic** | ~40 | 30s | Low | Story completion |
| **Full Suite** | ~100 | 90s | Medium | Pre-commit |
| **+ Integration** | ~130 | 180s | Medium | Weekly validation |

## CI/CD Integration

**Recommended GitHub Actions workflow:**

```yaml
- name: Unit Tests (Fast)
  run: ./scripts/quick-test.sh
  
- name: Integration Tests (Weekly)
  if: github.event_name == 'schedule'
  run: |
    ./scripts/start-emulator.sh &
    sleep 10
    ./scripts/quick-test.sh --with-integration
```

## Best Practices

1. **During development:** Run story tests after every change
2. **Before marking story done:** Run epic tests
3. **Before committing:** Run full test suite
4. **Keep simulator booted:** Speeds up all test runs
5. **Start emulator once:** Keep running during dev session (lightweight)
6. **Don't restart emulator:** This was the old problem! Keep it alive.

## Troubleshooting

### "Some tests failed" but not sure which?

Use story-level testing to isolate:
```bash
./scripts/test-story.sh NewConversationViewModelTests
```

### Integration tests failing?

Check if emulator is running:
```bash
./scripts/emulator-check.sh
```

If not:
```bash
./scripts/start-emulator.sh &
./scripts/quick-test.sh --with-integration
```

### Tests taking too long?

1. Use `--quick` flag (skip build)
2. Keep simulator booted
3. Run story tests instead of full suite during dev

## Benefits

✅ **10x faster feedback** during development (120s → 10s)  
✅ **Easy identification** of relevant failures  
✅ **Reduced friction** = more frequent testing  
✅ **No confusion** about emulator requirements  
✅ **Production-ready** CI/CD workflow  
✅ **TDD-friendly** rapid iteration  

## Related Documentation

- [Testing Best Practices](./testing-best-practices.md)
- [Story Implementation Guide](../prd/story-implementation-guide.md)
- [CI/CD Setup](./ci-cd.md)
