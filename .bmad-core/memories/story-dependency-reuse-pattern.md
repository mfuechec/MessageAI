# Story Dependency & Infrastructure Reuse Pattern

**Pattern Type:** Story Creation Best Practice
**Date:** 2025-10-22
**Examples:** Story 2.8 (PDF Documents) builds on Story 2.7 (Image Attachments)

## Core Principle

**When creating dependent stories, explicitly document what's reused vs. what's new.**

## Pattern Template

### Story Structure for Dependent Features

```markdown
## What's Already Done (Infrastructure from Previous Stories)

### ✅ [Component Name] ([Previous Story])
- List existing infrastructure
- Show code examples
- Mark status: ✅ ALREADY EXISTS

### ✅ [Protocol/Repository] ([Previous Story])
- Show existing methods
- Indicate what will be extended

## What's NEW in Story X.Y

Story X.Y adds:
- List only NEW components
- Highlight differences from previous story
- Show new methods to add

## Previous Story Context (Story X.Y-1 Completion)

### Key Learnings from Story X.Y-1
- Technical patterns to reuse
- Performance optimizations discovered
- Error handling approaches

### Impact on Story X.Y
Story X.Y **reuses 90% of Story X.Y-1's infrastructure**:
- **Component A**: Same pattern, different type
- **Component B**: Same @Published properties
- **Component C**: Same error handling

**Key Differences:**
- List what's actually different
```

## Real-World Example: Story 2.8 (PDF) builds on Story 2.7 (Images)

### What We Reused (90%)

**From Story 2.7:**
- ✅ `StorageRepositoryProtocol` with progress handler pattern
- ✅ `ChatViewModel` upload state management (@Published properties)
- ✅ Firebase Storage security rules pattern
- ✅ Upload progress tracking with `uploadProgress[messageId]` dictionary
- ✅ Error handling with `uploadErrors[messageId]` dictionary
- ✅ Optimistic UI pattern (append message immediately)
- ✅ Cancellation support (store upload tasks in dictionary)
- ✅ Offline queue management
- ✅ MessageKit integration with custom cells

### What Changed (10%)

| Component | Story 2.7 (Images) | Story 2.8 (PDFs) |
|-----------|-------------------|------------------|
| **Picker** | UIImagePickerController | UIDocumentPickerViewController |
| **Viewer** | Full-screen image viewer | QuickLook (QLPreviewController) |
| **UI** | Image bubble | Document card (icon + name + size) |
| **Size Limit** | 2MB | 10MB |
| **Validation** | Image format checking | MIME type (application/pdf) |
| **Compression** | Image compression (JPEG 0.7-0.9) | None (PDFs not compressed) |
| **Storage Path** | `images/{conv}/{msg}/image.jpg` | `documents/{conv}/{msg}/document.pdf` |

### Story 2.8 Dev Notes Example

```markdown
## Previous Story Context (Story 2.7 Completion)

### Key Learnings from Story 2.7

**Upload Infrastructure:**
- StorageRepositoryProtocol extended with uploadMessageImage method
- Progress tracking using @Published properties
- Optimistic UI pattern works well
- Cancellation support prevents memory leaks

### Impact on Story 2.8

Story 2.8 **reuses 90% of Story 2.7's infrastructure**:
- **Storage Repository**: Same upload pattern, different file type
- **Progress Tracking**: Same @Published properties
- **Optimistic UI**: Same message append pattern

**Key Differences:**
- **Picker**: UIDocumentPickerViewController instead of UIImagePickerController
- **Viewer**: QuickLook instead of full-screen image viewer
- **Size Limit**: 10MB instead of 2MB
```

## Benefits of Explicit Reuse Documentation

### 1. Prevents Duplicate Implementation

**Without explicit reuse documentation:**
```
Dev Agent: "I need to implement document upload from scratch"
Result: 4-6 hours, duplicated code, inconsistent patterns
```

**With explicit reuse documentation:**
```
Dev Agent: "Story says reuse Story 2.7's upload pattern"
Result: 1-2 hours, consistent code, follows established patterns
```

**Time saved:** 3-4 hours per dependent story

### 2. Maintains Consistency

All attachment types follow same pattern:
- Same progress tracking mechanism
- Same error handling approach
- Same optimistic UI updates
- Same offline queue behavior

**User experience:** Consistent across all attachment types

### 3. Easier Testing

Reused infrastructure already tested:
- Upload progress tracking: ✅ Already tested in Story 2.7
- Error handling: ✅ Already tested in Story 2.7
- Cancellation: ✅ Already tested in Story 2.7
- Offline queue: ✅ Already tested in Story 2.7

**New tests needed:** Only for document-specific behavior (picker, QuickLook, validation)

### 4. Faster Story Review

PO/QA can focus on:
- What's actually new (10%)
- What's different from previous story

Don't need to re-review:
- Upload infrastructure
- Progress tracking
- Error handling
- Offline behavior

## When to Use This Pattern

### ✅ Use When:
- Story adds new attachment type (images → PDFs → videos)
- Story extends existing UI pattern (read receipts → typing indicators)
- Story adds new message operation (send → edit → delete)
- Infrastructure exists from previous story

### ❌ Don't Use When:
- Story is completely new functionality (no prior infrastructure)
- Story refactors existing code (different purpose)
- Story is first in its category

## Story Creation Checklist for Dependent Stories

**Before writing story:**
- [ ] Identify previous story with shared infrastructure
- [ ] List what can be reused (aim for 80%+)
- [ ] Document only the differences

**While writing story:**
- [ ] Add "What's Already Done" section with ✅ checkmarks
- [ ] Add "Previous Story Context" section
- [ ] Add "What's NEW" section (only new stuff)
- [ ] Quantify reuse percentage (e.g., "reuses 90% of infrastructure")

**In Dev Notes:**
- [ ] Reference previous story completion notes
- [ ] List reusable patterns explicitly
- [ ] Highlight key differences
- [ ] Add Task 0: Check existing implementation first

**In Tasks:**
- [ ] Task 0: Check existing implementation (avoid duplicate work)
- [ ] Tasks reference existing infrastructure: "Reuse Story 2.7 pattern"
- [ ] Only create tasks for NEW components

## Anti-Patterns to Avoid

❌ **Assuming dev knows what exists**
```markdown
## Tasks
- [ ] Implement document upload
```
Dev doesn't know Story 2.7 already has upload infrastructure.

✅ **Explicit reuse reference**
```markdown
## Tasks
- [ ] Implement uploadMessageDocument (reuse Story 2.7's uploadMessageImage pattern)
```

---

❌ **Documenting everything from scratch**
```markdown
## Dev Notes
[20 pages of upload infrastructure documentation]
```
Story is overwhelming, most already exists.

✅ **Reference existing, document new**
```markdown
## Dev Notes

### Previous Story Infrastructure (Story 2.7)
- Upload progress tracking: ✅ Already implemented
- Error handling: ✅ Already implemented

### New for Story 2.8
- Document picker: UIDocumentPickerViewController
- QuickLook viewer: QLPreviewController
```

---

❌ **Vague reuse statement**
```markdown
This story builds on Story 2.7.
```
Dev doesn't know what specifically to reuse.

✅ **Specific reuse with percentages**
```markdown
Story 2.8 **reuses 90% of Story 2.7's infrastructure**:
- Storage Repository: Same upload pattern
- ChatViewModel: Same @Published properties
- Error handling: Same retry mechanism
```

## Impact on Story Estimates

| Approach | Estimate | Actual Time | Notes |
|----------|----------|-------------|-------|
| **No reuse documentation** | 4-6 hours | 6-8 hours | Dev reimplements from scratch |
| **Vague reuse mention** | 4-6 hours | 4-5 hours | Dev discovers reuse during implementation |
| **Explicit reuse (this pattern)** | 2-3 hours | 2-3 hours | Dev follows established patterns |

**Time saved:** 50-60% with explicit reuse documentation

## Key Takeaways

1. ✅ **Document what's reused** - Don't make devs rediscover infrastructure
2. ✅ **Quantify reuse percentage** - "Reuses 90% of Story 2.7" sets expectations
3. ✅ **List key differences** - Table format works well
4. ✅ **Reference previous story completion notes** - Learn from implementation
5. ✅ **Task 0: Check existing implementation** - Prevent duplicate work
6. ✅ **Keep story focused on NEW components** - Don't re-document existing code
7. ✅ **Maintain consistency** - Same patterns = better UX + faster development

## Pattern Success Metrics

**Story 2.8 (using this pattern):**
- Estimated: 3-4 hours
- 90% infrastructure reuse from Story 2.7
- Only 4 new components (picker, viewer, card, validator)
- Clear dependencies documented
- Tasks reference existing patterns

**Expected outcome:** Fast implementation, consistent UX, maintainable code
