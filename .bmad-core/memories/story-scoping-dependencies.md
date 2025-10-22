# Story Scoping & Dependency Analysis

**Date:** 2025-10-22
**Context:** Story 2.7, 2.8, 2.9 scoping session

## Key Principle: Check Dependencies Before Parallel Scoping

**Always verify story dependencies in the Epic Scope document before attempting parallel scoping.**

### Decision Framework

```
Can scope Story X and Story Y in parallel?
  ↓
Check Epic Scope document for explicit dependencies
  ↓
Story Y depends on Story X?
  ├─ YES → ❌ Scope sequentially (X first, then Y)
  └─ NO  → ✅ Can scope in parallel
```

## Real Example: Stories 2.7, 2.8, 2.9

### Story Dependencies (from Epic 2 Scope)

**Story 2.7: Image Attachments**
- Dependencies: None
- Deliverables: Firebase Storage upload, compression, progress indicators, security rules

**Story 2.8: Document Attachments (PDF)**
- Dependencies: **Story 2.7** ← BLOCKS parallel scoping
- Deliverables: Reuses 2.7's upload infrastructure
- Epic Scope explicitly states: "Sequential: Story 2.7 must complete before 2.8 (shared infrastructure)"

**Story 2.9: Offline Message Queue**
- Dependencies: None
- Deliverables: Queue management, connectivity monitoring, manual send

### Decision Made

✅ **Scope 2.7 and 2.9 in parallel** - Both independent
❌ **Cannot scope 2.8 yet** - Depends on 2.7's infrastructure design

**Why 2.8 must wait:**
1. Storage upload patterns defined in 2.7
2. Security rules written in 2.7 apply to PDFs
3. Offline queue for uploads designed in 2.7
4. Repository abstractions for attachments created in 2.7

**Risk of scoping 2.8 early:**
- Would have to guess at upload infrastructure design
- Likely rework after 2.7 implementation reveals constraints
- Wasted effort creating story that needs revision

## Pattern Reuse: Story 2.9 Example

**Story 2.9 (Offline Queue) extends Story 2.4 (Message Retry):**

Story 2.4 introduced:
- `FailedMessageStore` class for persistent local storage
- UserDefaults-based serialization with Codable
- Message persistence across app restarts
- Retry mechanism with user control

Story 2.9 reuses this pattern:
- `OfflineQueueStore` uses same UserDefaults approach
- Same Codable serialization pattern
- Same persistence guarantees
- Similar UI patterns (failed message UI → queued message UI)

**Benefit:** Saved 2-3 hours by reusing proven architecture instead of designing from scratch.

## Always Check for Existing Drafts

**Before drafting a story, check if it already exists:**

```bash
ls -la docs/stories/ | grep "2\.7\|2\.8\|2\.9"
```

**Story 2.7 was already drafted (Status: Draft):**
- Created on Oct 22, 15:25
- 53KB comprehensive story file
- Saved ~2 hours by not duplicating work

**Lesson:** Always check `docs/stories/` directory before starting story creation task.

## Epic Scope Document is Source of Truth

**Location:** `docs/prd/epic-{n}-scope-and-roadmap.md`

**Contains:**
- Story sequence and dependencies
- Parallel implementation opportunities
- Complexity estimates
- Risk assessment

**Always reference this document when:**
1. Planning which stories to draft next
2. Determining if parallel scoping is possible
3. Understanding technical dependencies between stories
4. Estimating effort and timeline

## Sequential vs. Parallel Scoping

### When to Scope Sequentially ⏭️

- Story B **depends on** Story A (shared infrastructure)
- Story B builds on **architecture decisions** made in Story A
- Story B requires **code artifacts** from Story A
- Epic Scope document lists Story A as blocker for Story B

**Example:** Story 2.8 (PDFs) depends on Story 2.7 (Images)

### When to Scope in Parallel ⚡

- Stories are **functionally independent**
- No **shared infrastructure** or code dependencies
- Epic Scope document lists as "Parallel Set"
- Different **functional areas** (messaging vs. profiles)

**Example:** Stories 2.2, 2.3, 2.4 (message operations) - listed as "Parallel Set 1" in Epic 2 Scope

## Common Dependency Patterns

### Infrastructure Dependencies 🏗️

Story A creates infrastructure → Story B uses it
- Example: Story 2.7 (Storage upload) → Story 2.8 (PDF upload)
- **Action:** Wait for Story A to reach "Approved" or "Done"

### Data Model Dependencies 📊

Story A extends entity → Story B uses new fields
- Example: Story 1.3 adds `attachments` field → Story 2.7 uses it
- **Action:** Can proceed if entity already updated (check existing code)

### Feature Dependencies 🔗

Story A implements pattern → Story B follows same pattern
- Example: Story 2.4 (FailedMessageStore) → Story 2.9 (OfflineQueueStore)
- **Action:** Can scope in parallel, reference Story A's pattern in Story B

### No Dependencies ✅

Stories operate on different parts of codebase
- Example: Story 2.5 (Read Receipts) + Story 2.6 (Typing Indicators)
- **Action:** Safe to scope in parallel

## Efficiency Tips

1. **Read Epic Scope first** - Saves time by understanding full picture
2. **Check existing drafts** - Avoid duplicate work
3. **Reference previous stories** - Reuse established patterns
4. **Update Epic Scope** - Mark stories as drafted/approved for team visibility

## Key Takeaways

✅ **Always check Epic Scope for dependencies before scoping**
✅ **Infrastructure dependencies require sequential scoping**
✅ **Independent stories can be scoped in parallel**
✅ **Reuse patterns from previous stories when possible**
✅ **Check for existing drafts before starting story creation**
✅ **Epic Scope document is the authoritative source**

**Time saved by following this approach:** 4-6 hours (avoided duplicate work + prevented rework from incorrect dependencies)
