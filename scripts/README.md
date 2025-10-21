# MessageAI Scripts

Utility scripts for development and testing.

## Table of Contents

- [Test Scripts](#test-scripts) - Tiered testing with smart error detection
- [Seed Test Data](#seed-test-data-script) - Populate Firebase with test data
- [Cleanup Duplicates](#cleanup-duplicate-conversations) - Remove duplicate conversations
- [Build Script](#build-script) - Simplified Xcode builds
- [Firebase Emulator](#firebase-emulator-scripts) - Local testing with Firebase Emulator

---

## Test Scripts

MessageAI uses a tiered testing strategy for efficient development. All test scripts now include automatic logging and smart error detection.

### Features (New in Story 2.1)

✅ **Automatic Log Persistence** - All test runs save to `.cursor/.agent-tools/test-logs/`  
✅ **Smart Error Detection** - Automatically finds and displays compilation errors, missing symbols, failed tests  
✅ **Verbose Mode** - See full xcodebuild output when needed  
✅ **Quiet Mode** - Suppress error details for CI/automation  
✅ **Color-Coded Output** - Errors in red, successes in green, info in blue  

### test-story.sh - Story-Level Tests (5-20 seconds)

Run during story development after each code change for instant feedback.

**Usage:**
```bash
./scripts/test-story.sh <TestClassName> [--verbose|-v] [--quiet|-q]
```

**Examples:**
```bash
# Default mode (filtered output + saved log)
./scripts/test-story.sh NewConversationViewModelTests

# Verbose mode (see everything)
./scripts/test-story.sh ChatViewModelTests --verbose

# Quiet mode (pass/fail only)
./scripts/test-story.sh UserTests -q
```

**Output:**
```
✅ Story tests passed!
💡 Next: Review changes, then run epic tests

Test Results:
  ✓ 14 tests passed
  ⏱ 2.1 seconds
  💾 Log: .cursor/.agent-tools/test-logs/NewConversationViewModelTests-20251021-123456.log
```

**On Failure:**
```
❌ Story tests failed

🔍 Error Details:
─────────────────────────────────────────
Missing symbols:
  Cannot find 'mockUserRepository' in scope

Failed tests:
  Test Case 'testGetSenderName_OtherUser' failed (0.360 seconds)
    XCTAssertEqual failed: ("Unknown") is not equal to ("Alice")
─────────────────────────────────────────
💾 Full log: .cursor/.agent-tools/test-logs/ChatViewModelTests-20251021-122821.log
💡 Run with --verbose for complete output
```

### test-epic.sh - Epic-Level Tests (20-40 seconds)

Run before marking story complete to catch integration issues within epic scope.

**Usage:**
```bash
./scripts/test-epic.sh <epic-number> [--verbose|-v] [--quiet|-q]
```

**Examples:**
```bash
# Epic 1: Foundation & Core Messaging (7 test classes)
./scripts/test-epic.sh 1

# Epic 2: Complete MVP with Reliability (2 test classes, 39 tests)
./scripts/test-epic.sh 2

# With verbose output
./scripts/test-epic.sh 2 --verbose
```

**Epic Test Coverage:**

| Epic | Test Classes | Test Count | Features Covered |
|------|--------------|------------|------------------|
| 1 | 7 classes | ~100 tests | Auth, Profile, Conversations, Chat, Domain Models |
| 2 | 2 classes | 39 tests | New Conversations, Group Chat, Multi-select |

**Output:**
```
🎯 Running Epic 2 Tests
💾 Log file: .cursor/.agent-tools/test-logs/epic-2-20251021-123611.log

Epic 2: Complete MVP with Reliability
Test Suite 'NewConversationViewModelTests' passed - 14 tests
Test Suite 'ChatViewModelTests' passed - 25 tests

✅ Epic 2 tests passed!
💡 Next: Run full suite with ./scripts/quick-test.sh
```

### quick-test.sh - Full Test Suite (1-2 minutes)

Run before committing. Tests all ~100 unit tests (integration tests skipped by default).

**Usage:**
```bash
# Unit tests only (default, fast)
./scripts/quick-test.sh

# Include Firebase Emulator integration tests (requires emulator running)
./scripts/quick-test.sh --with-integration
```

**See:** [docs/architecture/testing-strategy.md](../docs/architecture/testing-strategy.md) for complete testing documentation.

### Test Logs

All test runs automatically save complete logs:

```
.cursor/.agent-tools/test-logs/
├── ChatViewModelTests-20251021-122821.log
├── NewConversationViewModelTests-20251021-125432.log
├── epic-2-20251021-123611.log
└── ...
```

**Benefits:**
- Review test output after the fact
- Share logs with team members
- Compare test runs over time
- Debug CI failures

**Note:** Logs are automatically `.gitignore`d (part of `.cursor/` directory).

### When to Use Each Tier

| Scenario | Script | Time | When |
|----------|--------|------|------|
| 🔨 Active development | `test-story.sh` | 5-20s | After each code change |
| ✅ Story completion | `test-epic.sh` | 20-40s | Before marking story done |
| 🚀 Before commit | `quick-test.sh` | 1-2m | Before git commit |
| 🧪 Weekly/CI | `quick-test.sh --with-integration` | 2-5m | Weekly or pre-release |

---

## Seed Test Data Script

Creates test users, conversations, and messages in Firebase for manual testing.

### Setup (One-Time)

1. **Install dependencies:**
   ```bash
   cd scripts
   npm install
   ```

2. **Download Firebase Admin SDK Key:**
   
   For DEV database:
   - Go to [Firebase Console](https://console.firebase.google.com)
   - Select `messageai-dev-1f2ec` project
   - Go to Project Settings → Service Accounts
   - Click "Generate New Private Key"
   - Save as `firebase-admin-key-dev.json` in project root (one level up from scripts/)
   
   For PROD database (optional):
   - Select `messageai-prod-4d3a8` project
   - Repeat above steps
   - Save as `firebase-admin-key-prod.json`

3. **Add keys to .gitignore** (already done if following standard setup):
   ```
   firebase-admin-key-*.json
   ```

### Usage

**Seed DEV database (default):**
```bash
cd scripts
npm run seed
```

**Seed PROD database (use carefully!):**
```bash
cd scripts
npm run seed:prod
```

### What Gets Created

- **3 Test Users:**
  - `test1@messageai.dev` / `password123` (Alice TestUser)
  - `test2@messageai.dev` / `password123` (Bob TestUser)
  - `test3@messageai.dev` / `password123` (Charlie TestUser)

- **3 Conversations:**
  - 1-on-1: Alice ↔ Bob (5 messages)
  - 1-on-1: Alice ↔ Charlie (3 messages)
  - Group: Alice, Bob, Charlie (4 messages)

- **All with proper schema:**
  - All required Conversation entity fields
  - All required Message entity fields
  - All required User entity fields
  - Server timestamps for accurate testing

### Testing Real-Time Sync

1. Run seed script: `npm run seed`
2. Open Xcode → Run app (first simulator)
3. Sign in as `test1@messageai.dev`
4. Open second simulator
5. Sign in as `test2@messageai.dev`
6. Send messages between users
7. Watch real-time updates!

### Troubleshooting

**Error: Cannot find module 'firebase-admin'**
- Run `npm install` in scripts/ directory

**Error: Failed to load service account key**
- Download the key from Firebase Console (see Setup step 2)
- Ensure filename matches: `firebase-admin-key-dev.json`
- Place in project root (not in scripts/ folder)

**Script runs but no data appears in app**
- Verify you're looking at correct Firebase project in console
- Check app is running in DEBUG mode (uses DEV database)
- Look for console logs in Xcode showing conversation count

## Cleanup Duplicate Conversations

Finds and removes duplicate conversations with identical participantIds. Useful for cleaning up old test data created before duplicate prevention was implemented.

### Usage

**Dry run (see what would be deleted, no actual deletion):**
```bash
npm run cleanup
# or: node scripts/cleanup-duplicates.js --dry-run
```

**Clean up DEV database:**
```bash
npm run cleanup:run
# or: node scripts/cleanup-duplicates.js
```

**Clean up PROD database (use carefully!):**
```bash
npm run cleanup:prod
# or: node scripts/cleanup-duplicates.js --prod
```

### How It Works

1. Scans all conversations in Firestore
2. Groups conversations by participant signature (sorted participant IDs)
3. For duplicate groups:
   - **Keeps** the oldest conversation (earliest `createdAt`)
   - **Deletes** newer duplicates and their associated messages
4. Shows summary of what was kept/deleted

### Example Output

```
🧹 Cleaning up duplicate conversations in DEV database...

🔍 Scanning for duplicate conversations...

Found 9 total conversations

📦 Found 3 conversations with participants: user1, user2
   ✓ KEEP: test-conv-1234567890 (created 2025-01-15T10:00:00.000Z)
   ✗ DELETE: test-conv-1234567891 (created 2025-01-15T10:05:00.000Z)
   ✗ DELETE: test-conv-1234567892 (created 2025-01-15T10:10:00.000Z)

📊 Summary:
   Total conversation groups: 7
   Groups with duplicates: 1
   Conversations to keep: 1
   Duplicate conversations to delete: 2

🗑️  Deleting 2 duplicate conversations...

✅ Successfully deleted 2 duplicate conversations and their messages!
```

### Safety Features

- **Dry run mode** to preview changes before deleting
- **Preserves oldest conversation** (most likely to have message history)
- **Deletes orphaned messages** to keep database clean
- **Batch operations** for efficiency with large datasets

## Other Scripts

### Testing Scripts

## 🎯 Tiered Testing Strategy

We use a **three-tier testing approach** for efficient development:

| Tier | Purpose | Speed | When to Use | Command |
|------|---------|-------|-------------|---------|
| **Story Tests** | Test just what you built | ⚡ 5-20s | After each code change | `./scripts/test-story.sh <TestName>` |
| **Epic Tests** | Test epic's features | 🏃 20-40s | After completing story | `./scripts/test-epic.sh <epic-num>` |
| **Full Suite** | All unit tests | 🐢 1-2min | Before commit/push | `./scripts/quick-test.sh` |
| **Integration** | With emulator | 🐌 2-5min | Weekly / CI | `./scripts/quick-test.sh --with-integration` |

---

### Level 1: Story Tests (FASTEST) ⚡

**test-story.sh** - Test only what you just implemented
```bash
# Story 2.0: New Conversation
./scripts/test-story.sh NewConversationViewModelTests

# Story 2.1: Message Status
./scripts/test-story.sh MessageStatusViewModelTests

# Any specific test suite
./scripts/test-story.sh ConversationsListViewModelTests
```

**Why:** Instant feedback loop (5-20 seconds). Run after every change during story development.

---

### Level 2: Epic Tests (FAST) 🏃

**test-epic.sh** - Test all features in an epic
```bash
./scripts/test-epic.sh 1    # Epic 1: Foundation & Core Messaging
./scripts/test-epic.sh 2    # Epic 2: Complete MVP with Reliability
```

**Why:** Verify your story didn't break other epic features (20-40 seconds). Run before marking story complete.

---

### Level 3: Full Test Suite (COMPREHENSIVE) 🎯

**quick-test.sh** - Fast unit testing (default: skips integration tests)
```bash
./scripts/quick-test.sh              # Run all unit tests (1-2 min)
./scripts/quick-test.sh --quick      # Skip build, just run tests
./scripts/quick-test.sh --with-integration  # Include integration tests (needs emulator)
```

**Why:** Full regression testing before commit/push (1-2 minutes).

**build.sh** - Build the iOS app
```bash
./scripts/build.sh                   # Build in Debug mode
./scripts/build.sh --config Release  # Build for production
```

**ci-test.sh** - Full test suite for CI/CD
```bash
./scripts/ci-test.sh                 # Run all tests (works with/without emulator)
```

### Firebase Emulator Scripts

**IMPORTANT:** Integration tests require the Firebase Emulator to be running. Unit tests (which run by default) do NOT need the emulator.

**emulator-check.sh** - Check if emulator is running
```bash
./scripts/emulator-check.sh
```

**start-emulator.sh** - Start Firebase Emulator
```bash
# Option 1: Run in foreground (see logs)
./scripts/start-emulator.sh

# Option 2: Run in background (during dev session)
./scripts/start-emulator.sh > /dev/null 2>&1 &

# Check if running
./scripts/emulator-check.sh
```

**stop-emulator.sh** - Stop Firebase Emulator
```bash
./scripts/stop-emulator.sh
```

**run-integration-tests.sh** - Run integration tests (requires emulator)
```bash
# Make sure emulator is running first!
./scripts/emulator-check.sh

# Then run integration tests
./scripts/run-integration-tests.sh
```

### Recommended Testing Workflow

**During Story Development (TDD cycle):**
```bash
# 1. Make a code change
# 2. Test just that story (5-20 seconds)
./scripts/test-story.sh NewConversationViewModelTests

# 3. Repeat until story complete
```

**Before Marking Story Complete:**
```bash
# Test entire epic (20-40 seconds)
./scripts/test-epic.sh 2

# If epic tests pass, story is ready for commit
```

**Before Committing/Pushing:**
```bash
# Full unit test suite (1-2 minutes)
./scripts/quick-test.sh

# Only commit if all tests pass
git commit -m "Story X.X: Feature Name"
```

**Weekly / Before Major Release:**
```bash
# Terminal 1: Start emulator (keep running)
./scripts/start-emulator.sh

# Terminal 2: Run EVERYTHING including integration tests
./scripts/quick-test.sh --with-integration
```

**Resource Usage:**
- Unit tests only: ~100 MB RAM, < 10 seconds
- With emulator: ~300 MB RAM total, first run ~30 seconds, subsequent ~10 seconds
- Emulator idle: ~200 MB RAM, < 1% CPU (barely noticeable)

### Emulator Management Best Practices

1. **Keep emulator running during development** - It's lightweight and speeds up integration testing
2. **Stop emulator at end of day** - Free up ~200MB RAM when not needed
3. **Don't restart emulator between test runs** - This was the old problem! Keep it running.
4. **Check status anytime** - Use `./scripts/emulator-check.sh`

