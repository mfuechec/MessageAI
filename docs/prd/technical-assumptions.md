# Technical Assumptions

## Repository Structure: Monorepo

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

## Service Architecture

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

## Testing Requirements

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

## Additional Technical Assumptions and Requests

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
