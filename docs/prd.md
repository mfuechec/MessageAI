# MessageAI Product Requirements Document (PRD)

## Goals and Background Context

### Goals

- Deliver production-quality messaging infrastructure meeting all Gauntlet MVP requirements with zero message loss and real-time synchronization across devices
- Build AI-powered features that solve real pain points for remote team professionals (thread overload, missed important messages, context switching)
- Implement testable Clean Architecture enabling rapid iteration, comprehensive test coverage, and maintainable codebase
- Identify and mitigate technical risks through test-first development and prototype validation before feature implementation
- Create a B2B-focused product with team subscription potential targeting distributed engineering teams
- Successfully complete Gauntlet AI bootcamp final project showcasing end-to-end mobile AI development with modern iOS patterns

### Background Context

Remote team professionals—software engineers, designers, and PMs in distributed teams—are drowning in message threads across multiple platforms. Critical decisions get buried in conversations, action items are forgotten, and constant context-switching destroys productivity. Existing solutions like Slack and Teams add features but don't fundamentally solve the information overload problem.

MessageAI addresses this by combining WhatsApp-level messaging reliability with AI-powered intelligence. The app will help remote teams surface what matters, extract decisions and action items automatically, and proactively assist with coordination. This project follows the "golden path" tech stack (Swift + Firebase) recommended for rapid mobile development, allowing focus on product differentiation through AI features rather than infrastructure complexity.

The MVP is structured in two phases: **Phase 1** focuses on building all required infrastructure and features with functional completeness, while **Phase 2** polishes the infrastructure for optimal message delivery speed and reliability under various network conditions. This approach ensures a solid foundation before layering AI capabilities. Quality is defined quantifiably: zero message loss, real-time delivery between online users, graceful offline/online transitions, and message persistence across app restarts. Testing precedes implementation—comprehensive test suites will be reviewed and approved before feature development begins, ensuring architectural decisions are validated early.

### Change Log

| Date | Version | Description | Author |
|------|---------|-------------|---------|
| 2025-10-20 | 1.0 | Initial PRD created through PM agent brainstorming session | PM Agent (John) |

---

## Requirements

### Functional Requirements

**Core Messaging Infrastructure (MVP Phase 1)**

- **FR1:** The system shall support one-on-one chat functionality allowing two users to exchange text messages in real-time
- **FR2:** The system shall deliver messages to online recipients in real-time (< 2 seconds under normal network conditions)
- **FR3:** The system shall persist all messages locally and in the cloud, ensuring chat history survives app restarts
- **FR4:** The system shall implement optimistic UI updates, displaying sent messages immediately before server confirmation
- **FR5:** The system shall display online/offline status indicators for all conversation participants
- **FR6:** The system shall display timestamps for all messages in human-readable format (relative and absolute)
- **FR7:** The system shall provide user authentication with email/password using Firebase Auth
- **FR8:** The system shall support basic group chat functionality with 3 or more users in a single conversation
- **FR9:** The system shall implement message read receipts showing when messages have been read by recipients
- **FR10:** The system shall deliver push notifications for new messages when the app is in foreground or background
- **FR11:** The system shall support sending and receiving image attachments in conversations
- **FR12:** The system shall display user profile pictures and display names in all conversation contexts
- **FR13:** The system shall show typing indicators when conversation participants are actively composing messages
- **FR14:** The system shall track message delivery states (sending, sent, delivered, read) and display them to users
- **FR15:** The system shall allow users to edit previously sent messages with edit history visible to all participants
- **FR16:** The system shall provide unsend functionality allowing users to delete messages from all participants' views
- **FR17:** The system shall provide manual retry functionality for messages that fail to send with visible failure indication

**Offline Support (MVP Phase 1)**

- **FR18:** The system shall queue messages composed while offline with clear visual indication that they are not yet sent
- **FR19:** The system shall allow users to manually send queued offline messages when connectivity is available
- **FR20:** The system shall allow users to view their complete chat history while offline using cached data
- **FR21:** The system shall handle poor network conditions (3G, packet loss) gracefully without data loss
- **FR22:** The system shall notify users when connectivity is restored and show count of pending messages ready to send

**AI Features for Remote Team Professional (Post-MVP)**

- **FR23:** The system shall provide thread summarization, condensing long conversations into key points and decisions
- **FR24:** The system shall extract action items from conversations and present them as a structured list with assignees
- **FR25:** The system shall implement smart search allowing users to find messages using natural language queries
- **FR26:** The system shall detect and highlight priority messages requiring user attention or response
- **FR27:** The system shall track decisions made in conversations and provide decision history view
- **FR28:** The system shall implement a proactive assistant that auto-suggests meeting times based on conversation context
- **FR29:** The system shall detect scheduling needs in messages and proactively offer coordination assistance

**User Management**

- **FR30:** The system shall allow users to create accounts with email and password
- **FR31:** The system shall enable users to set and update their profile picture and display name
- **FR32:** The system shall provide a contacts/user search interface to find and start conversations

**Future Considerations (Post-MVP Stretch Goals)**

- **FR33 (Stretch):** The system may integrate with Jira to link conversations with existing tickets and add comments
- **FR34 (Stretch):** The system may allow creation of new Jira tickets directly from conversation context
- **FR35 (Stretch):** The system may provide user blocking and conversation management features
- **FR36 (Stretch):** The system may implement analytics and telemetry for measuring AI feature usage and engagement

### Non-Functional Requirements

**Performance (MVP Phase 2 Focus)**

- **NFR1:** The system shall never lose messages under any network conditions (zero message loss guarantee)
- **NFR2:** The system shall deliver messages to online users within 2 seconds under normal network conditions
- **NFR3:** The system shall handle rapid-fire messaging (20+ messages sent quickly) without performance degradation
- **NFR4:** The system shall load conversation history (last 50 messages) within 1 second on app launch
- **NFR5:** The system shall support conversations with 10,000+ messages without UI performance issues

**Reliability & Availability**

- **NFR6:** The system shall ensure message delivery even if the app crashes mid-send through persistent queuing
- **NFR7:** The system shall gracefully handle Firebase service interruptions with local caching and retry logic
- **NFR8:** The system shall maintain data consistency across multiple devices for the same user account

**Security**

- **NFR9:** The system shall store all Firebase API credentials securely in iOS Keychain, never in source code
- **NFR10:** The system shall use Firebase Security Rules to ensure users can only access their own conversations
- **NFR11:** The system shall encrypt all network communication using HTTPS/TLS via Firebase SDK

**Testability**

- **NFR12:** The system shall implement Clean Architecture (MVVM) enabling unit testing of business logic without UI dependencies
- **NFR13:** The system shall use repository pattern allowing mock implementations for testing without Firebase connections
- **NFR14:** The system shall achieve minimum 70% code coverage for business logic and data layers before feature development proceeds

**Usability**

- **NFR15:** The system shall follow iOS Human Interface Guidelines for native look and feel
- **NFR16:** The system shall use SwiftUI for declarative UI implementation with live preview support
- **NFR17:** The system shall integrate MessageKit for professional chat UI components reducing custom UI development

**Scalability & Cost**

- **NFR18:** The system shall optimize Firebase usage to remain within free tier limits during development and initial testing
- **NFR19:** The system shall implement efficient Firestore queries minimizing read/write operations and costs
- **NFR20:** The system shall use Firebase offline persistence to reduce redundant network requests

**AI Integration**

- **NFR21:** The system shall call AI services (OpenAI/Anthropic) via Firebase Cloud Functions to protect API keys from client exposure
- **NFR22:** The system shall implement caching for AI-generated content (summaries, action items) to minimize redundant LLM calls
- **NFR23:** The system shall handle AI service failures gracefully, degrading features without breaking core messaging

**Development & Deployment**

- **NFR24:** The system shall use Swift Package Manager for dependency management
- **NFR25:** The system shall support deployment via TestFlight for beta testing
- **NFR26:** The system shall maintain separation between development and production Firebase environments

---

## User Interface Design Goals

### Overall UX Vision

MessageAI delivers a familiar, WhatsApp-like messaging experience with native iOS polish and AI-powered intelligence. The interface prioritizes clarity and speed—users should be able to send messages, view history, and access AI features without cognitive overhead. The design follows iOS Human Interface Guidelines while leveraging MessageKit for professional chat UI components, ensuring a production-quality feel from day one.

The UX balances two modes: **focused communication** (traditional chat) and **intelligent insights** (AI aggregation). Core messaging feels immediate and distraction-free, with AI capabilities accessible contextually within conversations. A dedicated Insights tab aggregates cross-conversation AI features (action items, decisions, priority messages) for power users managing multiple teams. Push notifications leverage AI to summarize conversation activity since the user last opened the app, providing context before re-entry.

### Key Interaction Paradigms

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

### Core Screens and Views

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

### Accessibility: WCAG AA

The application will target WCAG AA compliance for iOS accessibility:
- Dynamic Type support for text scaling
- VoiceOver optimization for all interactive elements
- High contrast mode support
- Sufficient color contrast ratios (4.5:1 for normal text)
- Keyboard navigation where applicable
- Haptic feedback for AI processing completion

### Branding

Clean, professional design targeting B2B remote teams:
- Modern, minimal interface with generous whitespace
- iOS system colors with custom accent for AI features (suggestion: purple/indigo for AI differentiation)
- SF Symbols for iconography ensuring native feel
- Professional typography using San Francisco font family
- Subtle animations for state transitions (message sending, AI processing)
- **Dark Mode Support:** Full dark mode implementation following iOS system appearance
- AI elements visually distinct but not intrusive (subtle glow or icon indicators)

The visual language should communicate **reliability** (solid infrastructure) and **intelligence** (AI capabilities) without feeling overwhelming or gimmicky.

### Target Device and Platforms: iOS Mobile Only (Portrait)

- **Primary:** iPhone (iOS 15+)
- **Screen sizes:** iPhone SE to iPhone Pro Max
- **Orientation:** Portrait mode locked (no landscape support in MVP)
- **Deployment:** TestFlight for beta, eventual App Store distribution
- **Dark Mode:** Full support with automatic system appearance switching

Not targeting iPad or macOS in initial release—focus on mobile-first experience for remote professionals who primarily communicate on phones.

---

## Technical Assumptions

### Repository Structure: Monorepo

Single Git repository containing the complete iOS application with clear separation of concerns through folder structure:

```
MessageAI/
├── MessageAI/ (Xcode project)
│   ├── App/ (AppDelegate, SceneDelegate, DI)
│   ├── Domain/ (Entities, UseCases, Repository Protocols)
│   ├── Data/ (Firebase Services, Repository Implementations)
│   ├── Presentation/ (ViewModels, Views, UI Components)
│   └── Tests/ (Unit, Integration Tests)
├── docs/ (PRD, Architecture, Stories)
└── .bmad-core/ (BMAD workflow files)
```

**Rationale:** iOS projects naturally fit monorepo structure. No need for polyrepo complexity with a single mobile client.

### Service Architecture

**Clean Architecture (MVVM) with Firebase Backend:**

```
Presentation Layer (SwiftUI + ViewModels)
    ↓
Domain Layer (Use Cases + Repository Protocols)
    ↓
Data Layer (Firebase Repositories + Services)
    ↓
External Services (Firebase, OpenAI/Anthropic)
```

**Key Architectural Decisions:**

1. **Clean Architecture (MVVM Pattern):**
   - `Domain/Entities/`: Pure Swift models (Message, User, Conversation, etc.)
   - `Domain/UseCases/`: Business logic (SendMessageUseCase, SummarizeThreadUseCase, etc.)
   - `Domain/Repositories/`: Protocol definitions for data access
   - `Data/Repositories/`: Concrete implementations (FirebaseMessageRepository)
   - `Data/Network/`: Service layer (FirebaseService, OpenAIService)
   - `Presentation/`: ViewModels + SwiftUI Views

2. **Dependency Injection:**
   - DIContainer manages all dependencies
   - Repositories injected into ViewModels
   - Easy to swap implementations (Firebase → Mock for testing)

3. **Backend: Firebase Serverless:**
   - **Firestore:** Real-time database for messages, users, conversations
   - **Firebase Auth:** User authentication
   - **Cloud Functions:** AI service calls (protects API keys), push notification generation
   - **Firebase Cloud Messaging (FCM):** Push notifications
   - **Firebase Storage:** Image attachments

4. **Data Persistence Strategy:**
   - **Primary:** Firebase Firestore with offline persistence enabled
   - **Keychain:** Secure storage for OpenAI/Anthropic API keys
   - **CoreData:** NOT in MVP; evaluate on Day 3 if smart search performance requires it
   - **Rationale:** Firebase offline caching sufficient for MVP. CoreData adds complexity but may be needed for fast local search queries.

5. **AI Integration Architecture:**
   - **Client → Cloud Function → LLM API → Client**
   - Cloud Functions protect API keys from client exposure
   - URLSession for direct API calls only in development (testing)
   - Caching layer for AI results (summaries, action items) to minimize costs

6. **Real-Time Communication:**
   - Firestore snapshot listeners for real-time message updates
   - Presence system using Firestore onDisconnect triggers
   - Optimistic UI updates with local state management

### Testing Requirements

**Test-First Development Approach (CRITICAL):**

**Philosophy:** Tests written and reviewed BEFORE implementation begins. This validates architectural decisions early and ensures code is testable from the start.

**Testing Pyramid:**

1. **Unit Tests (70% coverage minimum for Domain + Data layers):**
   - All Use Cases fully tested with mocked repositories
   - Repository implementations tested with mocked Firebase
   - ViewModel logic tested in isolation
   - **Tools:** XCTest, Swift Testing framework
   - **Coverage Gate:** No feature development proceeds without approved tests

2. **Integration Tests:**
   - Repository → Firebase interaction (using Firebase Emulator)
   - ViewModel → Use Case → Repository flow
   - Message sending/receiving end-to-end
   - Offline → Online transition scenarios
   - **Tools:** XCTest, Firebase Local Emulator Suite

3. **UI Tests (Selective):**
   - Critical user flows: login, send message, view conversation
   - Offline message queue interaction
   - AI feature button interactions
   - **Tools:** XCTest UI Testing

4. **Manual Testing Scenarios:**
   - Two physical devices for real-time messaging validation
   - Network interruption testing (airplane mode toggles)
   - Push notification delivery verification
   - AI feature output quality assessment

**Test Review Process:**
- Tests written for each story before implementation
- Developer reviews test coverage and scenarios
- Tests must pass before story marked "Done"
- QA agent reviews test quality and coverage

### Additional Technical Assumptions and Requests

**Frontend Technology:**
- **Language:** Swift 5.9+
- **UI Framework:** SwiftUI (primary), MessageKit (chat UI components)
- **Minimum iOS:** iOS 15.0+
- **Deployment:** TestFlight for beta distribution
- **Dependency Management:** Swift Package Manager (SPM)

**Key Libraries and Dependencies:**
- **MessageKit:** Professional chat UI components (bubbles, input bar, typing indicators)
- **Firebase iOS SDK:** Complete Firebase suite (Auth, Firestore, Functions, Messaging, Storage)
- **Kingfisher or SDWebImageSwiftUI:** Async image loading for profile pictures and attachments
- **SwiftUI System:** Native UI components, no third-party UI frameworks beyond MessageKit

**Development Tools:**
- **IDE:** Xcode 15+
- **Version Control:** Git + GitHub
- **CI/CD:** Not required for MVP; manual TestFlight uploads acceptable
- **Firebase Console:** Development and production project separation

**API and External Services:**
- **LLM Provider:** OpenAI GPT-4 OR Anthropic Claude (to be selected based on API access)
- **AI Features:** Implemented via function calling / tool use
- **Rate Limiting:** Conservative LLM call frequency to manage costs
- **Error Handling:** Graceful degradation when AI services unavailable

**Security Considerations:**
- **API Keys:** Stored in iOS Keychain, never hardcoded
- **Firebase Security Rules:** Enforced at database level (users access only their conversations)
- **HTTPS/TLS:** All network communication encrypted via Firebase SDK
- **Authentication:** Firebase Auth tokens with automatic refresh
- **No sensitive data in logs:** Production builds strip debug logging

**Performance Targets:**
- **Message delivery:** < 2 seconds for online users under normal conditions
- **App launch:** < 1 second to conversations list
- **Conversation load:** Last 50 messages in < 1 second
- **AI response time:** 2-10 seconds acceptable with loading indicators
- **Offline queue:** No limit on queued messages

**Cost Management:**
- **Firebase Free Tier Target:** Optimize queries to stay within free tier during development
- **LLM Cost Control:** Cache AI results aggressively, implement request throttling
- **Firestore Optimization:** Efficient queries, pagination for large conversations
- **Storage Optimization:** Image compression before upload

**Data Model Assumptions:**
- **Message Structure:** id, text, senderId, conversationId, timestamp, status, editHistory, attachments
- **Conversation Structure:** id, participantIds, lastMessage, lastMessageTime, unreadCounts
- **User Structure:** id, email, displayName, profileImageURL, online, lastSeen
- **AI Results Caching:** Separate collections for summaries, action items, decisions

**Development Environment:**
- **Firebase Projects:** Separate dev and prod projects
- **Testing Data:** Mock conversations and users for development
- **Device Testing:** Physical iPhone required for push notifications and real-time testing
- **Simulator:** Acceptable for UI development and unit testing

**Architectural Flexibility Points:**
- **CoreData Integration:** Decision deferred to Day 3 based on search performance
- **LLM Provider:** Flexible between OpenAI and Anthropic based on API access
- **Message Attachments:** MVP supports images only; video/file support post-MVP
- **Group Chat Limit:** Start with 10 participants max; scale later if needed

**Known Constraints:**
- **Timeline:** 7-day sprint with MVP gate at day 2
- **Learning Curve:** Developer learning Swift during development
- **Single Developer:** All work solo; architecture must support rapid iteration
- **Bootcamp Evaluation:** Must demonstrate all 5 AI features + 1 advanced capability

---

## Epic List

**Epic 1: Foundation & Core Messaging Infrastructure**
Establish project setup with Clean Architecture, Firebase integration, authentication, and basic one-on-one text messaging with real-time delivery and persistence. This foundational epic accounts for Swift learning curve and includes comprehensive test framework setup.

**Epic 2: Complete MVP with Reliability**
Implement all remaining MVP Phase 1 & Phase 2 requirements including group chat, message states (edit/unsend/retry), read receipts, typing indicators, image attachments, offline message handling, and performance optimization. Each story includes reliability acceptance criteria ensuring zero message loss and optimized delivery under various network conditions. Regression test suite established.

**Epic 3: Core AI Features - Thread Intelligence**
Integrate AI-powered thread summarization, action item extraction, and smart search capabilities accessible contextually within conversations. Cloud Functions implemented for secure AI service calls. AI quality acceptance criteria defined and validated.

**Epic 4: Core AI Features - Priority & Decision Tracking**
Implement priority message detection, decision tracking system, and the Insights dashboard for cross-conversation AI aggregation. Regression testing ensures core messaging remains stable with AI features active.

**Epic 5: Advanced AI - Proactive Assistant**
Build proactive scheduling assistant that detects coordination needs, suggests meeting times, and delivers AI-summarized push notifications. Minimum viable scope defined with stretch goals for additional intelligence.

---

## Epic 1: Foundation & Core Messaging Infrastructure

### Epic 1 Goal

Establish a production-ready iOS project with Clean Architecture (MVVM), integrate Firebase for real-time messaging and authentication, and deliver functional one-on-one text chat with message persistence and real-time delivery. This epic prioritizes architectural soundness and testability, setting the foundation for all subsequent features. Expected timeline: 1.5 days accounting for Swift learning curve and initial project setup.

### Story 1.1: Project Setup & Clean Architecture Foundation

As a **developer**,  
I want **a well-structured Xcode project with Clean Architecture folders and dependency injection**,  
so that **the codebase is maintainable, testable, and follows best practices from day one**.

#### Acceptance Criteria

1. Xcode project created with Swift 5.9+ targeting iOS 15+
2. Folder structure implements Clean Architecture layers:
   - `App/` (AppDelegate, SceneDelegate, DIContainer)
   - `Domain/Entities/` (pure Swift models)
   - `Domain/UseCases/` (business logic protocols)
   - `Domain/Repositories/` (repository protocols)
   - `Data/Repositories/` (concrete implementations)
   - `Data/Network/` (service layer)
   - `Presentation/ViewModels/` (view models)
   - `Presentation/Views/` (SwiftUI views)
   - `Tests/` (unit and integration tests)
3. DIContainer created with dependency injection setup
4. Swift Package Manager configured as dependency manager
5. `.gitignore` configured for Xcode projects
6. Git repository initialized with initial commit
7. Dark mode support enabled in project settings
8. Portrait orientation locked in project configuration
9. Basic `README.md` created documenting project structure
10. Project builds successfully on simulator and physical device

### Story 1.2: Firebase Integration & Configuration

As a **developer**,  
I want **Firebase integrated with separate development and production environments**,  
so that **I can use Firebase services safely without affecting production data**.

#### Acceptance Criteria

1. Firebase projects created (development and production)
2. Firebase iOS SDK added via Swift Package Manager
3. `GoogleService-Info.plist` files configured for dev and prod
4. Firestore database initialized with security rules restricting access by user ID
5. Firebase Auth enabled with email/password provider
6. Firebase Cloud Messaging (FCM) configured for push notifications
7. Firebase Storage enabled for future image attachments
8. Firestore offline persistence enabled in code
9. Firebase configuration loads correctly on app launch
10. Connection to Firestore verified with test write and read
11. All Firebase API keys and sensitive data excluded from git via `.gitignore`
12. Development environment selected by default (production switch documented)

### Story 1.3: Domain Models & Repository Protocols

As a **developer**,  
I want **core domain entities and repository protocols defined**,  
so that **business logic is decoupled from data sources and follows Clean Architecture principles**.

#### Acceptance Criteria

1. `Message` entity created with properties: id, text, senderId, conversationId, timestamp, status (sending/sent/delivered/read), editHistory (optional), attachments (optional)
2. `User` entity created with properties: id, email, displayName, profileImageURL (optional), isOnline, lastSeen
3. `Conversation` entity created with properties: id, participantIds, lastMessage, lastMessageTimestamp, unreadCounts (per user)
4. `MessageRepositoryProtocol` defined with methods: sendMessage, observeMessages, getMessages, updateMessageStatus, editMessage, deleteMessage
5. `UserRepositoryProtocol` defined with methods: getUser, updateUser, observeUserPresence
6. `ConversationRepositoryProtocol` defined with methods: getConversation, createConversation, observeConversations, updateUnreadCount
7. `AuthRepositoryProtocol` defined with methods: signIn, signUp, signOut, getCurrentUser, observeAuthState
8. All protocols use async/await Swift concurrency patterns
9. Entity models are pure Swift with no external dependencies (Codable, Equatable, Identifiable)
10. Unit tests written for entity model behavior (equality, encoding/decoding)

### Story 1.4: Firebase Repository Implementations

As a **developer**,  
I want **concrete Firebase repository implementations**,  
so that **the app can interact with Firebase services while remaining testable through protocol abstractions**.

#### Acceptance Criteria

1. `FirebaseMessageRepository` implements `MessageRepositoryProtocol`
2. `FirebaseUserRepository` implements `UserRepositoryProtocol`
3. `FirebaseConversationRepository` implements `ConversationRepositoryProtocol`
4. `FirebaseAuthRepository` implements `AuthRepositoryProtocol`
5. All repositories use Firestore SDK with proper error handling
6. Real-time listeners implemented using Firestore snapshots (AsyncStream or Combine)
7. Repository implementations handle offline scenarios gracefully
8. Each repository has corresponding unit tests using mocked Firestore responses
9. DIContainer updated to provide repository instances
10. Firestore collection structure documented: `users/`, `conversations/`, `messages/`
11. Timestamp handling uses Firebase server timestamps for consistency
12. All Firestore operations include proper error logging

### Story 1.5: Authentication UI & Flow

As a **user**,  
I want **to create an account and sign in with email/password**,  
so that **I can access the messaging app with a secure personal account**.

#### Acceptance Criteria

1. `AuthView` created with SwiftUI showing login and signup modes
2. Email and password text fields with appropriate keyboard types and secure entry
3. "Sign In" and "Sign Up" buttons with loading states during authentication
4. `AuthViewModel` implements authentication logic using `AuthRepositoryProtocol`
5. Successful authentication navigates to conversations list
6. Authentication errors displayed to user with helpful messages (invalid email, weak password, account exists, etc.)
7. Form validation: email format check, password minimum length (6 characters)
8. "Switch to Sign Up" / "Switch to Sign In" toggle between modes
9. Authentication state persisted (Firebase Auth handles automatic re-login)
10. Unit tests for `AuthViewModel` cover success and failure scenarios
11. Dark mode styling verified on AuthView
12. VoiceOver accessibility labels added to all interactive elements

### Story 1.6: User Profile Setup

As a **user**,  
I want **to set my display name after creating an account**,  
so that **other users can identify me in conversations**.

#### Acceptance Criteria

1. `ProfileSetupView` shown immediately after successful sign-up
2. Display name text field with character limit (50 characters)
3. Optional profile picture selection (photo library access)
4. "Continue" button saves profile data to Firestore `users/` collection
5. `ProfileSetupViewModel` uses `UserRepositoryProtocol` to update user
6. User document created in Firestore with id matching Firebase Auth UID
7. Profile setup can be skipped (default display name: email prefix)
8. Loading state during profile save
9. Error handling if profile save fails (retry option)
10. Navigation to conversations list after successful profile setup
11. Unit tests for `ProfileSetupViewModel`
12. Dark mode and accessibility verified

### Story 1.7: Conversations List UI

As a **user**,  
I want **to see a list of my conversations**,  
so that **I can quickly access ongoing chats**.

#### Acceptance Criteria

1. `ConversationsListView` displays all conversations for current user
2. `ConversationsListViewModel` observes conversations using `ConversationRepositoryProtocol`
3. Each conversation row shows: participant name(s), last message preview, timestamp, unread count badge
4. Empty state displayed when no conversations exist ("Start a new conversation")
5. Pull-to-refresh gesture for manual sync
6. Tap conversation navigates to chat view
7. Navigation bar with title "Messages" and "New Conversation" button
8. Real-time updates when new messages arrive (conversation list reorders)
9. Loading state while initial conversations load
10. Offline indicator banner displayed when no network connectivity
11. Conversations sorted by most recent message first
12. Unit tests for `ConversationsListViewModel` with mocked data
13. Dark mode styling verified
14. Smooth scrolling performance with 50+ conversations

### Story 1.8: One-on-One Chat View with Real-Time Messaging

As a **user**,  
I want **to send and receive text messages in real-time within a conversation**,  
so that **I can communicate instantly with another user**.

#### Acceptance Criteria

1. `ChatView` displays messages for selected conversation using MessageKit
2. `ChatViewModel` observes messages using `MessageRepositoryProtocol`
3. Message composition bar with text input and send button
4. Send button sends message via `MessageRepositoryProtocol.sendMessage`
5. Optimistic UI: Sent message appears immediately with "sending" status indicator
6. Real-time updates: Received messages appear instantly via Firestore listener
7. Messages display sender name (or "You"), timestamp, and message text
8. Message bubbles styled differently for current user vs other participants
9. Auto-scroll to bottom when new messages arrive or user sends message
10. Pull-to-load-more for older messages (pagination)
11. Loading state while initial messages load
12. Empty state for new conversations ("Say hello!")
13. Keyboard handling: Input bar stays above keyboard, scroll adjusts
14. Offline indicator banner in chat view
15. Unit tests for `ChatViewModel` message sending and receiving flows
16. Integration test: Send message from User A, verify User B receives it in real-time
17. Dark mode styling applied to chat bubbles and input bar
18. MessageKit customization matches app design (colors, fonts, spacing)

### Story 1.9: Message Persistence & Offline Viewing

As a **user**,  
I want **to view my conversation history even when offline**,  
so that **I can reference past messages without an internet connection**.

#### Acceptance Criteria

1. Firestore offline persistence enabled in Firebase configuration
2. Messages cached locally by Firestore SDK automatically
3. Chat view loads cached messages when offline (no network calls)
4. Offline banner displays: "You're offline. Messages will send when connected."
5. User can scroll through entire cached conversation history while offline
6. Conversations list shows cached data when offline
7. Timestamp indicators show relative time ("2 hours ago") for offline context
8. Integration test: Load conversation online, go offline (airplane mode), verify messages still visible
9. Integration test: App killed and restarted offline, verify cached data loads
10. No errors or crashes when accessing data offline
11. Smooth UX: No loading spinners for cached data

### Story 1.10: Test Framework & Initial Test Suite

As a **developer**,  
I want **a comprehensive test framework with initial unit and integration tests**,  
so that **code quality is validated before proceeding and all future code follows test-first approach**.

#### Acceptance Criteria

1. XCTest framework configured with test targets
2. Unit test suite created covering:
   - All ViewModels (AuthViewModel, ProfileSetupViewModel, ConversationsListViewModel, ChatViewModel)
   - All Use Cases (if extracted)
   - Repository protocol mocks for testing
3. Integration test suite created covering:
   - Firebase authentication flow
   - Message sending and receiving between two users
   - Offline data persistence
4. Test coverage measured: Minimum 70% for Domain and Data layers
5. Tests run successfully in CI-compatible mode (Firebase Emulator for integration tests optional, can use real dev Firebase)
6. `MockMessageRepository`, `MockUserRepository`, `MockAuthRepository` created for ViewModel testing
7. All tests pass before story marked done
8. Test documentation added to README: How to run tests, what's covered
9. GitHub Actions or manual test run script provided
10. Performance baseline established: Message send < 2 seconds on simulator

---

## Epic 2: Complete MVP with Reliability

### Epic 2 Goal

Complete all Gauntlet MVP Phase 1 and Phase 2 requirements including group chat, advanced message features (edit/unsend/retry), read receipts, typing indicators, image attachments, offline message management, and push notifications. Each feature is built with reliability and performance criteria ensuring zero message loss and optimized delivery under various network conditions. Regression test suite established to validate stability as features are added. Expected timeline: 1.5 days.

### Story 2.1: Group Chat Functionality

As a **user**,  
I want **to create and participate in group conversations with 3 or more people**,  
so that **I can coordinate with my entire team in one place**.

#### Acceptance Criteria

1. "New Conversation" flow supports selecting multiple participants (3-10 users)
2. Group conversation created in Firestore with all participant IDs
3. Group chat view displays all participants' names in navigation bar
4. Messages in group chat show sender name for all messages (not just "You" vs "Them")
5. All participants receive real-time message updates via Firestore listeners
6. Group conversation appears in conversations list for all participants
7. Unread counts tracked per participant in group
8. Tap participant names in nav bar to view group member list
9. Message delivery works reliably for all group sizes (tested up to 10 participants)
10. Performance: Messages appear within 2 seconds for all online participants
11. Reliability: Messages delivered to all participants even if some are offline (queued for delivery)
12. Unit tests for group conversation creation and message distribution logic
13. Integration test: 3 users in group, User A sends message, verify Users B and C receive it
14. Regression test: Verify one-on-one chat still works after group chat implementation

### Story 2.2: Message Editing with History

As a **user**,  
I want **to edit messages I've already sent**,  
so that **I can correct typos or clarify my meaning**.

#### Acceptance Criteria

1. Long-press message bubble shows contextual menu with "Edit" option (only for own messages)
2. Edit mode opens text field with current message content pre-filled
3. "Save" button updates message in Firestore with edit timestamp
4. Edited messages display "(edited)" indicator next to timestamp
5. Message edit history stored in Firestore (array of {text, timestamp} objects)
6. Tap "(edited)" indicator shows edit history modal with all versions
7. Real-time updates: All participants see edited message immediately
8. Editing works offline: Edit queued and synced when connection restored
9. Message entity updated with `editHistory` array and `isEdited` boolean
10. MessageRepository protocol extended with `editMessage` method
11. Performance: Edit appears instantly with optimistic UI, confirmed within 2 seconds
12. Reliability: Edit conflicts handled (if edited offline on multiple devices, last write wins with timestamp)
13. Unit tests for edit message logic in ViewModel and Repository
14. Integration test: User A edits message, User B sees update in real-time
15. Regression test: Message sending still works after edit implementation

### Story 2.3: Message Unsend (Delete for Everyone)

As a **user**,  
I want **to delete messages I've sent from everyone's view**,  
so that **I can remove messages sent by mistake**.

#### Acceptance Criteria

1. Long-press message bubble shows "Unsend" option (only for own messages within 24 hours)
2. Confirmation alert: "Delete this message for everyone?"
3. Unsend action deletes message from Firestore or marks as deleted
4. Deleted messages show placeholder: "[Message deleted]" for all participants
5. Real-time updates: All participants see deletion immediately
6. Message data removed from database (privacy), only placeholder remains
7. Unsending works offline: Delete queued and synced when connected
8. MessageRepository protocol extended with `deleteMessage` method
9. Performance: Deletion appears instantly (optimistic UI), confirmed within 2 seconds
10. Reliability: Deletion works even if some participants offline (applied when they sync)
11. Edge case: Deleted messages removed from conversation preview in conversations list
12. Unit tests for delete message logic
13. Integration test: User A deletes message, User B sees "[Message deleted]"
14. Regression test: Edit and send functionality still work after unsend implementation

### Story 2.4: Message Send Retry on Failure

As a **user**,  
I want **to manually retry sending messages that failed**,  
so that **I have control over when failed messages are resent**.

#### Acceptance Criteria

1. Messages that fail to send display with red warning icon and "Failed" status
2. Tap failed message shows alert: "Message failed to send. [Retry] [Delete]"
3. Retry button attempts to resend message via repository
4. Delete button removes message from local queue permanently
5. Failed messages persist locally (not lost on app restart)
6. Message status enum includes: sending, sent, delivered, read, failed
7. ViewModel tracks failed messages and provides retry action
8. Performance: Retry attempt completes within 3 seconds or marks failed again
9. Reliability: Failed messages stored in local queue, never lost
10. Network error types handled gracefully (timeout, no connection, Firebase error)
11. Unit tests for retry logic in ViewModel
12. Integration test: Force network failure, send message, verify failure state, restore network, retry, verify success
13. Regression test: Normal message sending still works reliably

### Story 2.5: Read Receipts

As a **user**,  
I want **to see when my messages have been read by others**,  
so that **I know if my message has been seen**.

#### Acceptance Criteria

1. Message status updates to "read" when recipient views the chat containing the message
2. Read receipts displayed as small checkmarks: ✓ (sent), ✓✓ (delivered), ✓✓ (blue, read)
3. Message entity includes `readBy` array tracking user IDs who have read
4. Repository method `markMessagesAsRead` updates Firestore when user views chat
5. Real-time updates: Sender sees read receipt immediately when recipient opens chat
6. Group chat read receipts show count: "Read by 2 of 3"
7. Tap read receipt in group chat shows list of who has read
8. Read status updates work offline: Queued and synced when connected
9. Performance: Read receipts appear within 1 second of recipient opening chat
10. Reliability: Read status never downgrades (read → delivered), only upgrades
11. Unit tests for read receipt logic
12. Integration test: User A sends message to User B, User B opens chat, User A sees read receipt
13. Regression test: Message delivery and editing still work with read receipts active

### Story 2.6: Typing Indicators

As a **user**,  
I want **to see when someone is typing in a conversation**,  
so that **I know to wait for their response**.

#### Acceptance Criteria

1. Typing indicator appears below last message when participant is actively typing
2. Indicator shows: "[Name] is typing..." (one-on-one) or "[Name], [Name] are typing..." (group)
3. Firestore document tracks typing state per user per conversation (ephemeral data)
4. Typing state set to true when user types, false after 3 seconds of inactivity or on send
5. Real-time updates: Typing indicators appear within 500ms for recipients
6. Typing state cleared when user leaves chat view
7. Performance: Typing updates throttled (max 1 update per second) to reduce Firestore writes
8. Reliability: Typing state automatically cleared after timeout (prevents stuck "is typing")
9. MessageKit integrated typing indicator UI used (if available) or custom SwiftUI component
10. Unit tests for typing state management logic
11. Integration test: User A types, User B sees typing indicator within 1 second
12. Performance test: Typing updates don't cause lag in message composition
13. Regression test: Message sending, editing, and real-time updates still performant

### Story 2.7: Image Attachments

As a **user**,  
I want **to send and receive images in conversations**,  
so that **I can share visual information with my team**.

#### Acceptance Criteria

1. Attachment button in message input bar opens photo library picker
2. Selected image uploads to Firebase Storage
3. Message entity includes `attachments` array with { type, url, thumbnailUrl }
4. Image displayed in message bubble (MessageKit image message support)
5. Tap image opens full-screen viewer with zoom and pan
6. Image upload shows progress indicator during upload
7. Failed uploads show error state with retry option
8. Images compressed before upload to optimize storage and bandwidth (max 2MB per image)
9. Thumbnail generated for conversation list preview if last message is image
10. Image messages work offline: Image cached, upload queued until connection restored
11. Performance: Image upload completes within 10 seconds on reasonable connection
12. Reliability: Image uploads never lost, queued and retried on failure
13. Security: Firebase Storage rules restrict access to conversation participants only
14. Unit tests for image upload logic
15. Integration test: User A sends image, User B receives and views it
16. Regression test: Text messaging still works reliably with image support added

### Story 2.8: Offline Message Queue with Manual Send

As a **user**,  
I want **to see messages I've composed offline and manually send them when connected**,  
so that **I have control over what gets sent when connectivity returns**.

#### Acceptance Criteria

1. Messages composed while offline display with "Queued" status (yellow warning icon)
2. Persistent offline banner displays: "You're offline. X messages queued. [Send All]"
3. Queued messages persist locally (survive app restart)
4. Connectivity restored toast notification: "Connected. Auto-send 5 queued messages? [Yes] [Review First]"
5. "Review First" navigates to Offline Queue view showing all queued messages
6. Offline Queue view allows per-message actions: [Send] [Edit] [Delete]
7. "Send All" button in banner sends all queued messages in order
8. Queued messages sent sequentially (not in parallel) to maintain order
9. Successfully sent messages removed from queue and marked "sent"
10. Failed sends remain in queue with "Failed" status and manual retry option
11. Performance: Queue view loads instantly (local data only)
12. Reliability: Queue persisted in local storage (UserDefaults or local database), never lost
13. Edge case: Large queues (50+ messages) handled without UI lag
14. Unit tests for queue management logic
15. Integration test: Compose 5 messages offline, go online, send all, verify delivery
16. Regression test: Real-time messaging still works when always online

### Story 2.9: Push Notifications (Foreground & Background)

As a **user**,  
I want **to receive push notifications for new messages**,  
so that **I'm alerted even when not actively using the app**.

#### Acceptance Criteria

1. APNs certificate configured in Firebase Console
2. Device token registered with FCM on app launch
3. User prompted for notification permissions on first app launch
4. Cloud Function triggers on new message write to Firestore
5. Cloud Function sends push notification to recipient device(s) via FCM
6. Notification includes: sender name, message text preview, conversation ID
7. Foreground notifications displayed as banner at top (using UNUserNotificationCenter)
8. Background notifications wake device and display lock screen alert
9. Tap notification opens app directly to relevant conversation
10. Notification sound plays (default iOS sound acceptable for MVP)
11. Badge count updates on app icon showing unread message count
12. User online in conversation does NOT receive push (avoid redundant notifications)
13. Group chat notifications show: "[Sender] in [Group Name]: [Message]"
14. Performance: Notifications delivered within 5 seconds of message send
15. Reliability: Notifications delivered even if app is closed or device was offline (queued by APNs)
16. Cloud Function deployed and callable from Firestore triggers
17. Integration test: User A sends message while User B app backgrounded, verify User B receives push
18. Security: Cloud Function validates sender is participant in conversation before sending
19. Regression test: Real-time messaging in-app still works with push notifications enabled

### Story 2.10: Performance Optimization & Network Resilience

As a **developer**,  
I want **the app to handle poor network conditions and high message volume gracefully**,  
so that **users experience reliable messaging even under adverse conditions**.

#### Acceptance Criteria

1. Firestore queries optimized with proper indexing (composite indexes created)
2. Message pagination implemented (load 50 most recent, fetch older on scroll)
3. Conversation list pagination for users with 100+ conversations
4. Image thumbnails used in conversation previews (not full-resolution images)
5. Firestore listeners cleaned up properly when views dismissed (prevent memory leaks)
6. Network error handling with exponential backoff retry logic
7. Timeout handling for long-running operations (10 second max wait for network calls)
8. App handles 3G network speeds without crashes or data loss
9. Rapid-fire messaging test: Send 20+ messages quickly, verify all delivered in order
10. Performance baseline: App launch < 1 second, conversation load < 1 second, message send < 2 seconds
11. Memory profiling: App uses < 150MB RAM with 10 conversations loaded
12. Battery usage acceptable (no background processing runaway)
13. Offline → Online transition smooth (no crashes, queued messages process)
14. Integration test: Toggle airplane mode repeatedly during active messaging, verify no data loss
15. Load testing: 1000 message conversation loads and scrolls smoothly

### Story 2.11: Comprehensive Reliability Testing & Regression Suite

As a **QA engineer**,  
I want **a comprehensive test suite covering all MVP functionality and reliability scenarios**,  
so that **we can confidently validate the app meets production-quality standards**.

#### Acceptance Criteria

1. **Regression Test Suite Created** covering all Epic 1 and Epic 2 functionality:
   - Authentication flows
   - One-on-one messaging
   - Group chat
   - Message editing, unsend, retry
   - Read receipts and typing indicators
   - Image attachments
   - Offline queue
   - Push notifications

2. **10 Reliability Test Scenarios Defined and Executed:**
   - Scenario 1: Send 50 messages while toggling airplane mode 5 times - verify zero message loss
   - Scenario 2: Kill app mid-send - verify message completes on app restart
   - Scenario 3: Send message, edit 3 times, unsend - verify all participants see correct final state
   - Scenario 4: Group chat with 10 users, all send simultaneously - verify all messages delivered
   - Scenario 5: Compose 20 messages offline, review queue, send all - verify order maintained
   - Scenario 6: Send 100 messages rapidly (< 30 seconds) - verify all delivered without crashes
   - Scenario 7: Leave app backgrounded for 1 hour, receive 50 messages - verify all push notifications delivered
   - Scenario 8: Upload 10MB image on slow 3G - verify progress, completion, and retry on failure
   - Scenario 9: Two users edit same message simultaneously - verify conflict resolution (last write wins)
   - Scenario 10: Start with offline cached data, delete 5 conversations online (other device), sync - verify correct state

3. **Test Execution Results Documented:**
   - All 10 scenarios pass without critical failures
   - Any minor issues documented with workarounds or known limitations
   - Performance benchmarks recorded (message send time, app launch time, etc.)

4. **Code Coverage Verified:**
   - Minimum 70% coverage for Domain and Data layers maintained
   - New Epic 2 features have corresponding unit tests

5. **TestFlight Deployment:**
   - App successfully deployed to TestFlight
   - Beta testing instructions documented
   - At least 2 external testers receive build and validate basic messaging

6. **MVP Checkpoint Passed:**
   - All Gauntlet MVP requirements validated against spec
   - Demo-ready: Can showcase all required features to evaluators
   - Known issues list created for any non-critical bugs

---

## Epic 3: Core AI Features - Thread Intelligence

### Epic 3 Goal

Integrate the first three AI-powered features for remote team professionals: thread summarization, action item extraction, and smart search. These features are accessible contextually within conversations through buttons and modals, with minimal UI complexity. Cloud Functions are implemented to securely call AI services (OpenAI or Anthropic), protecting API keys from client exposure. AI quality acceptance criteria defined upfront to validate "good enough" performance. Expected timeline: 1.5 days.

### Story 3.1: Cloud Functions Infrastructure for AI Services

As a **developer**,  
I want **Firebase Cloud Functions that securely call AI services**,  
so that **API keys are never exposed in the client app and AI features can be triggered server-side**.

#### Acceptance Criteria

1. Cloud Functions project initialized in Firebase
2. Node.js Cloud Function created: `summarizeThread` accepting conversationId and messageIds
3. Node.js Cloud Function created: `extractActionItems` accepting conversationId and messageIds
4. Node.js Cloud Function created: `generateSmartSearchResults` accepting query and conversationIds
5. Cloud Functions authenticate requests (verify Firebase Auth token)
6. API keys for OpenAI or Anthropic stored in Firebase environment variables (not in code)
7. URLSession wrapper in iOS app to call Cloud Functions with proper authentication
8. Error handling in Cloud Functions: Rate limits, API failures, timeouts
9. Cloud Functions return structured JSON responses with AI results
10. Performance: Cloud Functions respond within 10 seconds or return timeout error
11. Cost optimization: Implement caching layer for repeated requests (same messages = cached summary)
12. Unit tests for Cloud Functions logic (mocked AI API calls)
13. Deployment: Cloud Functions deployed to Firebase dev environment
14. Integration test: iOS app calls Cloud Function, receives valid response
15. Security: Cloud Functions validate user has access to requested conversation data

### Story 3.2: Thread Summarization Feature

As a **user**,  
I want **to see an AI-generated summary of long conversation threads**,  
so that **I can quickly catch up on discussions without reading every message**.

#### Acceptance Criteria

**UI & Interaction:**
1. AI button added to chat view toolbar (lightning bolt or sparkle icon)
2. Tap AI button opens contextual menu showing "Summarize Thread" option
3. Tap "Summarize Thread" shows loading modal: "Analyzing conversation..."
4. Summary displayed in modal with: key points (bullets), main decisions, participants mentioned
5. Modal includes "Regenerate" and "Close" buttons
6. Summary persists: Tap AI button again shows last summary with timestamp "Generated 5 minutes ago"

**AI Implementation:**
7. ViewModel calls Cloud Function `summarizeThread` with last 100 messages (or all if fewer)
8. LLM prompt optimized for remote team context: "Summarize this team conversation, highlighting decisions, action items, and key points"
9. Summary length: 150-300 words maximum
10. Summary includes conversation participants and date range

**Quality Acceptance Criteria (Define "Good Enough"):**
11. Summary includes all explicitly stated decisions (e.g., "We decided to use Firebase")
12. Summary mentions any questions directly asked to current user
13. Summary doesn't hallucinate facts not in conversation
14. Summary readable and professional (no grammatical errors)
15. Manual validation: Test with 5 sample conversations, verify quality acceptable

**Performance & Caching:**
16. First summary generation: < 10 seconds
17. Cached summary: < 1 second load time
18. Summaries cached in Firestore collection `ai_summaries` with conversationId + messageRange key
19. Cache invalidated when new messages added (or regenerated on demand)

**Testing:**
20. Unit tests for summary ViewModel logic
21. Integration test: Generate summary, verify it contains key message content
22. Regression test: Chat functionality still works with AI button added

### Story 3.3: Action Item Extraction Feature

As a **user**,  
I want **AI to automatically extract action items from conversations**,  
so that **I don't miss tasks assigned to me or my team**.

#### Acceptance Criteria

**UI & Interaction:**
1. AI button contextual menu includes "Extract Action Items" option
2. Tap "Extract Action Items" shows loading modal: "Finding action items..."
3. Action items displayed in modal with structured list:
   - Task description
   - Assigned to (person mentioned or "Unassigned")
   - Context (link to source message)
4. Each action item has checkbox to "Add to Insights Dashboard"
5. "View All Action Items" button navigates to Insights tab

**AI Implementation:**
6. ViewModel calls Cloud Function `extractActionItems` with conversation messages
7. LLM prompt: "Extract action items from this conversation. For each, identify: what needs to be done, who should do it, and any mentioned deadlines"
8. Function returns array of { task, assignee, deadline, sourceMessageId }
9. Action items stored in Firestore `action_items` collection when user saves them

**Quality Acceptance Criteria (Define "Good Enough"):**
10. Detects explicit action items: "Can you send me the report?" → Task: "Send report", Assigned to: [detected name]
11. Detects implicit commitments: "I'll handle the deployment" → Task: "Handle deployment", Assigned to: [speaker]
12. Doesn't extract questions that aren't requests ("What time is it?" ≠ action item)
13. Correctly identifies assignee from context (name mentions, "you", "I")
14. Manual validation: Test with 5 conversations containing known action items, verify 80%+ detection rate

**Performance & Caching:**
15. Action item extraction: < 8 seconds
16. Cached results load < 1 second
17. Cache key: conversationId + messageRange

**Testing:**
18. Unit tests for action item ViewModel
19. Integration test: Extract action items from test conversation with known tasks
20. Regression test: Summary feature still works after action item implementation

### Story 3.4: Smart Search Feature

As a **user**,  
I want **to search my messages using natural language**,  
so that **I can find information without remembering exact keywords**.

#### Acceptance Criteria

**UI & Interaction:**
1. Search icon in conversations list navigation bar
2. Tap search opens search view with text input: "Search all conversations..."
3. Search suggestions below input: "Find decisions about...", "Messages from...", "Action items containing..."
4. User types query, AI-enhanced results appear below
5. Results show: message snippet, conversation name, timestamp, relevance score
6. Tap result navigates to conversation, scrolls to message

**AI Implementation (Hybrid Approach):**
7. Query preprocessed: Expand natural language to keywords (e.g., "when did we decide on Firebase" → keywords: "decide, decided, Firebase")
8. If query is simple keyword: Use Firestore text search (fast)
9. If query is complex/natural language: Call Cloud Function `generateSmartSearchResults` for semantic search
10. Cloud Function queries Firestore for relevant conversations, passes to LLM with query
11. LLM ranks messages by relevance and returns top 10 results

**Performance Considerations:**
12. Keyword search: < 1 second (Firestore only)
13. AI-enhanced search: < 5 seconds (Cloud Function + LLM)
14. Search results paginated (show 10, load more on scroll)
15. Recent searches cached locally for instant repeat queries

**Quality Acceptance Criteria (Define "Good Enough"):**
16. Natural language queries work: "What did Sarah say about the deadline?" returns messages from Sarah mentioning deadlines
17. Synonym handling: "meeting" also finds "call", "sync", "standup"
18. Contextual understanding: "our decision" finds messages with decision keywords near team member names
19. Manual validation: 10 test queries, verify top 3 results are relevant

**Edge Cases:**
20. No results state: "No messages found. Try different keywords."
21. Offline search: Falls back to local keyword search only (no AI)
22. Error handling: If Cloud Function fails, show basic Firestore results

**Testing:**
23. Unit tests for search ViewModel and query preprocessing
24. Integration test: Search for specific message, verify it appears in results
25. Performance test: Search across 1000+ messages completes within time limits
26. Regression test: Conversations list and chat still perform well with search added

### Story 3.5: AI Service Selection & Configuration

As a **developer**,  
I want **to finalize AI service selection (OpenAI vs Anthropic) and configure API access**,  
so that **all AI features use a consistent, reliable AI provider**.

#### Acceptance Criteria

1. Decision made: OpenAI GPT-4 OR Anthropic Claude (based on API access availability)
2. API key obtained and stored in iOS Keychain (for direct testing) and Firebase env vars (for Cloud Functions)
3. Cloud Functions updated to use selected AI provider
4. Rate limiting implemented: Max 100 AI requests per user per day (configurable)
5. Cost tracking: Log AI requests to Firebase Analytics for cost monitoring
6. Error messages user-friendly: "AI service temporarily unavailable" instead of raw API errors
7. Fallback strategy: If AI service down, features gracefully disabled (not crash)
8. KeychainService wrapper created for secure API key storage in iOS
9. Documentation: README updated with AI provider details and setup instructions
10. Testing: All AI features tested with final provider, verify quality acceptable

### Story 3.6: AI Results Caching & Cost Optimization

As a **developer**,  
I want **aggressive caching of AI results**,  
so that **repeated requests don't incur unnecessary costs and users get instant responses**.

#### Acceptance Criteria

1. Firestore collection `ai_cache` created with schema: { cacheKey, result, timestamp, expiresAt }
2. Cache key generation: Hash of (conversationId + messageIds + featureType)
3. Cloud Functions check cache before calling AI API
4. Cache hit: Return cached result (< 1 second response time)
5. Cache miss: Call AI API, store result in cache with 24-hour expiration
6. Cache invalidation: When new messages added, related caches marked stale
7. Stale cache UX: Show cached result with "Outdated (from 2 hours ago). [Regenerate]" option
8. Client-side caching: iOS app caches AI results locally for offline viewing
9. Cost monitoring: Dashboard in Firebase Console showing AI API usage and estimated costs
10. Performance: Cache lookups add < 100ms overhead
11. Testing: Verify cache hit/miss logic, measure cost savings (estimated 70% cache hit rate)

### Story 3.7: AI Feature Integration Testing & Quality Validation

As a **QA engineer**,  
I want **comprehensive testing of all AI features with real conversations**,  
so that **we validate quality meets acceptance criteria before moving to next epic**.

#### Acceptance Criteria

1. **Test Data Created:**
   - 10 sample conversations representing remote team scenarios (product decisions, bug discussions, planning, social chat)
   - Conversations vary in length: 10 messages, 50 messages, 100+ messages
   - Include edge cases: Very short threads, emoji-heavy, code snippets

2. **Quality Validation Matrix:**
   - Thread Summarization: 8/10 summaries capture all key decisions
   - Action Item Extraction: 7/10 conversations have 80%+ action item detection
   - Smart Search: 9/10 test queries return relevant results in top 3

3. **Performance Benchmarks Met:**
   - Summarization: Average 6 seconds (< 10 second requirement)
   - Action Items: Average 5 seconds (< 8 second requirement)
   - Smart Search: Average 3 seconds (< 5 second requirement)

4. **User Acceptance Testing:**
   - 2 external beta testers use AI features with real conversations
   - Feedback collected: Quality acceptable? Any hallucinations? Useful results?
   - At least 1 tester rates features "useful" or better

5. **Error Handling Validated:**
   - AI service unavailable: Features gracefully disabled, error message shown
   - Timeout: Loading modal shows "Taking longer than expected..." after 8 seconds
   - Invalid input: Empty conversations handled without crashes

6. **Regression Testing:**
   - All Epic 1 & Epic 2 features still work correctly
   - App performance not degraded (message send still < 2 seconds)
   - Memory usage acceptable with AI features active

7. **Documentation Updated:**
   - AI feature usage documented in README
   - Known limitations documented (e.g., "Works best with English conversations")
   - Cost estimates documented (e.g., "~$0.05 per summary")

---

## Epic 4: Core AI Features - Priority & Decision Tracking

### Epic 4 Goal

Implement the final two required AI features (priority message detection and decision tracking) and build the Insights dashboard that aggregates AI content across all conversations. This epic completes the 5 required AI features for Gauntlet evaluation. Regression testing ensures core messaging remains stable with all AI features active. Expected timeline: 1.5 days.

### Story 4.1: Priority Message Detection

As a **user**,  
I want **messages that require my attention to be automatically highlighted**,  
so that **I don't miss important questions or requests directed at me**.

#### Acceptance Criteria

**UI & Visual Treatment:**
1. Priority messages display with subtle visual indicator (yellow accent border or icon)
2. Priority badge appears in conversations list: "2 priority messages"
3. Tap priority badge filters conversation to show only priority messages
4. Long-press priority message shows option: "Why is this priority?"
5. "Why is this priority?" displays AI explanation modal: "This message asks you a direct question about deployment timeline"

**AI Implementation:**
6. Cloud Function created: `detectPriorityMessages` accepting conversationId and userId
7. Function analyzes new messages for priority signals:
   - Direct questions to user ("Can you...", "@username", user's name mentioned)
   - Urgency keywords ("ASAP", "urgent", "blocking", "critical")
   - Decision requests ("Need your approval", "What do you think?")
   - Assigned action items detected in message
8. Function returns array of messageIds with priority score (0-1) and reason
9. Messages with score > 0.7 marked as priority
10. Priority status stored in Firestore message document: `isPriority: true, priorityReason: string`

**Real-Time Detection:**
11. Cloud Function triggered on new message write (Firestore trigger)
12. Priority detection runs asynchronously (doesn't block message delivery)
13. Priority status updates in real-time for all participants
14. Push notifications enhanced: Priority messages get different notification sound/badge

**Quality Acceptance Criteria (Define "Good Enough"):**
15. Detects direct questions: "Sarah, can you review the PR?" → Priority for Sarah
16. Detects urgency: "Need this ASAP" → Priority
17. Doesn't over-flag: "What's for lunch?" in social chat → Not priority
18. Context-aware: Understands when user's name is mentioned in relevant context
19. Manual validation: 10 test conversations, verify 80%+ precision (flagged messages are actually important)
20. False positive rate < 20% (acceptable to miss some priorities, but minimize noise)

**Performance:**
21. Priority detection completes within 5 seconds of message arrival
22. Doesn't impact message delivery speed (runs asynchronously)
23. Priority status cached, re-evaluated only when conversation context changes

**Testing:**
24. Unit tests for priority detection logic in Cloud Function
25. Integration test: Send priority message, verify it's flagged correctly
26. Integration test: Send non-priority message, verify it's not flagged
27. Regression test: Message delivery, editing, and AI features still work correctly

### Story 4.2: Decision Tracking System

As a **user**,  
I want **AI to track important decisions made in conversations**,  
so that **I can reference past agreements and understand why choices were made**.

#### Acceptance Criteria

**UI & Interaction:**
1. Long-press any message shows option: "Mark as Decision"
2. Manual tagging opens modal: "What was decided?" with text input
3. User can edit AI-suggested decision summary or write custom
4. Decision saved with: summary, conversation link, participants, timestamp
5. Decisions visible in Insights tab "Recent Decisions" section
6. Each decision card shows: summary, context link, date, participants
7. Tap decision card navigates to source message in conversation
8. Decision indicator (badge or icon) on source message in chat view

**AI-Assisted Detection:**
9. Cloud Function created: `detectDecisions` analyzing conversations for decision signals
10. Decision signals detected:
    - "We decided to...", "Let's go with...", "Agreed", "Final decision:"
    - Resolution of previous debate/discussion
    - Explicit consensus statements
11. Function suggests decisions via in-app notification: "Detected decision: 'Use Firebase for backend'. [Save] [Ignore]"
12. Suggested decisions stored temporarily until user confirms or dismisses

**Data Model:**
13. Firestore collection `decisions` created with schema:
    - id, conversationId, messageId, summary, participants[], timestamp, tags[]
14. Decisions indexed by conversationId and timestamp for fast querying
15. User can add tags to decisions: "technical", "product", "urgent"

**Quality Acceptance Criteria (Define "Good Enough"):**
16. Detects explicit decisions: "We're going with option B" → Captured
17. Provides context: Decision includes preceding discussion summary
18. Doesn't hallucinate: Only suggests decisions actually stated in conversation
19. Manual validation: 8/10 explicit decisions detected and suggested correctly
20. User override: Manual tagging works even if AI doesn't detect decision

**Insights Dashboard Integration:**
21. Recent Decisions view shows last 20 decisions across all conversations
22. Filter by: conversation, date range, tags, participants
23. Search decisions: "What did we decide about the API?"
24. Export decisions as markdown or CSV (stretch goal: not MVP required)

**Performance:**
25. Decision detection runs on-demand (when user opens Insights tab) or nightly batch
26. Decision list loads < 2 seconds
27. Cached decisions with 1-hour refresh

**Testing:**
28. Unit tests for decision detection logic
29. Integration test: Make explicit decision in conversation, verify detection or manual tagging works
30. Integration test: Search decisions, verify correct results returned
31. Regression test: All previous AI features still functional

### Story 4.3: Insights Dashboard - Aggregated View

As a **user**,  
I want **a central dashboard showing AI insights across all my conversations**,  
so that **I can manage action items, review decisions, and see priority messages in one place**.

#### Acceptance Criteria

**Navigation & Structure:**
1. Insights tab (second tab) in main navigation with sparkle/AI icon
2. Dashboard shows four main sections:
   - **Priority Messages Inbox** (top)
   - **All Action Items**
   - **Recent Decisions**
   - **Proactive Suggestions** (placeholder for Epic 5)
3. Empty states for each section: "No priority messages", "No action items yet"
4. Pull-to-refresh updates all sections

**Priority Messages Inbox:**
5. Card-based list showing priority messages from all conversations
6. Each card displays: message text, sender, conversation name, timestamp, priority reason
7. Tap card navigates to message in conversation
8. Swipe actions: "Mark as Read", "Respond", "Not Priority" (removes flag)
9. Badge on Insights tab shows unread priority message count

**All Action Items Section:**
10. List of action items from all conversations
11. Grouped by: Assigned to me, Assigned to others, Unassigned
12. Each item shows: task, assignee, conversation context, due date (if detected)
13. Checkbox to mark action items complete
14. Completed items archived (not deleted), viewable in "Completed" filter
15. Tap action item navigates to source message

**Recent Decisions Section:**
16. Timeline view of recent decisions (last 30 days)
17. Decision cards show: summary, date, conversation, participants
18. Search bar: "Search decisions..."
19. Filter chips: "This Week", "Technical", "Product", "All Conversations"
20. Tap decision navigates to source conversation

**Performance:**
21. Dashboard initial load < 2 seconds
22. Each section loads independently (progressive loading)
23. Cached data shown immediately, refresh in background
24. Smooth scrolling with 100+ items across all sections

**Design & UX:**
25. Clean, organized layout with clear section headers
26. Dark mode styling applied
27. Accessibility: VoiceOver support, dynamic type
28. Visual distinction between sections (subtle dividers, spacing)

**Testing:**
29. Unit tests for Insights ViewModel aggregating data from multiple repositories
30. Integration test: Create action items and decisions in multiple conversations, verify they appear in Insights
31. UI test: Navigate through all Insights sections, verify interactions work
32. Regression test: Main messaging functionality unaffected by Insights tab

### Story 4.4: Cross-Conversation AI Context

As a **developer**,  
I want **AI features to access context across multiple conversations**,  
so that **Insights dashboard can provide intelligent aggregation and suggestions**.

#### Acceptance Criteria

**Architecture:**
1. Cloud Function created: `aggregateInsights` accepting userId
2. Function queries all user's conversations and AI-generated content
3. Aggregation logic:
   - Collect all priority messages from last 7 days
   - Collect all uncompleted action items
   - Collect all decisions from last 30 days
4. Function returns structured data for Insights dashboard
5. Caching: Aggregated insights cached for 15 minutes per user

**Smart Aggregation:**
6. Duplicate detection: Similar action items across conversations merged (e.g., "Deploy app" in two chats → one aggregated item)
7. Priority ranking: Most urgent/important items bubble to top
8. Relationship detection: Link related decisions and action items (e.g., decision "Use Firebase" → action item "Set up Firebase")

**Performance:**
9. Aggregation completes < 3 seconds for user with 20 conversations
10. Incremental updates: Only refresh changed conversations, not all data
11. Background refresh: Insights updated automatically every 30 minutes when app active

**Privacy & Security:**
12. Aggregation respects conversation permissions (user must be participant)
13. No cross-user data leakage (strict user ID filtering)
14. Cloud Function validates user authentication before returning data

**Testing:**
15. Unit tests for aggregation logic (mocked conversation data)
16. Integration test: User with 5 conversations, create action items in 3, verify aggregated view correct
17. Security test: Attempt to access another user's insights, verify denied
18. Performance test: User with 50 conversations, verify aggregation completes within time limit

### Story 4.5: AI Feature Discoverability & Onboarding

As a **user**,  
I want **to understand what AI features are available and how to use them**,  
so that **I don't miss valuable functionality**.

#### Acceptance Criteria

**First-Time Onboarding:**
1. After completing Epic 2 MVP, first app launch shows AI onboarding
2. 3-screen carousel explaining AI features:
   - Screen 1: "Intelligent Insights - Your AI assistant helps you stay organized"
   - Screen 2: "In-Chat AI - Summarize, extract tasks, and search with natural language"
   - Screen 3: "Insights Dashboard - See everything important in one place"
3. "Got it" button dismisses onboarding, sets flag to not show again
4. "Skip" option for power users

**In-App Discovery:**
5. AI button in chat has tooltip on first tap: "Tap for AI-powered features"
6. Empty Insights dashboard includes "How it works" explainer section
7. Settings includes "AI Features" section with toggles and explanations
8. Help/FAQ section documents all AI features with examples

**Visual Cues:**
9. AI-generated content visually distinct (subtle sparkle icon or badge)
10. First time AI feature used, show confirmation: "✓ Summary generated. Find it anytime in Insights."
11. Priority messages include first-time explanation: "This message may need your attention. Long-press to see why."

**Performance:**
12. Onboarding screens lightweight (< 500KB total assets)
13. Onboarding dismissible at any time (no forced completion)

**Testing:**
14. UI test: Complete onboarding flow, verify doesn't show again
15. Usability test: 2 new users try AI features without instruction, note confusion points
16. Regression test: Onboarding doesn't interfere with core messaging

### Story 4.6: Epic 4 Regression Testing & AI Feature Validation

As a **QA engineer**,  
I want **comprehensive validation that all 5 required AI features work correctly together**,  
so that **the app is ready for Gauntlet evaluation with complete AI functionality**.

#### Acceptance Criteria

1. **All 5 Required AI Features Validated:**
   - ✅ Thread Summarization: Working, quality acceptable
   - ✅ Action Item Extraction: Working, 80%+ detection rate
   - ✅ Smart Search: Working, natural language queries return relevant results
   - ✅ Priority Message Detection: Working, < 20% false positive rate
   - ✅ Decision Tracking: Working, manual and AI-assisted modes functional

2. **Insights Dashboard Integration Tested:**
   - Action items from multiple conversations appear correctly
   - Priority messages aggregated properly
   - Decisions searchable and filterable
   - Navigation from Insights to source messages works

3. **End-to-End Scenario Testing:**
   - Scenario 1: Team discussion → AI detects decision → Appears in Insights → User finds it via search
   - Scenario 2: User receives priority message → Gets push notification → Opens app → Sees in Insights → Responds
   - Scenario 3: Action items assigned in group chat → Extracted by AI → Marked complete in Insights → Status syncs across devices

4. **Performance Benchmarks Maintained:**
   - Message send still < 2 seconds (core messaging not degraded)
   - App launch still < 1 second
   - Insights dashboard loads < 2 seconds
   - All AI features respond within documented time limits

5. **Regression Test Suite Passed:**
   - All Epic 1 & 2 tests still pass
   - All Epic 3 tests still pass
   - No new crashes or critical bugs introduced

6. **TestFlight Deployment #2:**
   - Build deployed with all AI features
   - Beta testers validate AI features work as expected
   - Feedback collected and documented

7. **Gauntlet Evaluation Readiness:**
   - Demo script created showing all 5 required AI features
   - Can demonstrate each feature in < 2 minutes
   - Known issues list: Any non-critical bugs documented
   - App meets all Gauntlet MVP + AI requirements

---

## Epic 5: Advanced AI - Proactive Assistant

### Epic 5 Goal

Build the proactive scheduling assistant that detects coordination needs, auto-suggests meeting times, and delivers AI-summarized push notifications. This completes the advanced AI capability requirement for Gauntlet. Minimum viable scope defined with stretch goals for additional intelligence. Expected timeline: 1 day + buffer (Day 7 flex time).

### Story 5.1: Push Notification AI Summaries

As a **user**,  
I want **push notifications that summarize conversation activity since I last opened the app**,  
so that **I get context before diving into messages**.

#### Acceptance Criteria

**Notification Content:**
1. Push notification includes AI-generated summary when user has 3+ unread messages in a conversation
2. Summary format: "[Count] new messages from [Conversation]: [Key points]. [Direct questions to user]"
3. Example: "5 messages from Design Team: Sarah shared wireframes, Mike approved v2, action item assigned to you"
4. Long conversations (10+ messages) condensed to 2-3 key points max
5. Direct questions to user always highlighted if present

**Implementation:**
6. Cloud Function `generatePushSummary` triggered when sending push notification (from Story 2.9)
7. Function retrieves messages since user's last app open (tracked in Firestore)
8. LLM prompt: "Summarize these [N] team messages in 20 words or less, highlighting decisions and questions for [User Name]"
9. Summary embedded in push notification payload
10. Fallback: If summary generation fails, send standard push with message preview

**Performance:**
11. Summary generation doesn't delay push delivery (async process with fallback)
12. Summary generated within 3 seconds or fallback triggered
13. User's last-seen timestamp updated reliably when app opened

**Quality Acceptance Criteria:**
14. Summaries are accurate (no hallucinations)
15. Direct questions to user are included 90% of the time
16. Summaries don't exceed notification character limits (iOS: ~150 chars)
17. Manual validation: 10 test scenarios, verify summaries useful and accurate

**Testing:**
18. Integration test: User receives 5 messages while app closed, verify push includes summary
19. Integration test: Summary generation fails, verify fallback push still delivered
20. Regression test: Non-AI push notifications still work

### Story 5.2: Scheduling Need Detection

As a **user**,  
I want **AI to detect when my team is trying to schedule a meeting**,  
so that **I can get proactive coordination assistance**.

#### Acceptance Criteria

**Detection Signals:**
1. Cloud Function `detectSchedulingNeeds` analyzes messages for scheduling language:
   - "Let's meet", "Can we schedule", "When are you free"
   - Time/date mentions: "tomorrow", "next week", "Friday at 2pm"
   - Availability questions: "What's your availability?", "When works for you?"
2. Function triggered on message write, runs asynchronously
3. Detection result stored: `schedulingDetected: true, participants: [], context: string`

**In-App Notification:**
4. When scheduling detected, show in-app banner: "Looks like you're scheduling a meeting. [Get AI Help]"
5. Banner appears in conversation view, dismissible
6. Tap "Get AI Help" opens proactive assistant interface

**Proactive Suggestions Section (Insights Dashboard):**
7. Detected scheduling needs appear in "Proactive Suggestions" section of Insights tab
8. Card shows: conversation, participants, scheduling context, "[Help Schedule]" button
9. Tap card or button opens proactive assistant for that conversation

**Quality Acceptance Criteria:**
10. Detects explicit scheduling: "Let's meet Friday" → Detected
11. Detects implicit scheduling: "We need to sync on this" → Detected
12. Doesn't over-detect: "I'll meet you at the coffee shop" (social) → Not detected
13. Manual validation: 8/10 scheduling conversations detected
14. False positive rate < 15%

**Performance:**
15. Detection completes within 3 seconds of message
16. Doesn't impact message delivery

**Testing:**
17. Unit tests for scheduling detection logic
18. Integration test: Send scheduling message, verify detection and banner appear
19. Integration test: Non-scheduling message, verify no false detection

### Story 5.3: Meeting Time Suggestions

As a **user**,  
I want **AI to suggest meeting times based on conversation context**,  
so that **scheduling becomes faster and easier**.

#### Acceptance Criteria

**Proactive Assistant Interface:**
1. When user taps "Get AI Help" from scheduling detection, open modal: "Schedule Meeting Assistant"
2. Modal shows:
   - Detected participants from conversation
   - Add/remove participants option
   - "Generate Time Suggestions" button
3. Tap "Generate Time Suggestions" calls Cloud Function

**AI Suggestion Logic:**
6. Cloud Function `suggestMeetingTimes` accepts participants and conversation context
7. LLM analyzes conversation for:
   - Mentioned time constraints ("not mornings", "afternoons only")
   - Mentioned dates/ranges ("next week", "before Friday")
   - Timezone hints if present
8. Function suggests 3-5 meeting time options with rationale
9. Suggestions formatted: "Tomorrow at 2pm ET - [Rationale]"
10. Rationale examples: "Avoids morning conflicts mentioned", "Within requested timeframe"

**Minimum Viable Scope:**
11. MVP: Suggestions based on conversation analysis only (no calendar integration)
12. Suggestions are **recommendations**, not definitive availability
13. User can copy suggestions and paste into conversation manually

**Stretch Goals (Optional, Day 7):**
14. (Stretch) Calendar integration: Check user's actual availability
15. (Stretch) Send poll to participants with suggested times
16. (Stretch) Automatically book meeting when participants agree

**Quality Acceptance Criteria:**
17. Suggestions are relevant to conversation context
18. Suggestions respect mentioned constraints 80% of the time
19. Suggestions are realistic (not suggesting "3am" unless context indicates)
20. Manual validation: 5 test scenarios, verify suggestions reasonable

**Performance:**
21. Suggestion generation < 8 seconds
22. Cached for conversation (regenerate on request)

**Testing:**
23. Unit tests for suggestion logic
24. Integration test: Request suggestions, verify they match conversation constraints
25. Regression test: All previous AI features still functional

### Story 5.4: Proactive Assistant UX Polish

As a **user**,  
I want **the proactive assistant to feel helpful, not intrusive**,  
so that **I actually use it instead of ignoring it**.

#### Acceptance Criteria

**Discoverability:**
1. First time scheduling detected, show explainer tooltip: "AI can help coordinate meetings. Tap to try it."
2. Proactive Suggestions section in Insights has description: "AI detects when you're scheduling and offers help"
3. Settings toggle: "Proactive Scheduling Assistance" (on by default)

**Non-Intrusive Design:**
4. In-conversation banner is small, at bottom of screen (not blocking messages)
5. Banner auto-dismisses after 30 seconds if not interacted with
6. User can permanently dismiss: "Don't suggest for this conversation"
7. Suggestions section in Insights doesn't show old/irrelevant scheduling (auto-expire after 7 days)

**Feedback Loop:**
8. After user schedules meeting (detected by follow-up messages), ask: "Did AI suggestions help? 👍 👎"
9. Feedback stored for future improvement
10. Negative feedback reduces suggestion frequency for that user

**Visual Design:**
11. Proactive assistant uses distinct color/icon (different from other AI features)
12. Suggestion cards visually appealing, easy to read
13. Dark mode styling applied

**Testing:**
14. Usability test: 2 users try proactive assistant, note if it feels helpful or annoying
15. UI test: Verify all interactions (banner, modal, suggestions) work smoothly
16. Regression test: Doesn't interfere with core messaging

### Story 5.5: Epic 5 Final Testing & Project Completion

As a **QA engineer**,  
I want **final validation that the complete app meets all Gauntlet requirements**,  
so that **the project is ready for submission and evaluation**.

#### Acceptance Criteria

1. **Advanced AI Feature Validated:**
   - ✅ Proactive Assistant: Working, detects scheduling needs, suggests times
   - ✅ Push notification summaries: Working, provide useful context
   - ✅ Minimum viable scope met (no calendar integration required)

2. **Complete Feature Set Validation:**
   - All MVP messaging features (Epic 1 & 2)
   - All 5 required AI features (Epic 3 & 4)
   - 1 advanced AI capability (Epic 5)
   - Insights dashboard aggregating everything

3. **End-to-End Final Scenarios:**
   - Scenario 1: Full day of team communication → AI summaries in push → Open app → Insights shows all important items → Use proactive assistant to schedule follow-up
   - Scenario 2: New user onboarding → Try all features → Successful without confusion
   - Scenario 3: Stress test → 100 messages across 10 conversations → All AI features remain performant

4. **Performance & Reliability Final Check:**
   - App launch < 1 second
   - Message send < 2 seconds
   - All AI features respond within documented limits
   - Zero message loss in stress testing
   - No crashes in 1 hour continuous use

5. **TestFlight Deployment #3 (Final):**
   - Complete build deployed
   - 3+ external testers validate full feature set
   - Demo-ready for Gauntlet evaluation
   - Beta feedback addressed or documented as known limitations

6. **Gauntlet Submission Readiness:**
   - **Complete Feature Checklist:**
     - ✅ One-on-one chat
     - ✅ Real-time delivery
     - ✅ Message persistence
     - ✅ Optimistic UI
     - ✅ Online/offline status
     - ✅ Timestamps
     - ✅ User authentication
     - ✅ Group chat
     - ✅ Read receipts
     - ✅ Push notifications
     - ✅ Image attachments
     - ✅ Message editing, unsend, retry
     - ✅ Offline queue with manual send
     - ✅ Thread summarization (AI)
     - ✅ Action item extraction (AI)
     - ✅ Smart search (AI)
     - ✅ Priority detection (AI)
     - ✅ Decision tracking (AI)
     - ✅ Proactive assistant (Advanced AI)

7. **Documentation Package:**
   - README with setup instructions
   - Architecture documentation
   - API key setup guide
   - Known limitations documented
   - Demo script for evaluators
   - Video demo recorded (optional but recommended)

8. **Code Quality:**
   - 70%+ test coverage maintained
   - No critical linter errors
   - Clean Architecture maintained throughout
   - Code comments where necessary

9. **Success Metrics Achieved:**
   - Zero message loss validated
   - Real-time delivery working
   - All AI features meeting quality acceptance criteria
   - App stable and performant

---

**Epic 5 Complete!**

At the end of this epic, you have:
- ✅ Complete MessageAI app with all Gauntlet requirements
- ✅ Production-quality messaging infrastructure
- ✅ 5 required AI features fully functional
- ✅ 1 advanced AI capability (proactive assistant)
- ✅ Comprehensive testing and validation
- ✅ Ready for Gauntlet submission and evaluation

**🎉 Project Complete! 🎉**

---

## Success Metrics

The MessageAI project will be considered successful when:

### MVP Success Criteria (Epic 1-2)

- **Zero message loss** validated through 10 reliability test scenarios
- **Real-time delivery** < 2 seconds for online users under normal network conditions
- **Message persistence** survives app restarts and offline/online transitions
- **All Gauntlet MVP requirements** implemented and functional
- **TestFlight deployment** with 2+ external beta testers validating core functionality
- **70%+ code coverage** for Domain and Data layers

### AI Features Success Criteria (Epic 3-5)

- **Thread Summarization:** 80%+ of summaries capture key decisions without hallucinations
- **Action Item Extraction:** 80%+ detection rate for explicit action items
- **Smart Search:** 90%+ of test queries return relevant results in top 3
- **Priority Detection:** < 20% false positive rate, 80%+ precision on important messages
- **Decision Tracking:** Manual and AI-assisted modes both functional, 80%+ explicit decision detection
- **Proactive Assistant:** Detects scheduling needs with < 15% false positives, provides relevant meeting suggestions

### Performance Benchmarks

- **App Launch:** < 1 second to conversations list
- **Message Send:** < 2 seconds delivery to online recipients
- **Conversation Load:** Last 50 messages in < 1 second
- **AI Response Times:**
  - Summarization: < 10 seconds
  - Action Items: < 8 seconds
  - Smart Search: < 5 seconds
  - Priority Detection: < 5 seconds
  - Proactive Suggestions: < 8 seconds
- **Insights Dashboard:** < 2 seconds initial load

### Quality Metrics

- **Crash-Free Rate:** > 99% in beta testing
- **User Satisfaction:** At least 1 beta tester rates AI features "useful" or better
- **Code Quality:** No critical linter errors, Clean Architecture maintained

### Completion Criteria

- All 5 epics completed with stories marked "Done"
- Regression test suite passing
- Final TestFlight build deployed
- Demo script prepared for Gauntlet evaluators
- Known issues documented
- README and documentation complete

---

## Next Steps

### For UX Expert Agent

The UX Expert should refine:
- Detailed UI specifications for all screens
- Interaction patterns and animations
- Accessibility implementation details
- Design system components
- User flow diagrams

### For Architect Agent

The architecture document should detail:

**System Architecture:**
- Clean Architecture (MVVM) layer breakdown with iOS/Swift specifics
- Firebase backend architecture (Firestore, Cloud Functions, FCM, Storage)
- Real-time messaging flow diagrams
- AI service integration patterns
- Offline-first data strategy

**Database Schema:**
- Firestore collections structure (users, conversations, messages, action_items, decisions, ai_cache)
- Security rules design
- Indexing strategy for performance

**Cloud Functions Architecture:**
- Function-by-function breakdown (summarizeThread, extractActionItems, detectPriorityMessages, etc.)
- Authentication and authorization patterns
- Caching and cost optimization strategies

**iOS App Architecture:**
- Clean Architecture folder structure details
- Dependency injection strategy
- Repository pattern implementation
- ViewModel patterns for each feature
- MessageKit integration approach

**AI Integration Patterns:**
- LLM prompt engineering guidelines
- Function calling / tool use patterns
- Caching strategies for AI results
- Error handling and fallback patterns

**Testing Strategy:**
- Unit testing approach (70%+ coverage)
- Integration testing with Firebase
- UI testing for critical flows
- Manual testing scenarios

**Deployment & DevOps:**
- Firebase project configuration (dev/prod)
- TestFlight deployment process
- Environment variable management
- API key security (Keychain)

### For Development Team (SM → Dev → QA Cycle)

Once architecture is complete:

1. **Shard Documents:** Run `shard-doc` on PRD and Architecture
2. **Epic 1 Sprint:** SM creates stories → Dev implements → QA reviews
3. **Continue through Epic 5:** Repeat cycle for each epic
4. **Final validation:** Complete testing and deploy to TestFlight
5. **Gauntlet submission:** Demo and documentation package

---

**PRD Complete!** ✅

This Product Requirements Document provides complete specifications for building MessageAI from foundation through advanced AI features. The structured epic approach with detailed stories, acceptance criteria, and quality gates ensures systematic progress toward a production-quality messaging app with intelligent features for remote team professionals.

