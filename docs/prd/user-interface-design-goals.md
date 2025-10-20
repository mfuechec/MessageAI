# User Interface Design Goals

## Overall UX Vision

MessageAI delivers a familiar, WhatsApp-like messaging experience with native iOS polish and AI-powered intelligence. The interface prioritizes clarity and speed—users should be able to send messages, view history, and access AI features without cognitive overhead. The design follows iOS Human Interface Guidelines while leveraging MessageKit for professional chat UI components, ensuring a production-quality feel from day one.

The UX balances two modes: **focused communication** (traditional chat) and **intelligent insights** (AI aggregation). Core messaging feels immediate and distraction-free, with AI capabilities accessible contextually within conversations. A dedicated Insights tab aggregates cross-conversation AI features (action items, decisions, priority messages) for power users managing multiple teams. Push notifications leverage AI to summarize conversation activity since the user last opened the app, providing context before re-entry.

## Key Interaction Paradigms

**Primary Navigation:**
- Tab-based architecture with three main sections: **Conversations**, **Insights**, **Settings**
- Conversations list shows recent chats with preview, timestamp, and unread badges
- Insights tab aggregates AI-generated content across all conversations
- Tap conversation to enter full chat view
- Pull-to-refresh for manual sync

**Message Composition:**
- Standard iOS keyboard with text input bar at bottom
- Attachment button for images
- Send button becomes active when text is entered
- Long-press messages for contextual actions (edit, unsend, retry, copy)

**AI Feature Access (Hybrid Model):**

**In-Conversation (Contextual):**
- AI button in chat toolbar opens action menu:
  - "Summarize Thread" → Modal with summary
  - "Extract Action Items" → Modal with structured list
  - "Ask AI about this chat" → Chat-style Q&A interface
- Long-press individual messages for:
  - "Why is this priority?" (if flagged by AI)
  - "Add to decisions" (manual decision tagging)
- Smart search replaces standard search (AI-powered, natural language)

**Insights Tab (Aggregated):**
- All Action Items: Cross-conversation task dashboard with context links
- Priority Messages Inbox: Messages requiring attention from all conversations
- Recent Decisions: Tracked decisions with conversation context
- Proactive Suggestions: Meeting time suggestions, scheduling assistance

**Offline/Online Handling:**
- Persistent banner at top showing offline status
- Failed/queued messages have distinct visual treatment (gray, warning icon)
- Tap failed message to manually retry send
- Toast notification when connectivity restored: "Connected. Auto-send 5 messages? [Yes] [Review First]"

**Push Notifications with AI:**
- Notification includes AI-generated summary of conversation activity since last app open
- Example: "3 new messages from Design Team: Sarah shared wireframes, Mike approved v2, action item assigned to you"
- Long summary conversations (10+ messages) condensed to key points and questions directed at user
- Tap notification opens relevant conversation with summary banner at top for context

## Core Screens and Views

From a product perspective, these are the critical screens necessary to deliver the PRD values and goals:

**Core Messaging (MVP Phase 1):**
1. **Authentication Screen** - Email/password login and account creation
2. **Conversations List** - All active conversations with preview and status
3. **Chat View** - Full message thread with history, composition, and real-time updates
4. **New Conversation** - User search and conversation creation
5. **Profile Settings** - User profile editing (picture, name) and app settings
6. **Offline Message Queue** - View and manage messages pending send

**AI Features (Post-MVP):**
7. **Insights Dashboard** - Aggregated AI content across conversations (tab 2)
8. **Thread Summary Modal** - In-conversation AI-generated summary (minimal UI)
9. **Action Items Modal** - Extracted tasks from current conversation (minimal UI)
10. **AI Chat Interface** - Contextual Q&A about specific conversation (chat-style)
11. **Priority Message Detail** - Explanation of why message was flagged (minimal modal)
12. **Decision History View** - Tracked decisions with links to source conversations

## Accessibility: WCAG AA

The application will target WCAG AA compliance for iOS accessibility:
- Dynamic Type support for text scaling
- VoiceOver optimization for all interactive elements
- High contrast mode support
- Sufficient color contrast ratios (4.5:1 for normal text)
- Keyboard navigation where applicable
- Haptic feedback for AI processing completion

## Branding

Clean, professional design targeting B2B remote teams:
- Modern, minimal interface with generous whitespace
- iOS system colors with custom accent for AI features (suggestion: purple/indigo for AI differentiation)
- SF Symbols for iconography ensuring native feel
- Professional typography using San Francisco font family
- Subtle animations for state transitions (message sending, AI processing)
- **Dark Mode Support:** Full dark mode implementation following iOS system appearance
- AI elements visually distinct but not intrusive (subtle glow or icon indicators)

The visual language should communicate **reliability** (solid infrastructure) and **intelligence** (AI capabilities) without feeling overwhelming or gimmicky.

## Target Device and Platforms: iOS Mobile Only (Portrait)

- **Primary:** iPhone (iOS 15+)
- **Screen sizes:** iPhone SE to iPhone Pro Max
- **Orientation:** Portrait mode locked (no landscape support in MVP)
- **Deployment:** TestFlight for beta, eventual App Store distribution
- **Dark Mode:** Full support with automatic system appearance switching

Not targeting iPad or macOS in initial release—focus on mobile-first experience for remote professionals who primarily communicate on phones.

---
