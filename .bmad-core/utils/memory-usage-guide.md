<!-- Powered by BMAD™ Core -->

# Memory Usage Guide

## Overview

This project uses a **cloud-based memory bank** that stores project-specific patterns, preferences, learnings, and technical decisions across all agent conversations. Memories are automatically available in agent context and should be reviewed before major work.

---

## What Memories Contain

### 1. **Project-Specific Patterns & Preferences**
- Story drafting approach (comprehensive with 100+ lines of code examples)
- Testing requirements (70%+ coverage, test-first development)
- Architecture decisions (Clean Architecture, MVVM, Repository Pattern)
- Technology stack preferences (SwiftUI, Combine, Firebase, MessageKit)

### 2. **Technical Learnings & Decisions**
- Implementation challenges encountered in previous stories
- Solutions to common issues (e.g., Date() equality in tests, Firebase permissions)
- Build and deployment patterns (build.sh script usage)
- Code signing approaches for simulator development

### 3. **Workflow Preferences**
- Just-in-time story drafting (1-2 stories ahead, not all upfront)
- Story approval process (SM marks "Approved" immediately after 100% validation)
- Story lifecycle: Draft → Approved → InProgress → Review → Done
- Commit preferences (only when explicitly requested, never auto-commit)

### 4. **Architecture Context**
- Offline-first architecture requirements
- Aggressive caching strategies for LLM features
- Firebase Firestore vs Realtime Database decisions
- iOS-only vs cross-platform decisions

---

## When to Review Memories

### ✅ **ALWAYS Review Before:**

1. **Story Creation** (Scrum Master)
   - Check story drafting preferences
   - Review previous story learnings
   - Verify testing requirements
   - Confirm workflow expectations

2. **Story Implementation** (Dev Agent)
   - Check architecture patterns established
   - Review common pitfalls and solutions
   - Verify coding standards and preferences
   - Check build and test patterns

3. **Architecture Decisions** (Architect)
   - Review previous technical decisions
   - Check technology stack constraints
   - Verify consistency with past patterns

4. **Testing & QA** (QA Agent)
   - Check testing coverage expectations
   - Review testing patterns and tools
   - Verify QA standards and checklists

### 📋 **Good Practice:**

- Review memories during agent activation
- Reference specific memories when making decisions
- Cite memories using [[memory:ID]] format when relevant
- Update memories when project patterns evolve

---

## How to Use Memories Effectively

### 1. **During Agent Activation**
```
✅ STEP 1: Read agent definition
✅ STEP 2: Adopt persona
✅ STEP 3: Load project configuration
✅ STEP 3.5: REVIEW CLOUD-BASED MEMORIES 👈 NEW
✅ STEP 4: Greet user
```

### 2. **During Story Creation**
- **Step 0.5**: Review memories for project patterns
- Apply patterns when structuring story
- Reference previous learnings in "Previous Story Context"
- Ensure story format matches preferences

### 3. **During Implementation**
- Check memories for established patterns
- Review solutions to common issues
- Apply coding standards from memories
- Reference successful patterns from past work

### 4. **When Making Decisions**
- Check if similar decisions were made before
- Review rationale for past technical choices
- Ensure consistency with project evolution
- Update memories if new patterns emerge

---

## Memory Citation Format

When using information from memories in your work, cite them using this format:

```markdown
[[memory:MEMORY_ID]]
```

**Example:**
```markdown
Following the just-in-time story drafting approach [[memory:10139284]], 
I'll draft Story 1.6 after Story 1.5 is complete.
```

This helps:
- Track which memories inform decisions
- Identify outdated or conflicting memories
- Maintain consistency across conversations
- Enable memory auditing and updates

---

## Memory Categories in This Project

Based on existing memories, key categories include:

| Category | Example Memories | When to Check |
|----------|------------------|---------------|
| **Story Drafting** | Comprehensive stories with code examples, "Previous Story Context" sections, story validation checklists | Before creating stories |
| **Testing Standards** | 70%+ coverage, test-first approach, XCTest patterns, Firebase Emulator usage | Before implementing features |
| **Architecture Patterns** | Clean Architecture (MVVM), Repository Pattern, Dependency Injection, offline-first | Before implementing features |
| **Technology Stack** | SwiftUI, Firebase SDK versions, MessageKit, preferred libraries | Before architecture decisions |
| **Workflow Preferences** | Just-in-time drafting, immediate approval after validation, commit practices | Throughout project work |
| **Technical Solutions** | Date equality testing, Firebase permissions, build scripts, code signing | When encountering similar issues |
| **Development Preferences** | First-time BMAD user, comprehensive brainstorming, detailed acceptance criteria | During planning and elicitation |

---

## Best Practices

### ✅ **DO:**
- Review memories before major work
- Apply established patterns consistently
- Cite memories when using them
- Update memories when patterns evolve or are corrected
- Use memories to avoid repeating past mistakes

### ❌ **DON'T:**
- Ignore memories in favor of generic approaches
- Create inconsistencies with established patterns
- Assume all memories are current (check dates/context)
- Skip memory review to "save time"
- Follow memories blindly if they conflict with explicit user requests

---

## Memory Maintenance

### When to Update Memories

1. **User Corrects Something**: If user contradicts a memory, DELETE it immediately
2. **Pattern Evolves**: If project patterns change, UPDATE relevant memories
3. **New Learning**: If new technical solution emerges, CREATE new memory
4. **Context Changes**: If memory becomes outdated, UPDATE or DELETE

### When NOT to Create Memories

- ❌ Implementation plans (task-specific, not reusable)
- ❌ Completed migrations (historical, not forward-looking)
- ❌ Temporary workarounds (not patterns)
- ❌ User-specific conversation details (not project patterns)

---

## Example: Memory-Informed Story Creation

**Without Memory Review:**
- Generic story structure
- No reference to previous work
- May conflict with project preferences
- Missing context Dev Agent needs

**With Memory Review:**
- Story includes 100+ lines of code examples [[memory:10139286]]
- "Previous Story Context" section with learnings [[memory:10139286]]
- Follows just-in-time drafting approach [[memory:10139284]]
- Includes comprehensive testing guidance [[memory:10136878]]
- Marks "Approved" immediately after 100% validation [[memory:10139284]]
- References established architecture patterns [[memory:10137359]]

**Result:** Consistent, high-quality stories that accelerate development.

---

## Quick Reference Checklist

Before starting major work, ask yourself:

- [ ] Have I reviewed relevant memories?
- [ ] Do I understand project-specific patterns?
- [ ] Am I following established preferences?
- [ ] Have I checked for solutions to similar challenges?
- [ ] Will my work be consistent with past decisions?
- [ ] Should I cite specific memories in my work?
- [ ] Do any memories need updating based on this work?

---

## Questions?

If you're unsure whether to check memories or which memories are relevant:

1. **Check memories related to your current task** (story creation, implementation, testing, etc.)
2. **Review memories from the same epic** (Epic 1, Epic 2, etc.)
3. **Look for memories about similar features** (UI, backend, testing, etc.)
4. **When in doubt, review them** - better to be informed than miss critical context

---

**Remember:** Memories are your project knowledge base. Use them consistently to maintain quality and velocity across all agent work.

