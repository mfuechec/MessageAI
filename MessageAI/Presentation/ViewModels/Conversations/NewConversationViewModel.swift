//
//  NewConversationViewModel.swift
//  MessageAI
//
//  Created by Dev Agent (James) on 10/21/25.
//  Story 2.0: Start New Conversation with Duplicate Prevention
//

import Foundation
import Combine

/// ViewModel for starting new conversations with user selection and duplicate prevention
@MainActor
class NewConversationViewModel: ObservableObject {
    // MARK: - Published State
    
    @Published var users: [User] = []
    @Published var filteredUsers: [User] = []
    @Published var searchText: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var selectedConversation: Conversation?  // For navigation trigger (observed by parent)
    
    // MARK: - Dependencies
    
    private let userRepository: UserRepositoryProtocol
    private let conversationRepository: ConversationRepositoryProtocol
    private let authRepository: AuthRepositoryProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(
        userRepository: UserRepositoryProtocol,
        conversationRepository: ConversationRepositoryProtocol,
        authRepository: AuthRepositoryProtocol
    ) {
        self.userRepository = userRepository
        self.conversationRepository = conversationRepository
        self.authRepository = authRepository
        
        setupSearchObserver()
    }
    
    // MARK: - Public Methods
    
    /// Load all users from repository, excluding current user
    /// Note: For MVP, shows all users. Future enhancement: Implement contacts/friends system.
    func loadUsers() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let allUsers = try await userRepository.getAllUsers()
            
            // Filter out current user
            guard let currentUser = try await authRepository.getCurrentUser() else {
                errorMessage = "Authentication required. Please sign in again."
                isLoading = false
                return
            }
            
            // Filter: exclude current user only
            users = allUsers.filter { user in
                user.id != currentUser.id
            }
            filteredUsers = users
            
            print("✅ Loaded \(users.count) users (excluding current user)")
            
        } catch {
            errorMessage = "Failed to load users: \(error.localizedDescription)"
            print("❌ Failed to load users: \(error)")
        }
        
        isLoading = false
    }
    
    /// Select a user and get or create conversation
    /// - Parameter user: The user to start a conversation with
    func selectUser(_ user: User) async {
        isLoading = true
        errorMessage = nil
        
        do {
            guard let currentUser = try await authRepository.getCurrentUser() else {
                errorMessage = "Authentication required. Please sign in again."
                isLoading = false
                return
            }
            
            // Prevent self-conversation
            guard user.id != currentUser.id else {
                errorMessage = "You cannot start a conversation with yourself."
                isLoading = false
                return
            }
            
            print("🔍 Getting or creating conversation with user: \(user.displayName)")
            
            let participantIds = [currentUser.id, user.id]
            let conversation = try await conversationRepository.getOrCreateConversation(
                participantIds: participantIds
            )
            
            // Set selected conversation (parent will observe this change)
            await MainActor.run {
                selectedConversation = conversation
                print("✅ Conversation ready for navigation: \(conversation.id)")
            }
            
        } catch {
            errorMessage = "Failed to create conversation: \(error.localizedDescription)"
            print("❌ Failed to create conversation: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Private Methods
    
    /// Set up search text observer with debouncing
    private func setupSearchObserver() {
        $searchText
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] searchText in
                self?.filterUsers(searchText)
            }
            .store(in: &cancellables)
    }
    
    /// Filter users by search text (display name or email)
    /// - Parameter searchText: The text to filter by
    private func filterUsers(_ searchText: String) {
        if searchText.isEmpty {
            filteredUsers = users
        } else {
            filteredUsers = users.filter { user in
                user.displayName.localizedCaseInsensitiveContains(searchText) ||
                user.email.localizedCaseInsensitiveContains(searchText)
            }
            print("🔍 Filtered to \(filteredUsers.count) users for query: '\(searchText)'")
        }
    }
}

