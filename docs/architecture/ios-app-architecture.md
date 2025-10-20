# iOS App Architecture

Detailed breakdown of the iOS application's Clean Architecture implementation with MVVM pattern.

## Layer Structure

```
MessageAI/
├── App/
│   ├── MessageAIApp.swift          # SwiftUI App entry point
│   ├── SceneDelegate.swift         # Scene lifecycle (if needed)
│   └── DIContainer.swift           # Dependency injection container
│
├── Domain/                          # Pure Swift, no external dependencies
│   ├── Entities/
│   │   ├── User.swift
│   │   ├── Message.swift
│   │   ├── Conversation.swift
│   │   ├── ActionItem.swift
│   │   ├── Decision.swift
│   │   └── AICacheEntry.swift
│   │
│   ├── UseCases/
│   │   ├── Auth/
│   │   │   ├── SignInUseCase.swift
│   │   │   ├── SignUpUseCase.swift
│   │   │   └── SignOutUseCase.swift
│   │   ├── Messaging/
│   │   │   ├── SendMessageUseCase.swift
│   │   │   ├── EditMessageUseCase.swift
│   │   │   ├── DeleteMessageUseCase.swift
│   │   │   └── ObserveMessagesUseCase.swift
│   │   ├── Conversations/
│   │   │   ├── CreateConversationUseCase.swift
│   │   │   ├── ObserveConversationsUseCase.swift
│   │   │   └── UpdateTypingStatusUseCase.swift
│   │   └── AI/
│   │       ├── SummarizeThreadUseCase.swift
│   │       ├── ExtractActionItemsUseCase.swift
│   │       ├── SearchConversationsUseCase.swift
│   │       ├── DetectPriorityUseCase.swift
│   │       └── SuggestMeetingTimesUseCase.swift
│   │
│   └── Repositories/                # Protocol definitions only
│       ├── AuthRepositoryProtocol.swift
│       ├── MessageRepositoryProtocol.swift
│       ├── ConversationRepositoryProtocol.swift
│       ├── UserRepositoryProtocol.swift
│       ├── ActionItemRepositoryProtocol.swift
│       ├── DecisionRepositoryProtocol.swift
│       └── AIServiceProtocol.swift
│
├── Data/                            # Firebase implementations
│   ├── Repositories/
│   │   ├── FirebaseAuthRepository.swift
│   │   ├── FirebaseMessageRepository.swift
│   │   ├── FirebaseConversationRepository.swift
│   │   ├── FirebaseUserRepository.swift
│   │   ├── FirebaseActionItemRepository.swift
│   │   ├── FirebaseDecisionRepository.swift
│   │   └── FirebaseAIService.swift
│   │
│   ├── Network/
│   │   ├── FirebaseService.swift       # Firestore/Auth initialization
│   │   ├── StorageService.swift        # Firebase Storage wrapper
│   │   └── CloudFunctionsService.swift # Cloud Functions caller
│   │
│   └── Models/                          # Firebase DTOs (if needed)
│       └── FirestoreMappers.swift      # Entity <-> Firestore conversions
│
├── Presentation/
│   ├── ViewModels/
│   │   ├── Auth/
│   │   │   ├── AuthViewModel.swift
│   │   │   └── ProfileSetupViewModel.swift
│   │   ├── Conversations/
│   │   │   ├── ConversationsListViewModel.swift
│   │   │   └── NewConversationViewModel.swift
│   │   ├── Chat/
│   │   │   ├── ChatViewModel.swift
│   │   │   └── MessageInputViewModel.swift
│   │   ├── Insights/
│   │   │   ├── InsightsDashboardViewModel.swift
│   │   │   ├── ActionItemsViewModel.swift
│   │   │   └── DecisionsViewModel.swift
│   │   └── Settings/
│   │       └── SettingsViewModel.swift
│   │
│   ├── Views/
│   │   ├── Auth/
│   │   │   ├── AuthView.swift
│   │   │   └── ProfileSetupView.swift
│   │   ├── Conversations/
│   │   │   ├── ConversationsListView.swift
│   │   │   ├── ConversationRowView.swift
│   │   │   └── NewConversationView.swift
│   │   ├── Chat/
│   │   │   ├── ChatView.swift
│   │   │   ├── MessageBubbleView.swift (MessageKit integration)
│   │   │   ├── MessageInputBar.swift
│   │   │   └── AIFeaturesSheet.swift
│   │   ├── Insights/
│   │   │   ├── InsightsDashboardView.swift
│   │   │   ├── PriorityMessagesView.swift
│   │   │   ├── ActionItemsView.swift
│   │   │   └── DecisionsView.swift
│   │   └── Settings/
│   │       └── SettingsView.swift
│   │
│   └── Components/                      # Reusable UI components
│       ├── LoadingView.swift
│       ├── ErrorView.swift
│       ├── EmptyStateView.swift
│       ├── OfflineBannerView.swift
│       └── UserAvatarView.swift
│
└── Resources/
    ├── Assets.xcassets                  # Images, colors, icons
    ├── GoogleService-Info.plist         # Firebase config (gitignored)
    └── Info.plist
```

## Dependency Injection

```swift
// DIContainer.swift
class DIContainer {
    // Singletons
    private let firebaseService: FirebaseService
    private let cloudFunctionsService: CloudFunctionsService
    private let storageService: StorageService
    
    // Repositories (lazy initialization)
    private lazy var authRepository: AuthRepositoryProtocol = 
        FirebaseAuthRepository(firebaseService: firebaseService)
    
    private lazy var messageRepository: MessageRepositoryProtocol = 
        FirebaseMessageRepository(firebaseService: firebaseService)
    
    private lazy var conversationRepository: ConversationRepositoryProtocol = 
        FirebaseConversationRepository(firebaseService: firebaseService)
    
    private lazy var userRepository: UserRepositoryProtocol = 
        FirebaseUserRepository(firebaseService: firebaseService)
    
    private lazy var aiService: AIServiceProtocol = 
        FirebaseAIService(cloudFunctionsService: cloudFunctionsService)
    
    init() {
        self.firebaseService = FirebaseService()
        self.cloudFunctionsService = CloudFunctionsService()
        self.storageService = StorageService()
    }
    
    // Factory methods for ViewModels
    func makeAuthViewModel() -> AuthViewModel {
        AuthViewModel(authRepository: authRepository)
    }
    
    func makeChatViewModel(conversationId: String) -> ChatViewModel {
        ChatViewModel(
            conversationId: conversationId,
            messageRepository: messageRepository,
            userRepository: userRepository,
            aiService: aiService
        )
    }
    
    // ... other factory methods
}
```

## ViewModel Pattern

```swift
// Example: ChatViewModel.swift
@MainActor
class ChatViewModel: ObservableObject {
    // Published state for SwiftUI binding
    @Published var messages: [Message] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var isOffline: Bool = false
    
    // Dependencies (injected via DI)
    private let messageRepository: MessageRepositoryProtocol
    private let userRepository: UserRepositoryProtocol
    private let aiService: AIServiceProtocol
    
    private let conversationId: String
    private var cancellables = Set<AnyCancellable>()
    
    init(
        conversationId: String,
        messageRepository: MessageRepositoryProtocol,
        userRepository: UserRepositoryProtocol,
        aiService: AIServiceProtocol
    ) {
        self.conversationId = conversationId
        self.messageRepository = messageRepository
        self.userRepository = userRepository
        self.aiService = aiService
        
        observeMessages()
    }
    
    func sendMessage(_ text: String) async {
        do {
            let message = Message(
                id: UUID().uuidString,
                conversationId: conversationId,
                senderId: currentUserId,
                text: text,
                timestamp: Date(),
                status: .sending,
                // ... other fields
            )
            
            // Optimistic UI update
            messages.append(message)
            
            // Background save
            try await messageRepository.sendMessage(message)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func summarizeThread() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let summary = try await aiService.summarizeThread(
                conversationId: conversationId
            )
            // Handle summary
        } catch {
            errorMessage = "AI summary failed: \\(error.localizedDescription)"
        }
    }
    
    private func observeMessages() {
        messageRepository.observeMessages(conversationId: conversationId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] messages in
                self?.messages = messages
            }
            .store(in: &cancellables)
    }
}
```

## Repository Pattern Implementation

```swift
// Protocol definition (Domain layer)
protocol MessageRepositoryProtocol {
    func sendMessage(_ message: Message) async throws
    func observeMessages(conversationId: String) -> AnyPublisher<[Message], Never>
    func editMessage(id: String, newText: String) async throws
    func deleteMessage(id: String) async throws
}

// Firebase implementation (Data layer)
class FirebaseMessageRepository: MessageRepositoryProtocol {
    private let db: Firestore
    
    init(firebaseService: FirebaseService) {
        self.db = firebaseService.firestore
    }
    
    func sendMessage(_ message: Message) async throws {
        let data = try Firestore.Encoder().encode(message)
        try await db.collection("messages").document(message.id).setData(data)
    }
    
    func observeMessages(conversationId: String) -> AnyPublisher<[Message], Never> {
        let subject = PassthroughSubject<[Message], Never>()
        
        db.collection("messages")
            .whereField("conversationId", isEqualTo: conversationId)
            .order(by: "timestamp")
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else { return }
                
                let messages = documents.compactMap { doc -> Message? in
                    try? doc.data(as: Message.self)
                }
                
                subject.send(messages)
            }
        
        return subject.eraseToAnyPublisher()
    }
    
    func editMessage(id: String, newText: String) async throws {
        let editEntry = MessageEdit(text: newText, editedAt: Date())
        
        try await db.collection("messages").document(id).updateData([
            "text": newText,
            "isEdited": true,
            "editHistory": FieldValue.arrayUnion([editEntry])
        ])
    }
    
    func deleteMessage(id: String) async throws {
        try await db.collection("messages").document(id).updateData([
            "isDeleted": true,
            "deletedAt": FieldValue.serverTimestamp()
        ])
    }
}
```

---
