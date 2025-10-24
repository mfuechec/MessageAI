//
//  AuthViewModel.swift
//  MessageAI
//
//  Created by Dev Agent (James) on 10/20/25.
//  Story 1.5: Authentication UI & Flow
//

import Foundation
import Combine
import UserNotifications
import FirebaseAuth
import FirebaseFirestore

/// ViewModel for managing authentication state and user sign-in/sign-up flows
///
/// This ViewModel handles:
/// - User sign-in and sign-up with email/password
/// - Form validation (email format, password length)
/// - Error message localization for user-friendly feedback
/// - Authentication state observation for automatic re-login
/// - Toggle between sign-in and sign-up modes
///
/// Architecture:
/// - Depends on AuthRepositoryProtocol (not concrete Firebase implementation)
/// - Marked @MainActor for thread-safe UI updates
/// - Uses Swift async/await for asynchronous operations
/// - Publishes state changes to SwiftUI via @Published properties
@MainActor
class AuthViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// User's email input
    @Published var email: String = ""
    
    /// User's password input
    @Published var password: String = ""
    
    /// Indicates if authentication operation is in progress
    @Published var isLoading: Bool = false
    
    /// Error message to display to user (nil if no error)
    @Published var errorMessage: String?
    
    /// Toggles between sign-in and sign-up modes
    @Published var isSignUpMode: Bool = false
    
    /// Currently authenticated user (nil if not authenticated)
    @Published var currentUser: User?
    
    // MARK: - Dependencies
    
    /// Authentication repository for sign-in/sign-up operations
    private let authRepository: AuthRepositoryProtocol
    
    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    /// Creates AuthViewModel with injected authentication repository
    /// - Parameter authRepository: Repository for authentication operations
    init(authRepository: AuthRepositoryProtocol) {
        self.authRepository = authRepository
        
        // Observe authentication state changes (handles automatic re-login)
        observeAuthState()
    }
    
    // MARK: - Authentication Actions
    
    /// Signs in user with email and password
    ///
    /// Flow:
    /// 1. Validates form inputs (email format, password length)
    /// 2. Sets loading state and clears errors
    /// 3. Calls repository sign-in method
    /// 4. Updates currentUser on success
    /// 5. Shows localized error message on failure
    func signIn() async {
        guard validateForm() else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let user = try await authRepository.signIn(email: email, password: password)
            currentUser = user
        } catch {
            errorMessage = localizeError(error)
        }
        
        isLoading = false
    }
    
    /// Signs up new user with email and password
    ///
    /// Flow:
    /// 1. Validates form inputs (email format, password length)
    /// 2. Sets loading state and clears errors
    /// 3. Calls repository sign-up method
    /// 4. Updates currentUser on success
    /// 5. Shows localized error message on failure
    func signUp() async {
        guard validateForm() else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let user = try await authRepository.signUp(email: email, password: password)
            currentUser = user
        } catch {
            errorMessage = localizeError(error)
        }
        
        isLoading = false
    }
    
    /// Toggles between sign-in and sign-up modes
    ///
    /// Clears error message when switching modes
    func toggleMode() {
        isSignUpMode.toggle()
        errorMessage = nil
    }
    
    /// Signs out the current user
    ///
    /// Story 2.10a: Cleans up FCM token and app state on sign-out
    /// to prevent cross-user notification leakage
    func signOut() async {
        // Step 1: Clear FCM token from Firestore (Story 2.10a)
        // Prevents old user from receiving notifications after new user signs in
        if let userId = currentUser?.id, !userId.isEmpty {
            do {
                let db = Firestore.firestore()
                try await db.collection("users").document(userId).updateData([
                    "fcmToken": FieldValue.delete(),
                    "fcmTokenUpdatedAt": FieldValue.delete()
                ])
                print("✅ FCM token removed for user: \(userId)")
            } catch {
                print("⚠️ Failed to remove FCM token: \(error.localizedDescription)")
                // Don't block sign-out if this fails
            }
        }

        // Step 2: Clear app state (Story 2.10a)
        await MainActor.run {
            AppState.shared.clearState()
        }

        // Step 3: Sign out from Firebase Auth (existing logic)
        do {
            try await authRepository.signOut()
            currentUser = nil
            email = ""
            password = ""
            errorMessage = nil
        } catch {
            errorMessage = "Failed to sign out. Please try again."
        }
    }
    
    /// Refreshes the current user from the repository
    /// Useful after profile updates to ensure UI reflects latest data
    func refreshCurrentUser() async {
        guard let userId = currentUser?.id else { return }
        
        do {
            // Fetch latest user data from Firestore
            let updatedUser = try await authRepository.getCurrentUser()
            currentUser = updatedUser
        } catch {
            // Silently fail - user can retry or sign out
            print("Failed to refresh user: \(error)")
        }
    }
    
    // MARK: - Notification Permissions
    
    /// Requests notification permissions from the user
    ///
    /// Should be called after successful authentication and profile setup
    /// to avoid permission fatigue during onboarding.
    ///
    /// Flow:
    /// 1. Request authorization for alerts, sounds, and badges
    /// 2. If granted, register for remote notifications
    /// 3. If denied, user can still use app (just won't get push notifications)
    func requestNotificationPermissions() async {
        let center = UNUserNotificationCenter.current()
        
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            
            if granted {
                print("✅ Notification permission granted")
                // Register for remote notifications on main thread (UIApplication requirement)
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } else {
                print("⚠️ Notification permission denied by user")
            }
        } catch {
            print("❌ Notification permission error: \(error)")
        }
    }
    
    // MARK: - Form Validation
    
    /// Validates form inputs before submission
    ///
    /// Validation rules:
    /// - Email must match valid email format
    /// - Password must be at least 6 characters (Firebase requirement)
    ///
    /// - Returns: true if form is valid, false otherwise
    func validateForm() -> Bool {
        // Validate email format
        guard isValidEmail(email) else {
            errorMessage = "Please enter a valid email address"
            return false
        }
        
        // Validate password length (Firebase requires minimum 6 characters)
        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters"
            return false
        }
        
        return true
    }
    
    /// Checks if email string matches valid email format
    /// - Parameter email: Email string to validate
    /// - Returns: true if email format is valid
    private func isValidEmail(_ email: String) -> Bool {
        let emailPattern = "^[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES[c] %@", emailPattern)
        return emailPredicate.evaluate(with: email)
    }
    
    // MARK: - Error Handling
    
    /// Converts Firebase errors to user-friendly messages
    ///
    /// Maps Firebase Auth error codes to localized strings
    ///
    /// - Parameter error: Error from Firebase Auth
    /// - Returns: User-friendly error message
    func localizeError(_ error: Error) -> String {
        let nsError = error as NSError
        let errorCode = nsError.domain
        
        switch errorCode {
        case "auth/invalid-email":
            return "Please enter a valid email address"
        case "auth/weak-password":
            return "Password must be at least 6 characters"
        case "auth/email-already-in-use":
            return "An account with this email already exists"
        case "auth/user-not-found":
            return "No account found with this email"
        case "auth/wrong-password":
            return "Incorrect password"
        case "auth/network-request-failed":
            return "Network error. Please check your connection."
        default:
            return "Authentication failed. Please try again."
        }
    }
    
    // MARK: - Authentication State Observation
    
    /// Observes authentication state changes for automatic re-login
    ///
    /// Firebase Auth persists authentication state in iOS Keychain.
    /// This observer ensures currentUser is updated when:
    /// - App launches with existing authenticated session
    /// - User signs in
    /// - User signs out
    /// - Token expires or is invalidated
    private func observeAuthState() {
        authRepository.observeAuthState()
            .sink { [weak self] user in
                self?.currentUser = user
            }
            .store(in: &cancellables)
    }
}

