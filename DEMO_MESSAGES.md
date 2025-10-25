# Demo Message Generator - Quick Reference

## How to Use

In DEBUG builds, there's a **flask icon** (🧪) in the top-right toolbar of any conversation. Tap it to populate realistic demo messages.

## What It Does

The system **automatically detects** the conversation type and generates appropriate messages:

### 2-Person Conversation
**Scenario**: Product Manager + Engineer discussing a new feature implementation

**Generated Messages Include**:
- Feature planning discussion about implementing semantic search
- Technical decisions (choosing OpenAI embeddings API)
- Action items with deadlines ("Can you have the technical spec ready by Wednesday?")
- Priority issue (production search broken - immediate crisis)
- Crisis resolution
- Meeting scheduling discussion
- Project tracking requests

**Perfect for Demoing**:
- AI thread summaries (20+ messages spanning feature discussion)
- Action item extraction (5+ clear action items)
- Decision tracking (2-3 major decisions)
- Priority detection (production outage scenario)

---

### Group Conversation (3+ people)
**Scenario**: Team standup/project update with multiple participants

**Generated Messages Include**:
- Team standup kickoff and status updates
- Multiple action items assigned to different people
- Team decisions (PostgreSQL vs MongoDB, postponing launch)
- Priority issue (production API errors affecting customers)
- Meeting scheduling with multiple participants
- Budget decisions
- Wrap-up with action item tracking

**Perfect for Demoing**:
- AI thread summaries (longer conversation with multiple topics)
- Action item extraction (8+ action items across multiple people)
- Decision tracking (4+ team decisions)
- Priority detection (critical production issue)
- Meeting workflow (scheduling discussion)

---

## Demo Flow

### Part 1: Basic Messaging (30 seconds)
1. Open any conversation (existing messages are cleared automatically)
2. Tap the flask icon to populate demo messages
3. Show real-time message display scrolling to bottom
4. Type and send a new message to show optimistic UI

### Part 2: AI Features (3 minutes)
1. Tap the **✨ sparkles icon** to open AI Analysis
2. Show **AI Summary** tab (instant summary of 20+ messages)
3. Switch to **Action Items** tab (extracted tasks with assignees/deadlines)
4. Switch to **Decisions** tab (key decisions made)
5. If group conversation, tap a priority message to show navigation

### Part 3: Meeting Detection (30 seconds)
1. Scroll to meeting scheduling discussion
2. Show how AI detected the scheduling intent
3. (Future: Tap to create calendar event)

---

## Message Content Breakdown

### Action Items Generated
**2-Person Conversation**:
- "Can you have the technical spec ready by Wednesday?"
- "Set up a meeting with the data team"
- "Please add the project to Jira and create the epic"

**Group Conversation**:
- "Sarah, can you prepare the staging environment for testing by Friday?"
- "Mike - don't forget to update the API documentation before the client demo next Tuesday"
- "Everyone please submit your time logs by 5pm today"
- "I'll send out the meeting notes and action item list in Slack"

### Decisions Generated
**2-Person Conversation**:
- "We've decided to go with OpenAI's embeddings API"
- "Let's cache common searches. Maybe Redis with a 24-hour TTL?"

**Group Conversation**:
- "We've decided to go with PostgreSQL instead of MongoDB"
- "Team consensus: we're postponing the launch to next Monday"
- "Finalized the Q4 budget at $75K"

### Priority Messages
**2-Person Conversation**:
- "Our current search is completely broken in production. The Algolia index got corrupted somehow and users are getting zero results"

**Group Conversation**:
- "Production API is throwing 500 errors on checkout. Payment processor says 20+ customers affected in last 30 minutes"

---

## Technical Details

### Cloud Function: `populateTestMessages`
- **Location**: `functions/src/populateTestMessages.ts`
- **Auto-Detection**: Checks `participantIds.length >= 3` to determine group vs 2-person
- **Message Count**: 19-23 messages depending on conversation type
- **Timing**: Messages spread across ~1 hour (realistic timestamps)
- **Security**: Only callable by authenticated conversation participants
- **Cleanup**: Automatically deletes existing messages before populating

### Button Implementation
- **Location**: `ChatView.swift:175-189`
- **Icon**: Flask (🧪)
- **Label**: "Populate Test Messages"
- **Trigger**: `viewModel.populateTestMessages()` → calls Cloud Function
- **Only Available**: `#if DEBUG` builds

---

## Why Two Different Message Sets?

**2-Person conversations** feel different from group discussions:
- More back-and-forth dialogue
- Deeper technical discussion
- Personal pronouns ("I'll do this", "Can you...")
- Focus on a single feature/topic

**Group conversations** have different dynamics:
- Multiple voices and perspectives
- Coordination across people
- Status updates from different team members
- Broader range of topics
- Meeting scheduling with multiple attendees

The AI should handle both scenarios realistically, so we test with realistic data for each.

---

## Demo Tips

1. **Start fresh**: Tapping the flask icon clears existing messages automatically
2. **Show the contrast**: Demo both a 2-person and group conversation to show AI versatility
3. **Highlight smart caching**: Request the same summary twice - second time is instant (<1s)
4. **Natural language**: Point out there are no "ACTION:" or "DECISION:" labels - AI understands context
5. **Real scenarios**: Emphasize these are realistic work conversations, not "test message 1, test message 2"
