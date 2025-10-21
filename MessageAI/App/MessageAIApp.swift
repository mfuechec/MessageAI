//
//  MessageAIApp.swift
//  MessageAI
//
//  Created by Mark Fuechec on 10/20/25.
//  Updated by Dev Agent (James) on 10/20/25 - Story 1.5
//

import SwiftUI

@main
struct MessageAIApp: App {
    
    /// Authentication ViewModel for managing user sign-in/sign-up state
    /// StateObject ensures ViewModel persists across app lifecycle
    @StateObject private var authViewModel = DIContainer.shared.makeAuthViewModel()
    
    /// Initialize Firebase on app launch
    /// FirebaseService.shared triggers Firebase configuration with environment-specific settings
    init() {
        _ = FirebaseService.shared
    }
    
    var body: some Scene {
        WindowGroup {
            // Conditional navigation based on authentication state
            // Firebase Auth automatically restores authenticated session on app launch
            if let currentUser = authViewModel.currentUser {
                // Check if user needs profile setup
                if needsProfileSetup(currentUser) {
                    // Create ProfileSetupViewModel with authViewModel for navigation updates
                    let profileViewModel = ProfileSetupViewModel(
                        userRepository: DIContainer.shared.userRepository,
                        authRepository: DIContainer.shared.authRepository,
                        currentUser: currentUser,
                        authViewModel: authViewModel
                    )
                    ProfileSetupView(viewModel: profileViewModel, authViewModel: authViewModel)
                } else {
                    // Show Conversations List after profile setup complete
                    ConversationsListView(
                        viewModel: DIContainer.shared.makeConversationsListViewModel(currentUserId: currentUser.id)
                    )
                    .environmentObject(authViewModel)
                }
            } else {
                AuthView(viewModel: authViewModel)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Determines if user needs to complete profile setup
    /// - Parameter user: The authenticated user
    /// - Returns: True if profile setup is needed, false otherwise
    ///
    /// Note: Uses UserDefaults for MVP. Production should use a `hasCompletedProfileSetup: Bool`
    /// flag in the User entity stored in Firestore.
    private func needsProfileSetup(_ user: User) -> Bool {
        // Check if user has completed profile setup (persisted in UserDefaults)
        let hasCompleted = UserDefaults.standard.bool(forKey: "hasCompletedProfileSetup_\(user.id)")
        return !hasCompleted
    }
}
