//
//  ProfileSetupViewModel.swift
//  MessageAI
//
//  Created by Dev Agent on 2025-10-20.
//

import Foundation
import Combine
import UIKit

@MainActor
class ProfileSetupViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var displayName: String = ""
    @Published var profileImageURL: String? = nil
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var profileSaved: Bool = false
    
    // MARK: - Dependencies
    
    private let userRepository: UserRepositoryProtocol
    private let authRepository: AuthRepositoryProtocol
    private let currentUser: User
    private let authViewModel: AuthViewModel?
    
    // MARK: - Initialization
    
    init(
        userRepository: UserRepositoryProtocol,
        authRepository: AuthRepositoryProtocol,
        currentUser: User,
        authViewModel: AuthViewModel? = nil
    ) {
        self.userRepository = userRepository
        self.authRepository = authRepository
        self.currentUser = currentUser
        self.authViewModel = authViewModel
        
        // Pre-fill display name with email prefix as default
        self.displayName = defaultDisplayName(from: currentUser.email)
    }
    
    // MARK: - Public Methods
    
    /// Saves the profile to Firestore with user-provided display name
    func saveProfile() async {
        guard validateDisplayName() else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Create updated user with new display name
            var updatedUser = currentUser
            updatedUser.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            updatedUser.profileImageURL = profileImageURL
            
            // Save to Firestore
            try await userRepository.updateUser(updatedUser)
            
            // Mark profile setup as complete (persists across app restarts)
            UserDefaults.standard.set(true, forKey: "hasCompletedProfileSetup_\(currentUser.id)")
            
            // Refresh auth state so navigation updates
            await authViewModel?.refreshCurrentUser()
            
            profileSaved = true
        } catch {
            errorMessage = "Failed to save profile. Please try again."
        }
        
        isLoading = false
    }
    
    /// Skips profile setup and uses default display name (email prefix)
    func skipSetup() {
        // Use default display name (email prefix)
        displayName = defaultDisplayName(from: currentUser.email)
        
        Task {
            await saveProfile()
        }
    }
    
    /// Uploads profile image to Firebase Storage
    /// - Parameter image: The UIImage to upload
    func uploadProfileImage(_ image: UIImage) async {
        isLoading = true
        
        do {
            // Convert UIImage to Data
            guard let imageData = image.jpegData(compressionQuality: 0.7) else {
                errorMessage = "Failed to process image"
                isLoading = false
                return
            }
            
            // Upload to Firebase Storage
            // Path: users/{userId}/profile.jpg
            let storagePath = "users/\(currentUser.id)/profile.jpg"
            
            // Note: Firebase Storage integration will be needed from FirebaseService
            // This is a placeholder for future Firebase Storage implementation
            // After upload, set profileImageURL to the download URL
            
            // For MVP, we'll skip actual upload and just note the requirement
            // profileImageURL = downloadURL
        } catch {
            errorMessage = "Failed to upload image"
        }
        
        isLoading = false
    }
    
    /// Placeholder for photo picker trigger (will be called from view)
    func selectProfileImage() {
        // Will integrate PHPickerViewController in implementation
        // For now, this method will be called when user taps profile image
    }
    
    // MARK: - Private Methods
    
    /// Validates the display name meets requirements
    /// - Returns: True if valid, false otherwise
    func validateDisplayName() -> Bool {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            errorMessage = "Display name cannot be empty"
            return false
        }
        
        if trimmed.count > 50 {
            errorMessage = "Display name must be 50 characters or less"
            return false
        }
        
        return true
    }
    
    /// Extracts default display name from email (prefix before @)
    /// - Parameter email: User's email address
    /// - Returns: Email prefix or "User" if extraction fails
    private func defaultDisplayName(from email: String) -> String {
        email.components(separatedBy: "@").first ?? "User"
    }
}

