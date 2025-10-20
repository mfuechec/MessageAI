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
            if authViewModel.currentUser != nil {
                // Story 1.7 will implement ConversationsListView
                Text("Conversations List (Coming in Story 1.7)")
                    .font(.title)
                    .foregroundColor(.secondary)
            } else {
                AuthView(viewModel: authViewModel)
            }
        }
    }
}
