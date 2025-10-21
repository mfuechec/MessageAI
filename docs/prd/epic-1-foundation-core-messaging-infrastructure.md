# Epic 1: Foundation & Core Messaging Infrastructure

## Epic 1 Goal

Establish a production-ready iOS project with Clean Architecture (MVVM), integrate Firebase for real-time messaging and authentication, and deliver functional one-on-one text chat with message persistence and real-time delivery. This epic prioritizes architectural soundness and testability, setting the foundation for all subsequent features. Expected timeline: 1.5 days accounting for Swift learning curve and initial project setup.

## Story 1.1: Project Setup & Clean Architecture Foundation

As a **developer**,  
I want **a well-structured Xcode project with Clean Architecture folders and dependency injection**,  
so that **the codebase is maintainable, testable, and follows best practices from day one**.

### Acceptance Criteria

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

## Story 1.2: Firebase Integration & Configuration

As a **developer**,  
I want **Firebase integrated with separate development and production environments**,  
so that **I can use Firebase services safely without affecting production data**.

### Acceptance Criteria

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

## Story 1.3: Domain Models & Repository Protocols

As a **developer**,  
I want **core domain entities and repository protocols defined**,  
so that **business logic is decoupled from data sources and follows Clean Architecture principles**.

### Acceptance Criteria

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

## Story 1.4: Firebase Repository Implementations

As a **developer**,  
I want **concrete Firebase repository implementations**,  
so that **the app can interact with Firebase services while remaining testable through protocol abstractions**.

### Acceptance Criteria

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

## Story 1.5: Authentication UI & Flow

As a **user**,  
I want **to create an account and sign in with email/password**,  
so that **I can access the messaging app with a secure personal account**.

### Acceptance Criteria

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

## Story 1.6: User Profile Setup

As a **user**,  
I want **to set my display name after creating an account**,  
so that **other users can identify me in conversations**.

### Acceptance Criteria

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

## Story 1.7: Conversations List UI

As a **user**,  
I want **to see a list of my conversations**,  
so that **I can quickly access ongoing chats**.

### Acceptance Criteria

1. `ConversationsListView` displays all conversations for current user
2. `ConversationsListViewModel` observes conversations using `ConversationRepositoryProtocol`
3. Each conversation row shows: participant name(s), last message preview, timestamp, unread count badge
4. Empty state displayed when no conversations exist ("Start a new conversation")
5. Tap conversation navigates to chat view
6. Navigation bar with title "Messages" and "New Conversation" button
7. Real-time updates when new messages arrive (conversation list reorders)
8. Loading state while initial conversations load
9. Offline indicator banner displayed when no network connectivity
10. Conversations sorted by most recent message first
11. Unit tests for `ConversationsListViewModel` with mocked data
12. Dark mode styling verified
13. Smooth scrolling performance with 50+ conversations

**Note:** Pull-to-refresh intentionally excluded - real-time Firestore listeners provide automatic updates.

## Story 1.8: One-on-One Chat View with Real-Time Messaging

As a **user**,  
I want **to send and receive text messages in real-time within a conversation**,  
so that **I can communicate instantly with another user**.

### Acceptance Criteria

1. `ChatView` displays messages for selected conversation using MessageKit
2. `ChatViewModel` observes messages using `MessageRepositoryProtocol`
3. Message composition bar with text input and send button
4. Send button sends message via `MessageRepositoryProtocol.sendMessage`
5. Optimistic UI: Sent message appears immediately with "sending" status indicator
6. Real-time updates: Received messages appear instantly via Firestore listener
7. Messages display sender name (or "You"), timestamp, and message text
8. Message bubbles styled differently for current user vs other participants
9. Auto-scroll to bottom when new messages arrive or user sends message
10. Scroll-to-top loads older messages (pagination, NOT pull-to-refresh for new messages)
11. Loading state while initial messages load
12. Empty state for new conversations ("Say hello!")
13. Keyboard handling: Input bar stays above keyboard, scroll adjusts
14. Offline indicator banner in chat view
15. Unit tests for `ChatViewModel` message sending and receiving flows
16. Integration test: Send message from User A, verify User B receives it in real-time
17. Dark mode styling applied to chat bubbles and input bar
18. MessageKit customization matches app design (colors, fonts, spacing)

## Story 1.9: Message Persistence & Offline Viewing

As a **user**,  
I want **to view my conversation history even when offline**,  
so that **I can reference past messages without an internet connection**.

### Acceptance Criteria

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

## Story 1.10: Test Framework & Initial Test Suite

As a **developer**,  
I want **a comprehensive test framework with initial unit and integration tests**,  
so that **code quality is validated before proceeding and all future code follows test-first approach**.

### Acceptance Criteria

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
