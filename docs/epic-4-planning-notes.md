# Epic 4: Planning Notes

**Status:** Not yet scoped
**Theme:** Scaling & Enterprise Infrastructure (tentative)

---

## Deferred Stories from Epic 3

### Story 3.0: Organization/Workspace System

**Deferred from Epic 3** on 2025-10-22 by PO decision.

**Rationale for Deferral:**
- Not required for AI features to function
- Current user system (`getAllUsers()`) works for MVP and small-medium teams
- Reduces Epic 3 complexity and timeline
- Better suited for Epic 4 which can focus on scaling infrastructure

**Original Story Description:**

As a **user**,
I want **to belong to an organization/workspace where I can message other members**,
so that **I only see relevant contacts and can participate in team-based messaging at scale**.

**Key Acceptance Criteria:**
1. `Organization` entity created with: id, name, memberIds, createdAt, settings
2. User entity updated with `organizationIds: [String]` field (users can belong to multiple orgs)
3. Update `getAllUsers()` → `getUsersInOrganization(organizationId: String)` in UserRepository
4. Update `getOrCreateConversation()` to validate participants in same organization
5. Organization selection UI for users in multiple organizations (simple dropdown/picker)
6. Default organization auto-created for existing users (migration script)
7. Admin users can invite new users to organization (email invitation)
8. Organization settings: name, member management, permissions
9. Firestore security rules updated: Users can only query users in their organization(s)
10. Performance: User queries scoped to organization (< 100ms for 1000+ member orgs)
11. Conversation list filtered to conversations within current organization
12. Unit tests for organization-based user filtering
13. Integration test: User A in Org 1 cannot message User B in Org 2
14. Migration: Existing users assigned to "Default Organization"
15. Error handling: User without organization shown onboarding flow

**Complexity:** High
**Estimated Time:** 16 hours
**Risk:** Medium (data migration, schema changes)

**Full Details:** See `docs/prd/epic-3-core-ai-features-thread-intelligence.md` Story 3.0

---

## Potential Epic 4 Themes

**Option A: Scaling & Enterprise Infrastructure**
- Story 3.0 (Organization/Workspace System)
- Performance optimization for large message volumes
- Advanced caching strategies
- Analytics & usage monitoring
- Admin dashboard for organization management

**Option B: Advanced AI Features**
- Conversation insights dashboard
- AI-powered smart replies
- Meeting scheduling from conversation context
- Advanced search filters and saved searches

**Option C: Collaboration Enhancements**
- Video/voice calling
- Screen sharing
- Rich media embeds (links, videos)
- Message reactions and threading

---

## Notes

- Epic 4 scope to be determined after Epic 3 completion
- Story 3.0 should be prioritized in Epic 4 if user base grows beyond small teams
- Consider user feedback from Epic 3 AI features when planning Epic 4
