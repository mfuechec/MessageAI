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
/// Usage Pattern:
/// 1. DIContainer creates repositories with concrete implementations (Firebase, etc.)
/// 2. Factory methods provide ViewModels injected with repository protocols
/// 3. Views receive ViewModels from DIContainer, never creating their own
///
/// Example (will be implemented in future stories):
/// ```
/// let container = DIContainer.shared
/// let authViewModel = container.makeAuthViewModel()
/// ```
class DIContainer {
    
    // MARK: - Singleton Instance
    
    /// Shared instance for app-wide dependency access
    /// Note: For testing, you can create separate instances with mock dependencies
    static let shared = DIContainer()
    
    // MARK: - Initialization
    
    private init() {
        // Future stories will initialize core services here:
        // - Firebase configuration (Story 1.2)
        // - Repository instances (Story 1.4)
        // - Network services (Story 1.4)
    }
    
    // MARK: - Factory Methods
    
    // Factory methods will be added as features are implemented in future stories
    // Each factory method creates a ViewModel with its required dependencies
    //
    // Example structure (to be implemented):
    //
    // func makeAuthViewModel() -> AuthViewModel {
    //     return AuthViewModel(authRepository: authRepository)
    // }
    //
    // func makeChatViewModel(conversationId: String) -> ChatViewModel {
    //     return ChatViewModel(
    //         conversationId: conversationId,
    //         messageRepository: messageRepository,
    //         userRepository: userRepository
    //     )
    // }
}

