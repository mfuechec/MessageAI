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
    private let storageRepository: StorageRepositoryProtocol
    private let currentUser: User
    private let authViewModel: AuthViewModel?
    
    // MARK: - Initialization
    
    init(
        userRepository: UserRepositoryProtocol,
        authRepository: AuthRepositoryProtocol,
        storageRepository: StorageRepositoryProtocol,
        currentUser: User,
        authViewModel: AuthViewModel? = nil
    ) {
        self.userRepository = userRepository
        self.authRepository = authRepository
        self.storageRepository = storageRepository
        self.currentUser = currentUser
        self.authViewModel = authViewModel
        
        // Pre-fill display name with email prefix as default
        self.displayName = defaultDisplayName(from: currentUser.email)
    }
    
    // MARK: - Public Methods
    
    /// Saves the profile to Firestore with user-provided display name
    func saveProfile() async {
        print("🔵 [ProfileSetup] saveProfile() called")
        print("🔵 [ProfileSetup] saveProfile() - self.profileImageURL at start: \(String(describing: self.profileImageURL))")
        
        guard validateDisplayName() else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Create updated user with new display name and profile image (if uploaded)
            var updatedUser = currentUser
            updatedUser.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            // Use the profileImageURL from local state (set during image upload)
            updatedUser.profileImageURL = self.profileImageURL
            
            print("🔵 [ProfileSetup] saveProfile() - updatedUser.displayName: \(updatedUser.displayName)")
            print("🔵 [ProfileSetup] saveProfile() - updatedUser.profileImageURL: \(String(describing: updatedUser.profileImageURL))")
            
            // Save to Firestore
            try await userRepository.updateUser(updatedUser)
            print("✅ [ProfileSetup] saveProfile() - User updated in Firestore with profileImageURL: \(String(describing: updatedUser.profileImageURL))")
            
            // Mark profile setup as complete (persists across app restarts)
            UserDefaults.standard.set(true, forKey: "hasCompletedProfileSetup_\(currentUser.id)")
            
            // Refresh auth state so navigation updates (now safe because Firestore has the profileImageURL)
            print("🔵 [ProfileSetup] saveProfile() - Now refreshing auth view model...")
            await authViewModel?.refreshCurrentUser()
            print("✅ [ProfileSetup] saveProfile() - Auth view model refreshed with Firestore data")
            
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
        print("🔵 [ProfileSetup] uploadProfileImage called for user: \(currentUser.id)")
        isLoading = true
        errorMessage = nil
        
        do {
            print("🔵 [ProfileSetup] Starting upload to Storage...")
            // Upload to Firebase Storage
            let downloadURL = try await storageRepository.uploadProfileImage(image, userId: currentUser.id)
            print("✅ [ProfileSetup] Storage upload succeeded. URL: \(downloadURL)")
            
            // Update local state
            self.profileImageURL = downloadURL
            print("🔵 [ProfileSetup] Local state updated. profileImageURL = \(String(describing: self.profileImageURL))")
            
            // Update Firestore user document with new profile image URL
            do {
                print("🔵 [ProfileSetup] Preparing to update Firestore...")
                print("🔵 [ProfileSetup] Current user ID: \(currentUser.id)")
                print("🔵 [ProfileSetup] Current user email: \(currentUser.email)")
                print("🔵 [ProfileSetup] Current user displayName: \(currentUser.displayName)")
                
                var updatedUser = currentUser
                updatedUser.profileImageURL = downloadURL
                
                print("🔵 [ProfileSetup] Updated user profileImageURL: \(String(describing: updatedUser.profileImageURL))")
                print("🔵 [ProfileSetup] Calling userRepository.updateUser()...")
                
                try await userRepository.updateUser(updatedUser)
                
                print("✅ [ProfileSetup] Profile image uploaded and saved to Firestore")
                print("✅ [ProfileSetup] Firestore document should now have profileImageURL: \(downloadURL)")
                
                // Don't refresh auth view model here - it would reset our @Published profileImageURL
                // The refresh will happen when saveProfile() is called after the user presses Continue
                print("✅ [ProfileSetup] Skipping auth refresh to preserve local profileImageURL state")
            } catch {
                // Image uploaded but Firestore update failed
                errorMessage = "Image uploaded but couldn't save. Please try again."
                print("❌ [ProfileSetup] Firestore update failed after successful upload: \(error)")
                print("❌ [ProfileSetup] Error type: \(type(of: error))")
                print("❌ [ProfileSetup] Error description: \(error.localizedDescription)")
            }
        } catch let error as StorageError {
            // User-friendly storage error messages
            errorMessage = error.localizedDescription
            print("❌ [ProfileSetup] Profile image upload failed (StorageError): \(error)")
        } catch {
            // Generic fallback error
            errorMessage = "Unable to upload image. Please check your connection and try again."
            print("❌ [ProfileSetup] Profile image upload failed (generic): \(error)")
            print("❌ [ProfileSetup] Error type: \(type(of: error))")
        }
        
        isLoading = false
        print("🔵 [ProfileSetup] uploadProfileImage completed. isLoading = false")
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

