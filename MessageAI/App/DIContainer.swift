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
    ///
    /// **IMPORTANT:** Not lazy - initialized eagerly in init() to ensure
    /// monitoring starts immediately at app launch. This gives NWPathMonitor
    /// time to establish baseline connectivity before any views appear,
    /// preventing the offline banner from missing initial offline states.
    private var networkMonitor: NetworkMonitor

    /// Offline queue store (Story 2.9)
    /// Manages persistent storage of queued messages composed while offline
    private lazy var offlineQueueStore: OfflineQueueStore = OfflineQueueStore()

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
        FirebaseStorageRepository(firebaseService: firebaseService)
    }()

    /// Notification preferences repository (Epic 6 - Story 6.4)
    /// Manages user preferences for smart AI-powered notifications
    internal lazy var notificationPreferencesRepository: NotificationPreferencesRepositoryProtocol = {
        FirebaseNotificationPreferencesRepository(firebaseService: firebaseService)
    }()

    /// Notification analysis repository (Epic 6 - Story 6.1)
    /// Calls Cloud Function to analyze conversations for notification decisions
    internal lazy var notificationAnalysisRepository: NotificationAnalysisRepositoryProtocol = {
        FirebaseNotificationAnalysisRepository(firebaseService: firebaseService)
    }()

    /// Notification history repository (Epic 6 - Story 6.5)
    /// Manages notification decision history and user feedback
    internal lazy var notificationHistoryRepository: NotificationHistoryRepositoryProtocol = {
        FirebaseNotificationHistoryRepository()
    }()

    // MARK: - Notification Services (Epic 6)

    /// Conversation activity monitor (Epic 6 - Story 6.1)
    /// Monitors message activity and triggers notification analysis
    internal lazy var conversationActivityMonitor: ConversationActivityMonitor = {
        ConversationActivityMonitor(repository: notificationAnalysisRepository)
    }()

    // MARK: - AI Services (Story 3.1)

    /// Cloud Functions service (Story 3.1)
    /// Low-level wrapper for calling Firebase Cloud Functions
    private lazy var cloudFunctionsService: CloudFunctionsService = {
        CloudFunctionsService()
    }()

    /// AI service (Story 3.1)
    /// High-level AI features: thread summarization, action item extraction, smart search
    internal lazy var aiService: AIServiceProtocol = {
        FirebaseAIService(cloudFunctionsService: cloudFunctionsService)
    }()

    // MARK: - Initialization

    private init() {
        // Initialize Firebase service (Story 1.2)
        self.firebaseService = FirebaseService.shared

        // Initialize NetworkMonitor eagerly to start monitoring immediately
        // This ensures NWPathMonitor has time to establish baseline connectivity
        // before any views appear, preventing offline banner timing issues
        self.networkMonitor = NetworkMonitor()

        print("✅ DIContainer initialized with eager NetworkMonitor")
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
            storageRepository: storageRepository,
            networkMonitor: networkMonitor,
            offlineQueueStore: offlineQueueStore,  // Story 2.9
            initialConversation: initialConversation,
            initialParticipants: initialParticipants,
            aiService: aiService  // Story 3.1: Inject for debug testing
        )
    }
    
    /// Creates ConversationsListViewModel for displaying conversation list
    /// - Parameter currentUserId: The ID of the current user viewing conversations
    /// - Returns: Configured ConversationsListViewModel instance
    func makeConversationsListViewModel(currentUserId: String) -> ConversationsListViewModel {
        ConversationsListViewModel(
            conversationRepository: conversationRepository,
            userRepository: userRepository,
            notificationAnalysisRepository: notificationAnalysisRepository,
            currentUserId: currentUserId,
            networkMonitor: networkMonitor,
            aiService: aiService,  // For summary staleness detection
            messageRepository: messageRepository  // For notification simulation in DEBUG + staleness detection
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

    /// Creates SummaryViewModel for thread summarization (Story 3.2)
    /// - Parameters:
    ///   - conversationId: The conversation to summarize
    ///   - userId: Current user ID for per-user cache
    ///   - messageIds: Optional specific message IDs to summarize
    /// - Returns: Configured SummaryViewModel instance
    func makeSummaryViewModel(
        conversationId: String,
        userId: String,
        messageIds: [String]? = nil
    ) -> SummaryViewModel {
        SummaryViewModel(
            conversationId: conversationId,
            userId: userId,
            messageIds: messageIds,
            aiService: aiService
        )
    }

    /// Creates NotificationPreferencesViewModel for smart notifications (Epic 6 - Story 6.4)
    /// - Parameter userId: The user ID for preferences
    /// - Returns: Configured NotificationPreferencesViewModel instance
    func makeNotificationPreferencesViewModel(userId: String) -> NotificationPreferencesViewModel {
        NotificationPreferencesViewModel(
            repository: notificationPreferencesRepository,
            userId: userId
        )
    }

    /// Creates NotificationHistoryViewModel for viewing notification history (Epic 6 - Story 6.5)
    /// - Parameter userId: The user ID for history
    /// - Returns: Configured NotificationHistoryViewModel instance
    func makeNotificationHistoryViewModel(userId: String) -> NotificationHistoryViewModel {
        print("🏭 [DIContainer] Creating NotificationHistoryViewModel for userId: \(userId)")
        let vm = NotificationHistoryViewModel(
            repository: notificationHistoryRepository,
            userId: userId
        )
        print("🏭 [DIContainer] NotificationHistoryViewModel created")
        return vm
    }
}

