//
//  DIContainer.swift
//  MessageAI
//
//  Created by Dev Agent (James) on 10/20/25.
//

import Foundation

/// Dependency Injection Container for MessageAI
///
/// This container manages the creation and lifecycle of dependencies throughout the app.
/// It follows the Dependency Injection pattern to enable:
/// - Testability: ViewModels can be tested with mock dependencies
/// - Loose coupling: Components depend on protocols, not concrete implementations
/// - Centralized configuration: All dependency wiring happens in one place
///
/// Architecture Pattern:
/// - Repositories are created lazily on first access
/// - Factory methods provide ViewModels with injected dependencies
/// - All dependencies flow from protocols, enabling test mocking
///
/// Usage:
/// ```swift
/// let container = DIContainer.shared
/// let authViewModel = container.makeAuthViewModel()
/// ```
class DIContainer {
    
    // MARK: - Singleton Instance
    
    /// Shared instance for app-wide dependency access
    /// Note: For testing, you can create separate instances with mock dependencies
    static let shared = DIContainer()
    
    // MARK: - Services
    
    /// Firebase service instance (Story 1.2)
    /// Provides access to Firestore, Auth, and Storage
    private let firebaseService: FirebaseService
    
    /// Network monitor instance (Story 1.9)
    /// Tracks network connectivity status for offline indicators
    private lazy var networkMonitor: NetworkMonitor = NetworkMonitor()
    
    // MARK: - Repositories
    
    /// Message repository (Story 1.4)
    /// Handles message CRUD operations and real-time synchronization
    internal lazy var messageRepository: MessageRepositoryProtocol = {
        FirebaseMessageRepository(firebaseService: firebaseService)
    }()
    
    /// User repository (Story 1.4)
    /// Manages user profile data and presence status
    internal lazy var userRepository: UserRepositoryProtocol = {
        FirebaseUserRepository(firebaseService: firebaseService)
    }()
    
    /// Conversation repository (Story 1.4)
    /// Handles conversation metadata and participant management
    internal lazy var conversationRepository: ConversationRepositoryProtocol = {
        FirebaseConversationRepository(firebaseService: firebaseService)
    }()
    
    /// Authentication repository (Story 1.4)
    /// Manages user authentication and session state
    /// Note: Depends on userRepository for profile data after auth
    internal lazy var authRepository: AuthRepositoryProtocol = {
        FirebaseAuthRepository(
            firebaseService: firebaseService,
            userRepository: userRepository
        )
    }()
    
    /// Storage repository (Story 2.1)
    /// Handles file uploads to Firebase Storage (profile images, attachments)
    internal lazy var storageRepository: StorageRepositoryProtocol = {
        FirebaseStorageRepository()
    }()
    
    // MARK: - Initialization
    
    private init() {
        // Initialize Firebase service (Story 1.2)
        self.firebaseService = FirebaseService.shared
    }
    
    // MARK: - Factory Methods for ViewModels
    
    // Note: ViewModels will be implemented in future stories (1.5+)
    // These factory methods are ready for use when ViewModels are created
    
    /// Creates AuthViewModel with authentication repository
    /// - Returns: Configured AuthViewModel instance
    func makeAuthViewModel() -> AuthViewModel {
        AuthViewModel(authRepository: authRepository)
    }
    
    /// Creates ProfileSetupViewModel for profile configuration after sign-up
    /// - Parameter currentUser: The user who needs profile setup
    /// - Returns: Configured ProfileSetupViewModel instance
    func makeProfileSetupViewModel(currentUser: User) -> ProfileSetupViewModel {
        ProfileSetupViewModel(
            userRepository: userRepository,
            authRepository: authRepository,
            storageRepository: storageRepository,
            currentUser: currentUser
        )
    }
    
    /// Creates ChatViewModel for a specific conversation
    /// - Parameters:
    ///   - conversationId: The conversation to display
    ///   - currentUserId: The ID of the current user
    /// - Returns: Configured ChatViewModel instance
    func makeChatViewModel(
        conversationId: String,
        currentUserId: String,
        initialConversation: Conversation? = nil,
        initialParticipants: [User]? = nil
    ) -> ChatViewModel {
        ChatViewModel(
            conversationId: conversationId,
            currentUserId: currentUserId,
            messageRepository: messageRepository,
            conversationRepository: conversationRepository,
            userRepository: userRepository,
            networkMonitor: networkMonitor,
            initialConversation: initialConversation,
            initialParticipants: initialParticipants
        )
    }
    
    /// Creates ConversationsListViewModel for displaying conversation list
    /// - Parameter currentUserId: The ID of the current user viewing conversations
    /// - Returns: Configured ConversationsListViewModel instance
    func makeConversationsListViewModel(currentUserId: String) -> ConversationsListViewModel {
        ConversationsListViewModel(
            conversationRepository: conversationRepository,
            userRepository: userRepository,
            currentUserId: currentUserId,
            networkMonitor: networkMonitor,
            messageRepository: messageRepository  // For notification simulation in DEBUG
        )
    }
    
    /// Creates NewConversationViewModel for starting new conversations (Story 2.0)
    /// - Returns: Configured NewConversationViewModel instance
    func makeNewConversationViewModel() -> NewConversationViewModel {
        NewConversationViewModel(
            userRepository: userRepository,
            conversationRepository: conversationRepository,
            authRepository: authRepository
        )
    }
}

