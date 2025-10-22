# Story Implementation Checklist

**Date:** 2025-10-22
**Lesson From:** Story 2.5 - Read Receipts (95% pre-implemented)

## Critical First Step: Check Existing Implementation

**BEFORE writing any code, ALWAYS check if the feature is already implemented.**

### Story 2.5 Example

**What the story asked for:**
- Repository method for markMessagesAsRead ✅ Already existed
- ChatViewModel integration ✅ Already existed
- ReadReceiptDetailView ✅ Already existed
- Unit tests ✅ Already existed
- Visual indicators ✅ Partially existed

**What actually needed to be done:**
- Add group chat read count display ("Read by X of Y") ← Only this!

**Time saved:** ~4-6 hours by checking first

## Pre-Implementation Checklist

### 1. Read the ENTIRE Story File First
```bash
# Check story's Dev Notes section for "What's Already Done"
cat docs/stories/2.5.read-receipts.md | grep -A 50 "What's Already Done"
```

**Story files often include:**
- "What's Already Done" section
- "Previous Story Context" section
- Code snippets showing existing implementations

### 2. Search for Existing Protocol Methods
```bash
# Search protocol definitions
grep -r "markMessagesAsRead" MessageAI/Domain/Repositories/

# Check if implementation exists
grep -r "markMessagesAsRead" MessageAI/Data/Repositories/
```

### 3. Check ViewModel for Existing Methods
```bash
# Search ViewModel implementations
grep -r "markMessagesAsRead" MessageAI/Presentation/ViewModels/

# Check lifecycle methods
grep -r "onAppear" MessageAI/Presentation/ViewModels/ChatViewModel.swift
```

### 4. Look for Existing Views/Components
```bash
# Search for view files
find MessageAI/Presentation/Views -name "*Receipt*.swift"

# Check imports and usage
grep -r "ReadReceiptDetailView" MessageAI/Presentation/Views/
```

### 5. Verify Test Coverage
```bash
# Check if tests already exist
grep -r "testMarkMessagesAsRead" MessageAITests/

# Count existing tests
grep -c "func test.*markMessagesAsRead" MessageAITests/Presentation/ViewModels/ChatViewModelTests.swift
```

### 6. Check Mock Repository Support
```bash
# Verify mock has the method
grep -A 10 "markMessagesAsRead" MessageAITests/Data/Mocks/MockMessageRepository.swift
```

## Implementation Decision Tree

```
START
  ↓
Does protocol method exist?
  ├─ NO → Implement from scratch (Domain → Data → Presentation)
  └─ YES → Continue checking...
       ↓
  Does repository implement it?
    ├─ NO → Implement repository + tests
    └─ YES → Continue checking...
         ↓
    Does ViewModel use it?
      ├─ NO → Add ViewModel integration + tests
      └─ YES → Continue checking...
           ↓
      Does UI display it correctly?
        ├─ NO → Update UI components
        └─ YES → Story already complete! Update story file.
```

## Story 2.5 Walkthrough (What I Did Right)

### Step 1: Read Story File ✅
```bash
# Opened docs/stories/2.5.read-receipts.md
# Found "What's Already Done" section
# Saw extensive list of completed items
```

### Step 2: Verify Protocol ✅
```bash
grep "markMessagesAsRead" MessageAI/Domain/Repositories/MessageRepositoryProtocol.swift
# FOUND: func markMessagesAsRead(messageIds: [String], userId: String) async throws
```

### Step 3: Check Implementation ✅
```bash
grep -A 20 "markMessagesAsRead" MessageAI/Data/Repositories/FirebaseMessageRepository.swift
# FOUND: Complete implementation with batch writes
```

### Step 4: Verify ViewModel ✅
```bash
grep -A 30 "markMessagesAsRead" MessageAI/Presentation/ViewModels/Chat/ChatViewModel.swift
# FOUND: Complete method with optimistic UI
# FOUND: Call in onAppear()
```

### Step 5: Check Tests ✅
```bash
grep "testMarkMessagesAsRead" MessageAITests/Presentation/ViewModels/ChatViewModelTests.swift
# FOUND: 5 tests covering read receipt logic
```

### Step 6: Review UI ✅
```bash
grep -A 20 "statusIconAndColor" MessageAI/Presentation/Views/Chat/ChatView.swift
# FOUND: Basic status indicators
# MISSING: Group chat read count display ← This is what I implemented!
```

## Red Flags That Code Might Already Exist

🚩 **Story mentions "What's Already Done"** - Always check this section first

🚩 **Previous story in same epic** - Features often share code

🚩 **Entity fields already exist** - `readBy` and `readCount` fields = backend likely implemented

🚩 **Tests reference the feature** - Test names like `testMarkMessagesAsRead_*` = implementation exists

🚩 **Mock has the method** - If mock supports it, real repo probably does too

## Time Estimates

| Approach | Time Required | Risk |
|----------|--------------|------|
| **Check first, then implement** | 30min check + 1-2hr implementation | Low ✅ |
| **Implement blindly** | 4-6hr duplicate work + 1hr fixing conflicts | High ❌ |

**Time saved by checking first: 4-6 hours**

## Common Scenarios

### Scenario 1: Feature 100% Complete
**Action:** Update story file with completion notes, mark Done, commit

**Example:** If Story 2.5 had group read counts already implemented

### Scenario 2: Feature 80% Complete (Most Common)
**Action:** Identify missing pieces, implement only those

**Example:** Story 2.5 - Only group read count display missing

### Scenario 3: Feature 0% Complete
**Action:** Implement full stack (Domain → Data → Presentation → Tests)

**Example:** Completely new feature like AI summarization

### Scenario 4: Feature Exists But Broken
**Action:** Debug existing implementation, write failing test, fix

**Example:** Read receipts implemented but not working

## Documentation to Check

**In order of importance:**

1. **Story file itself** (`docs/stories/2.x.story-name.md`)
   - "What's Already Done" section
   - "Dev Notes" section
   - Code snippets in story

2. **Previous story in epic** (`docs/stories/2.y.previous-story.md`)
   - "Completion Notes" section
   - "File List" section

3. **CLAUDE.md** (project overview)
   - Architecture diagrams
   - File locations
   - Current feature status

4. **Git history**
   ```bash
   git log --all --grep="read receipt" --oneline
   ```

5. **Test files** (often more up-to-date than docs)
   ```bash
   ls MessageAITests/Presentation/ViewModels/
   ```

## Key Takeaways

1. ✅ **ALWAYS check existing implementation FIRST** - Could save 4-6 hours
2. ✅ **Read "What's Already Done" section** - Story files tell you what exists
3. ✅ **Search protocol → repo → viewmodel → UI** - Systematic approach
4. ✅ **Check test coverage** - Tests reveal what's implemented
5. ✅ **Look at previous stories** - Features often build on each other
6. ✅ **Use grep/find extensively** - Faster than manual file browsing
7. ✅ **Update story file accurately** - Help future developers

## Anti-Patterns to Avoid

❌ **Starting to code immediately** - High risk of duplicate work

❌ **Assuming nothing exists** - Wastes time reimplementing

❌ **Ignoring "What's Already Done"** - Story files are written for you

❌ **Not checking tests** - Tests often reveal hidden implementations

❌ **Skipping git history** - Previous commits show what's done

## The Golden Rule

> **"Grep first, code second."**

**Before writing ANY code:**
```bash
# 1. Search protocols
grep -r "methodName" MessageAI/Domain/

# 2. Search implementations
grep -r "methodName" MessageAI/Data/

# 3. Search ViewModels
grep -r "methodName" MessageAI/Presentation/

# 4. Search tests
grep -r "testMethodName" MessageAITests/

# 5. If all return results → Feature likely exists!
```

**Story 2.5 taught us:** 95% of the work was already done. By checking first, implementation took 30 minutes instead of 6 hours.
