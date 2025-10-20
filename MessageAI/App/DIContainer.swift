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
    
    // MARK: - Repositories
    
    /// Message repository (Story 1.4)
    /// Handles message CRUD operations and real-time synchronization
    private lazy var messageRepository: MessageRepositoryProtocol = {
        FirebaseMessageRepository(firebaseService: firebaseService)
    }()
    
    /// User repository (Story 1.4)
    /// Manages user profile data and presence status
    private lazy var userRepository: UserRepositoryProtocol = {
        FirebaseUserRepository(firebaseService: firebaseService)
    }()
    
    /// Conversation repository (Story 1.4)
    /// Handles conversation metadata and participant management
    private lazy var conversationRepository: ConversationRepositoryProtocol = {
        FirebaseConversationRepository(firebaseService: firebaseService)
    }()
    
    /// Authentication repository (Story 1.4)
    /// Manages user authentication and session state
    /// Note: Depends on userRepository for profile data after auth
    private lazy var authRepository: AuthRepositoryProtocol = {
        FirebaseAuthRepository(
            firebaseService: firebaseService,
            userRepository: userRepository
        )
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
    
    /// Creates ChatViewModel for a specific conversation
    /// - Parameter conversationId: The conversation to display
    /// - Returns: Configured ChatViewModel instance
    func makeChatViewModel(conversationId: String) -> ChatViewModel {
        ChatViewModel(
            conversationId: conversationId,
            messageRepository: messageRepository,
            userRepository: userRepository
        )
    }
    
    /// Creates ConversationsListViewModel for displaying conversation list
    /// - Returns: Configured ConversationsListViewModel instance
    func makeConversationsListViewModel() -> ConversationsListViewModel {
        ConversationsListViewModel(
            conversationRepository: conversationRepository,
            userRepository: userRepository
        )
    }
}

// MARK: - Placeholder ViewModels

// These placeholder classes allow DIContainer to compile
// They will be replaced with real implementations in future stories

/// Placeholder ChatViewModel (will be implemented in Story 1.7+)
class ChatViewModel {
    init(conversationId: String, messageRepository: MessageRepositoryProtocol, userRepository: UserRepositoryProtocol) {}
}

/// Placeholder ConversationsListViewModel (will be implemented in Story 1.7+)
class ConversationsListViewModel {
    init(conversationRepository: ConversationRepositoryProtocol, userRepository: UserRepositoryProtocol) {}
}

