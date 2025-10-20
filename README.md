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

3. **Firebase Configuration** (Story 1.2)
   - Firebase setup will be added in Story 1.2
   - `GoogleService-Info.plist` configuration coming soon

4. **Install Dependencies** (Story 1.2+)
   - Swift Package Manager dependencies will be added via Xcode
   - File → Add Package Dependencies
   - Dependencies: Firebase SDK, MessageKit, Kingfisher

5. **Build and Run**
   - Select MessageAI scheme
   - Choose simulator or physical device
   - Press `Cmd+R` to build and run

## Development Workflow

### Adding Dependencies (Swift Package Manager)

1. In Xcode: File → Add Package Dependencies
2. Enter package URL
3. Select version/branch
4. Add to MessageAI target

### Running Tests

```bash
# Run all tests
Cmd+U in Xcode

# Run specific test class
Cmd+U with test file open
```

### Code Standards

- **Naming**: PascalCase for types, camelCase for functions/variables
- **Protocols**: Suffix with `Protocol` (e.g., `MessageRepositoryProtocol`)
- **Async/Await**: Use modern Swift concurrency (no completion handlers)
- **ViewModels**: Mark with `@MainActor` for thread safety
- **Max Function Length**: 50 lines (extract helpers for longer functions)
- **Force Unwrapping**: Forbidden except in test code

See `docs/architecture/coding-standards.md` for complete standards.

## Testing Strategy

### Test Coverage Goals

- **Domain Layer**: 70%+ coverage (pure Swift, fast unit tests)
- **Data Layer**: 70%+ coverage (use mocked Firebase services)
- **ViewModels**: 75%+ coverage (use protocol-based repository mocks)
- **Overall Target**: 70%+ code coverage

### Test Structure

```
MessageAITests/
├── Domain/                # Domain entity and use case tests
├── Data/                  # Repository implementation tests
└── Presentation/          # ViewModel tests
```

### Mocking Strategy

- Repository protocols enable testing with mock implementations
- No Firebase SDK calls in tests (use protocol mocks)
- Fast test execution: Unit tests run in milliseconds

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

