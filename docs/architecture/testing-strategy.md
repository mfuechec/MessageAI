# Testing Strategy

Comprehensive testing approach achieving 70%+ code coverage with test-first development workflow.

## Testing Pyramid

```
        E2E Tests (5%)
       /              \
      /                \
     Integration Tests (15%)
    /                    \
   /                      \
  Unit Tests (80%)
```

## Unit Testing (XCTest)

**Target:** 70%+ coverage for Domain and Data layers

**Test Structure:**

```
MessageAITests/
├── Domain/
│   ├── UseCases/
│   │   ├── SendMessageUseCaseTests.swift
│   │   ├── SummarizeThreadUseCaseTests.swift
│   │   └── ...
│   └── Entities/
│       ├── MessageTests.swift
│       └── ConversationTests.swift
│
├── Data/
│   ├── Repositories/
│   │   ├── FirebaseMessageRepositoryTests.swift
│   │   └── FirebaseAuthRepositoryTests.swift
│   └── Mocks/
│       ├── MockMessageRepository.swift
│       ├── MockFirestore.swift
│       └── MockAIService.swift
│
└── Presentation/
    └── ViewModels/
        ├── ChatViewModelTests.swift
        ├── AuthViewModelTests.swift
        └── InsightsDashboardViewModelTests.swift
```

**Example Unit Test:**

```swift
// ChatViewModelTests.swift
@MainActor
final class ChatViewModelTests: XCTestCase {
    var sut: ChatViewModel!
    var mockMessageRepo: MockMessageRepository!
    var mockUserRepo: MockUserRepository!
    var mockAIService: MockAIService!
    
    override func setUp() {
        super.setUp()
        mockMessageRepo = MockMessageRepository()
        mockUserRepo = MockUserRepository()
        mockAIService = MockAIService()
        
        sut = ChatViewModel(
            conversationId: "test-convo",
            messageRepository: mockMessageRepo,
            userRepository: mockUserRepo,
            aiService: mockAIService
        )
    }
    
    func testSendMessage_OptimisticUIUpdate() async throws {
        // Given
        let messageText = "Hello, world!"
        XCTAssertEqual(sut.messages.count, 0)
        
        // When
        await sut.sendMessage(messageText)
        
        // Then
        XCTAssertEqual(sut.messages.count, 1)
        XCTAssertEqual(sut.messages.first?.text, messageText)
        XCTAssertEqual(sut.messages.first?.status, .sending)
    }
    
    func testSummarizeThread_Success() async throws {
        // Given
        let expectedSummary = "This is a test summary"
        mockAIService.mockSummary = expectedSummary
        
        // When
        await sut.summarizeThread()
        
        // Then
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.errorMessage)
        XCTAssertTrue(mockAIService.summarizeCalled)
    }
    
    func testSendMessage_Failure_ShowsError() async throws {
        // Given
        mockMessageRepo.shouldFail = true
        
        // When
        await sut.sendMessage("Test")
        
        // Then
        XCTAssertNotNil(sut.errorMessage)
    }
}
```

## Integration Testing

**Target:** Key workflows with real Firebase interactions

**Test Firebase Emulator Suite:**

```bash
# Install Firebase Emulator
npm install -g firebase-tools

# Start emulators for testing
firebase emulators:start --only firestore,auth,functions
```

**Example Integration Test:**

```swift
// MessageIntegrationTests.swift
final class MessageIntegrationTests: XCTestCase {
    var firebaseService: FirebaseService!
    var messageRepo: FirebaseMessageRepository!
    
    override func setUp() {
        super.setUp()
        // Configure to use emulator
        let settings = Firestore.firestore().settings
        settings.host = "localhost:8080"
        settings.isSSLEnabled = false
        Firestore.firestore().settings = settings
        
        firebaseService = FirebaseService()
        messageRepo = FirebaseMessageRepository(firebaseService: firebaseService)
    }
    
    func testSendAndRetrieveMessage() async throws {
        // Given
        let message = Message(/* test data */)
        
        // When
        try await messageRepo.sendMessage(message)
        
        let messages = try await messageRepo.getMessages(conversationId: message.conversationId)
        
        // Then
        XCTAssertTrue(messages.contains(where: { $0.id == message.id }))
    }
}
```

## UI Testing (XCTest UI)

**Target:** Critical user flows

```swift
// MessageAIUITests/AuthFlowTests.swift
final class AuthFlowTests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI-Testing"]
        app.launch()
    }
    
    func testSignUpAndSendMessage() throws {
        // Sign up
        let emailField = app.textFields["Email"]
        emailField.tap()
        emailField.typeText("test@example.com")
        
        let passwordField = app.secureTextFields["Password"]
        passwordField.tap()
        passwordField.typeText("password123")
        
        app.buttons["Sign Up"].tap()
        
        // Verify navigated to conversations
        XCTAssertTrue(app.navigationBars["Messages"].exists)
        
        // Create conversation
        app.buttons["New Conversation"].tap()
        
        // Send message
        let messageField = app.textFields["Message"]
        messageField.tap()
        messageField.typeText("Hello!")
        app.buttons["Send"].tap()
        
        // Verify message appears
        XCTAssertTrue(app.staticTexts["Hello!"].exists)
    }
}
```

## Test Coverage Goals

| Layer | Target Coverage | Rationale |
|-------|----------------|-----------|
| Domain (UseCases) | 90%+ | Pure business logic, fully testable |
| Domain (Entities) | 80%+ | Test computed properties and validation |
| Data (Repositories) | 70%+ | Core data operations, use mocks |
| Presentation (ViewModels) | 75%+ | UI state logic, use mock repositories |
| Presentation (Views) | 30%+ | SwiftUI views, UI tests cover critical flows |

## Mock Implementations

```swift
// MockMessageRepository.swift
class MockMessageRepository: MessageRepositoryProtocol {
    var messages: [Message] = []
    var shouldFail = false
    var sendMessageCalled = false
    
    func sendMessage(_ message: Message) async throws {
        sendMessageCalled = true
        if shouldFail {
            throw NSError(domain: "Test", code: -1)
        }
        messages.append(message)
    }
    
    func observeMessages(conversationId: String) -> AnyPublisher<[Message], Never> {
        Just(messages.filter { $0.conversationId == conversationId })
            .eraseToAnyPublisher()
    }
    
    // ... other methods
}
```

---
