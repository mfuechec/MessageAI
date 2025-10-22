# Story Validation Best Practices

**Date:** 2025-10-22
**Context:** Story 2.9 validation - example of excellent story writing

## Story Validation Framework (9 Dimensions)

Use this comprehensive checklist when validating story readiness:

### 1. Template Compliance ✅
- All required sections present (Status, Story, AC, Tasks, Dev Notes, Testing, Change Log)
- No placeholder text remaining (no "TBD", "TODO", etc.)
- Format matches `story-tmpl.yaml` structure

### 2. File Structure Validation ✅
- Clear file paths for ALL new components
- Repository methods explicitly named
- ViewModel property names specified
- No ambiguous "somewhere in..." descriptions

### 3. UI/Frontend Completeness ✅
- Complete SwiftUI code examples for ALL new views
- Component hierarchy defined (parent-child relationships)
- State management patterns clear (@Published, @ObservedObject, etc.)
- Navigation flows documented

### 4. Acceptance Criteria Satisfaction ✅
- Every AC maps to specific task(s)
- No orphan ACs without implementation tasks
- Task subtasks provide concrete implementation steps
- No missing AC coverage

### 5. Testing Instructions ✅
- Unit test count specified with file names
- Integration test scenarios defined
- Manual testing checklist provided
- Performance targets stated (< Xms requirements)

### 6. Security Considerations ✅
- Security implications assessed
- Firestore security rules considered
- Data validation patterns documented
- Authentication/authorization requirements clear

### 7. Task Sequencing ✅
- Logical task order (infrastructure → business logic → UI)
- Dependencies between tasks identified
- No circular dependencies
- Clear starting point for dev agent

### 8. Anti-Hallucination Verification ✅
**CRITICAL**: All technical claims must be traceable to source documents

Verify:
- NetworkMonitor exists in codebase (check file path)
- FailedMessageStore pattern exists (reference Story 2.4)
- MessageStatus enum has required cases
- Repository protocols support required methods
- Architecture patterns match documented standards

**How to verify**: Search codebase for referenced classes/patterns before approving

### 9. Dev Agent Readiness ✅
Ask: "Can a dumb AI agent implement this without asking questions?"

Requirements:
- Self-contained (no external research needed)
- Clear implementation path
- Complete code examples
- No ambiguous requirements
- Expected 4-6 hour implementation time

## Story 2.9 as Gold Standard

**Score:** 9.5/10 (Excellent)

**What Made It Outstanding:**
1. **Pattern Reuse**: Extended Story 2.4's FailedMessageStore pattern for OfflineQueueStore
2. **Complete Code Examples**: Full SwiftUI implementations for all 5 new components
3. **Source Citations**: Every technical claim traced to architecture docs
4. **Comprehensive Testing**: 20 unit tests + integration test + manual checklist
5. **Clear Task Breakdown**: 16 tasks with 120+ detailed subtasks

**Single Minor Observation:**
- ChatViewModel property exposure (internal vs private) for OfflineQueueViewModel access
- Not a blocker - can be addressed during implementation

## Tab Naming Convention

**Standard:** `{agent} - Story {story}`

**Examples:**
- Dev agent working on Story 2.9: "Dev - Story 2.9"
- QA agent reviewing Story 2.5: "QA - Story 2.5"
- SM agent drafting Story 2.7: "SM - Story 2.7"
- PO agent validating Story 2.9: "PO - Story 2.9"

**Implementation:** Add `tabName: {Agent} - Story {story}` field to agent YAML config

## Validation Score Interpretation

| Score | Confidence | Recommendation |
|-------|-----------|----------------|
| 9.0-10.0 | HIGH | GO - Ready for immediate implementation |
| 7.0-8.9 | MEDIUM | CONDITIONAL GO - Address identified gaps first |
| 5.0-6.9 | LOW | NO GO - Substantial rework needed |
| < 5.0 | VERY LOW | NO GO - Return to SM agent for re-scoping |

## Common Validation Pitfalls

❌ **Skipping Anti-Hallucination Check**: Always verify technical claims exist in codebase
❌ **Accepting Placeholder Text**: "TBD" or "TODO" = incomplete story
❌ **Missing Code Examples**: "Create a view that shows..." without SwiftUI code
❌ **Orphan Acceptance Criteria**: AC without corresponding task = incomplete coverage
❌ **Vague File Paths**: "Add a file somewhere..." = dev agent confusion
❌ **Missing Performance Targets**: "Should be fast" = untestable requirement
❌ **No Task Dependencies**: Dev agent may implement in wrong order
❌ **Insufficient Testing**: < 70% coverage = quality gate failure

## Integration with Other Agents

**SM Agent (Bob):** Creates stories using `create-next-story` task
**PO Agent (Sarah):** Validates stories using `validate-next-story` task
**Dev Agent (James):** Implements approved stories following task sequence
**QA Agent (Quinn):** Reviews implementation against acceptance criteria

**Workflow:** Draft (SM) → Validate (PO) → Implement (Dev) → Test (QA) → Done

## Key Takeaways

✅ **Use 9-dimension validation framework for all story reviews**
✅ **Story 2.9 is a gold standard example (9.5/10 score)**
✅ **Anti-hallucination verification is non-negotiable**
✅ **Complete code examples prevent dev agent confusion**
✅ **Pattern reuse (like FailedMessageStore → OfflineQueueStore) saves time**
✅ **Tab naming should follow `{agent} - Story {story}` convention**
✅ **Validation score determines GO/NO-GO recommendation**

**Time saved by rigorous validation:** 4-6 hours (prevented mid-implementation rework and clarification cycles)
