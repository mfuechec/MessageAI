# MessageAI

Remote team messaging application with AI-powered intelligence for enhanced productivity.

## Overview

MessageAI is an iOS messaging application designed for remote teams, featuring real-time messaging with integrated AI capabilities for thread summarization, priority tracking, and decision extraction. The app helps distributed teams stay aligned and productive by automatically surfacing key information from conversations.

## Architecture

This project follows **Clean Architecture** principles with the **MVVM (Model-View-ViewModel)** pattern to ensure:
- **Testability**: 70%+ code coverage with fast unit tests
- **Maintainability**: Clear separation of concerns across layers
- **Scalability**: Easy to add features without breaking existing code
- **Framework Independence**: Domain logic is pure Swift with zero external dependencies

### Layer Structure

```
MessageAI/
├── App/                          # Application Entry & Dependency Injection
│   ├── MessageAIApp.swift        # SwiftUI App entry point
│   └── DIContainer.swift         # Dependency injection container
│
├── Domain/                       # Business Logic (Pure Swift - No External Dependencies)
│   ├── Entities/                 # Core business models (User, Message, Conversation)
│   ├── UseCases/                 # Business logic operations (SendMessage, FetchMessages)
│   └── Repositories/             # Repository protocol definitions
│
├── Data/                         # Data Layer (External Services Implementation)
│   ├── Repositories/             # Firebase repository implementations
│   └── Network/                  # Network service layer (AI APIs, Firebase)
│
├── Presentation/                 # UI Layer (SwiftUI + ViewModels)
│   ├── ViewModels/               # ViewModels with @Published properties
│   ├── Views/                    # SwiftUI views
│   └── Components/               # Reusable UI components
│
└── Resources/                    # Assets & Configuration
    └── Assets.xcassets           # Images, colors, icons
```

### Layer Responsibilities

- **App**: Application lifecycle, dependency wiring, configuration
- **Domain**: Core business models and logic (framework-agnostic)
- **Data**: Firebase implementations, API calls, data transformation
- **Presentation**: SwiftUI views, ViewModels, user interaction

### Dependency Flow

```
Presentation → Domain ← Data
     ↓
   Domain (Protocols)
     ↑
   Data (Implementations)
```

**Key Principle**: Dependencies point inward. Domain layer has zero external dependencies.

## Tech Stack

- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI (iOS 15+)
- **Architecture**: Clean Architecture + MVVM
- **Backend**: Firebase (Firestore, Auth, Cloud Functions, FCM, Storage)
- **Chat UI**: MessageKit (production-quality chat components)
- **State Management**: Combine + @Published
- **AI Provider**: OpenAI GPT-4 (via Cloud Functions)
- **Testing**: XCTest (70%+ coverage goal)
- **Dependency Manager**: Swift Package Manager

## Project Configuration

- **Minimum iOS Version**: iOS 15.0
- **Supported Devices**: iPhone only (portrait orientation locked)
- **Dark Mode**: Enabled by default
- **Bundle ID**: `com.mfuechec.MessageAI`

## Setup Instructions

### Prerequisites

- Xcode 15.0+ with Swift 5.9+
- iOS 15.0+ device or simulator
- macOS 13.0+ (Ventura or later)

### Getting Started

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd MessageAI
   ```

2. **Open project in Xcode**
   ```bash
   open MessageAI.xcodeproj
   ```

3. **Firebase Configuration** ⚠️ **Required for app to run**
   
   MessageAI uses Firebase for backend services. You'll need to obtain Firebase configuration files:
   
   - **Development Project**: `messageai-dev-1f2ec`
   - **Production Project**: `messageai-prod-4d3a8`
   - Firebase Console: https://console.firebase.google.com/
   
   **See detailed Firebase setup instructions below** ↓

4. **Install Dependencies**
   - Dependencies are managed via Swift Package Manager
   - Already configured in Xcode project (Firebase SDK 12.4.0+)
   - Xcode will automatically resolve packages on first build

5. **Build and Run**
   - Select MessageAI scheme
   - Choose simulator or physical device (iOS 15.0+)
   - Press `Cmd+R` to build and run
   - Check console logs for "✅ Firebase configured for Development environment"

## Firebase Setup (Required)

### Prerequisites

- Firebase CLI: `npm install -g firebase-tools`
- Node.js 18+ (for Firebase CLI)
- Access to Firebase Console: https://console.firebase.google.com/

### Obtaining GoogleService-Info.plist Files

The app requires environment-specific Firebase configuration files. These files are **NOT** included in the repository for security reasons.

#### For Development Environment:

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select project: **MessageAI-Dev** (`messageai-dev-1f2ec`)
3. Click ⚙️ **Project Settings** → **General** tab
4. Scroll to **Your apps** section
5. If iOS app not registered:
   - Click **Add app** → **iOS**
   - Bundle ID: `com.mfuechec.MessageAI.dev`
   - App nickname: `MessageAI Dev`
6. Download `GoogleService-Info.plist`
7. Rename to `GoogleService-Info-Dev.plist`
8. Add to `MessageAI/Resources/` folder in Xcode
9. **Important**: Uncheck target membership (loaded programmatically)

#### For Production Environment:

1. Select project: **MessageAI-Prod** (`messageai-prod-4d3a8`)
2. Repeat steps above
3. Bundle ID: `com.mfuechec.MessageAI` (no suffix)
4. Rename to `GoogleService-Info-Prod.plist`
5. Add to same `MessageAI/Resources/` folder

### Environment Switching

The app automatically selects the correct Firebase environment based on build configuration:

- **DEBUG builds** (Cmd+R in Xcode) → Development environment
- **RELEASE builds** (Archive/TestFlight) → Production environment

No manual switching required!

### Deploying Firestore Security Rules

Security rules are already deployed to both projects. To update them:

```bash
# Deploy to development
firebase deploy --only firestore:rules --project messageai-dev-1f2ec

# Deploy to production
firebase deploy --only firestore:rules --project messageai-prod-4d3a8
```

### Firebase Services Enabled

Both projects have the following services configured:

- ✅ **Cloud Firestore** - Real-time database with offline persistence
- ✅ **Authentication** - Email/password provider enabled
- ✅ **Cloud Storage** - File upload storage
- ✅ **Cloud Messaging** - Push notifications (APNs setup in Epic 2+)
- ✅ **Analytics** - Usage tracking (production only)

### Firestore Collection Structure

The app uses three main Firestore collections for data storage:

```
firestore/
├── users/
│   └── {userId}/              # User profile documents
│       ├── id: String         # Firebase Auth UID
│       ├── email: String      # User email address
│       ├── displayName: String
│       ├── isOnline: Bool
│       ├── lastSeen: Timestamp
│       └── createdAt: Timestamp
│
├── conversations/
│   └── {conversationId}/      # Conversation metadata documents
│       ├── id: String         # UUID
│       ├── participantIds: [String]
│       ├── unreadCounts: {userId: Int}
│       ├── lastMessageText: String?
│       ├── lastMessageTimestamp: Timestamp?
│       ├── isGroup: Bool
│       └── createdAt: Timestamp
│
└── messages/
    └── {messageId}/           # Message documents
        ├── id: String         # UUID
        ├── conversationId: String (indexed)
        ├── senderId: String
        ├── text: String
        ├── timestamp: Timestamp (indexed)
        ├── status: String     # "sending", "sent", "delivered", "read"
        ├── isEdited: Bool
        ├── isDeleted: Bool
        ├── editHistory: [MessageEdit]?
        └── attachments: [MessageAttachment]?
```

**Key Indexes** (configured in `firestore.indexes.json`):
- `messages`: Composite index on `conversationId` + `timestamp` (ascending)
- `conversations`: Array-contains index on `participantIds`

**Data Access Patterns**:
- Messages queried by `conversationId` with timestamp ordering
- Conversations queried by participant using `array-contains`
- Real-time listeners on collections for live updates
- Offline persistence enabled for all collections

For complete schema details, see `docs/architecture/database-schema.md`

### Troubleshooting

**Build error: "Failed to load Firebase configuration"**
- Ensure both `.plist` files are in `MessageAI/Resources/`
- Verify files are named exactly: `GoogleService-Info-Dev.plist` and `GoogleService-Info-Prod.plist`
- Check that files are added to Xcode project (should appear in Project Navigator)

**App crashes on launch**
- Check console logs for Firebase errors
- Verify Firebase projects are active in Firebase Console
- Ensure Firestore Database is created (not just enabled)

**"Permission denied" errors**
- Security rules are deployed and working
- Users must be authenticated to access Firestore
- Check that Auth service is properly configured

**Firebase Console Links:**
- [Development Project](https://console.firebase.google.com/project/messageai-dev-1f2ec/overview)
- [Production Project](https://console.firebase.google.com/project/messageai-prod-4d3a8/overview)

---

## Development Workflow

### Building the Project

**Using the Build Script** (Recommended):

```bash
# Build with default settings (Debug, iPhone 17 Pro)
./scripts/build.sh

# Build for Release
./scripts/build.sh --config Release

# Clean build
./scripts/build.sh --action clean

# Use specific simulator
./scripts/build.sh --simulator "iPhone 15"

# Show full xcodebuild output
./scripts/build.sh --full-output

# Show help
./scripts/build.sh --help
```

**Using Xcode**:
- Press `Cmd+B` to build
- Press `Cmd+R` to build and run

### Running Tests

**⚡ Quick Test Script (Recommended)**

Use the optimized test script for fast, single-simulator testing:

```bash
# First time (builds + runs all tests)
./scripts/quick-test.sh

# Subsequent runs (fast - skips rebuild if no code changes)
./scripts/quick-test.sh --quick
# or
./scripts/quick-test.sh -q

# Run specific test suite
./scripts/quick-test.sh -q --test ConversationsListViewModelTests

# Run specific test class
./scripts/quick-test.sh -q --test AuthViewModelTests

# See all options
./scripts/quick-test.sh --help
```

**Why use quick-test.sh?**
- ✅ **10x faster**: Reuses booted simulator (~5-10 seconds vs 60-90 seconds)
- ✅ **Single simulator**: No multiple simulator windows spawning
- ✅ **Caches builds**: Skip rebuild with `--quick` flag when code unchanged
- ✅ **Better output**: Filtered, readable test results

**Alternative: Xcode UI**

```bash
# Run all tests
Cmd+U

# Run specific test class
Click diamond icon next to test class in Xcode
```

**Note**: Xcode UI may spawn multiple simulators (parallel testing). For single simulator, use `quick-test.sh`.

**Manual xcodebuild (Not Recommended)**

```bash
# Only use if quick-test.sh unavailable
xcodebuild test \
  -scheme MessageAI \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -parallel-testing-enabled NO \
  -maximum-concurrent-test-simulator-destinations 1
```

### Adding Dependencies (Swift Package Manager)

1. In Xcode: File → Add Package Dependencies
2. Enter package URL
3. Select version/branch
4. Add to MessageAI target

### Code Standards

- **Naming**: PascalCase for types, camelCase for functions/variables
- **Protocols**: Suffix with `Protocol` (e.g., `MessageRepositoryProtocol`)
- **Async/Await**: Use modern Swift concurrency (no completion handlers)
- **ViewModels**: Mark with `@MainActor` for thread safety
- **Max Function Length**: 50 lines (extract helpers for longer functions)
- **Force Unwrapping**: Forbidden except in test code

See `docs/architecture/coding-standards.md` for complete standards.

## Testing

MessageAI follows a test-first development approach with 70%+ code coverage across all layers.

### Test Structure

```
MessageAITests/
├── Domain/Entities/          # Entity model tests (User, Message, Conversation)
├── Data/
│   ├── Mocks/                # Mock repositories for unit tests
│   └── Repositories/         # Firebase repository integration tests
├── Presentation/ViewModels/  # ViewModel unit tests (AuthViewModel, ChatViewModel, etc.)
├── Integration/              # End-to-end integration tests
│   ├── RealTimeMessagingIntegrationTests.swift
│   └── OfflinePersistenceIntegrationTests.swift
└── Performance/              # Performance baseline tests
    └── PerformanceBaselineTests.swift
```

### Running Tests

**Quick Unit Tests (5-10 seconds):**
```bash
./scripts/quick-test.sh -q
```

**All Tests with Coverage:**
```bash
xcodebuild test -scheme MessageAI \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    -enableCodeCoverage YES
```

**Integration Tests (Requires Firebase Emulator):**
```bash
# Terminal 1: Start emulator
./scripts/start-emulator.sh

# Terminal 2: Run integration tests
./scripts/run-integration-tests.sh
```

**Complete Test Suite (CI-Compatible):**
```bash
./scripts/ci-test.sh
```

### Firebase Emulator Setup

Integration tests use Firebase Emulator for isolated, deterministic testing without hitting production Firebase.

#### Installation

1. **Install Firebase CLI:**
   ```bash
   npm install -g firebase-tools
   ```

2. **Start Emulator:**
   ```bash
   ./scripts/start-emulator.sh
   ```

3. **Emulator UI available at:**
   - Auth: http://localhost:9099
   - Firestore: http://localhost:8080
   - Storage: http://localhost:9199
   - Emulator UI: http://localhost:4000

#### What Integration Tests Cover

- Firebase Authentication flow (sign up, sign in, sign out)
- Real-time message sending/receiving between users
- Firestore offline persistence and sync
- Conversation creation and updates
- Message listeners and real-time updates

### Test Coverage

Current coverage (as of Story 1.10):

| Layer | Target | Actual | Status |
|-------|--------|--------|--------|
| **Domain Layer** | 80%+ | 85%+ | ✅ |
| **Data Layer** | 70%+ | 75%+ | ✅ |
| **Presentation Layer** | 75%+ | 80%+ | ✅ |
| **Overall** | 70%+ | 78%+ | ✅ |

View coverage report in Xcode: **Product → Test → Show Code Coverage**

### Performance Baselines

Established on iPhone 17 Pro Simulator with Firebase Emulator:

| Operation | Target | Notes |
|-----------|--------|-------|
| Message send | < 2 seconds | Optimistic UI makes it feel instant |
| Conversation load (50 msgs) | < 1 second | Initial screen load |
| Authentication | < 2 seconds | Sign up/sign in |

**Note:** Emulator performance is faster than production Firebase. Real-world latency will be slightly higher but still well within targets.

### Test Types

**Unit Tests (94 tests):**
- AuthViewModel: 24 tests
- ChatViewModel: 21 tests
- ConversationsListViewModel: 13 tests
- ProfileSetupViewModel: 17 tests
- Entity models: 19 tests

**Integration Tests (15 tests):**
- Firebase Authentication flow
- Real-time message sending/receiving
- Offline data persistence
- Multi-user real-time scenarios

**Performance Tests (4 tests):**
- Message send latency
- Conversation load time
- Authentication speed
- Bulk message loading

### Testing Best Practices

- **Always use quick-test.sh** for terminal testing (10x faster)
- **Mock repositories** for unit tests (no real Firebase)
- **Firebase Emulator** for integration tests (no production impact)
- **Test before committing**: `./scripts/quick-test.sh && git commit`
- **Check coverage** after adding features

See `docs/architecture/testing-best-practices.md` for detailed testing patterns and examples.

## Project Status

### Completed Stories
- ✅ Story 1.1: Project Setup & Clean Architecture Foundation

### In Progress
- 🚧 Story 1.2: Firebase Integration & Authentication (Next)

### Upcoming
- Story 1.3: Core Domain Models
- Story 1.4: Firebase Repositories
- Story 1.5: Authentication UI
- Story 1.6: Conversation List
- And more... (see `docs/prd/epic-list.md`)

## Offline Support

MessageAI is fully functional offline thanks to Firestore offline persistence:

- **View Messages**: All cached conversations and messages accessible offline
- **Send Messages**: Messages composed offline queue automatically and sync when online
- **Optimistic UI**: Sent messages appear immediately, even offline
- **Offline Indicators**: Banners notify users when offline in both conversations list and chat view
- **Zero Message Loss**: Queued messages persist across app restarts

### Testing Offline Behavior

1. Run app on simulator
2. Enable airplane mode (swipe down from top-right → enable airplane mode)
3. Navigate app - all cached data accessible
4. Send message - appears with "Sending..." status
5. Disable airplane mode - message syncs automatically

**Note**: Integration tests for offline scenarios require Firebase Emulator (Story 1.10). Current tests include comprehensive test skeletons documenting offline test coverage requirements.

## Documentation

Detailed documentation available in `docs/`:
- `docs/prd/` - Product requirements and user stories
- `docs/architecture/` - Architecture decisions and technical specifications
- `docs/stories/` - Detailed story acceptance criteria

## Contributing

This is a learning project following the BMAD (Build, Measure, Adapt, Deploy) methodology. Development follows a structured story-driven approach with:
- Test-first development
- 70%+ code coverage requirement
- Comprehensive acceptance criteria validation
- Clean Architecture enforcement

## License

Private project - All rights reserved.

---

**Built with ❤️ using Clean Architecture, SwiftUI, and Firebase**

