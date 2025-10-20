//
//  AuthView.swift
//  MessageAI
//
//  Created by Dev Agent (James) on 10/20/25.
//  Story 1.5: Authentication UI & Flow
//

import SwiftUI
import Combine

/// Authentication view for user sign-in and sign-up
///
/// This view provides:
/// - Email and password text fields with appropriate keyboard types
/// - Toggle between sign-in and sign-up modes
/// - Loading states with spinner during authentication
/// - Error message display with user-friendly text
/// - Automatic navigation on successful authentication
/// - Dark mode support via semantic colors
/// - VoiceOver accessibility labels
struct AuthView: View {
    
    // MARK: - Properties
    
    /// ViewModel managing authentication state and logic
    @StateObject var viewModel: AuthViewModel
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // App Logo / Branding
            appLogo
            
            Spacer()
            
            // Email TextField
            emailField
            
            // Password SecureField
            passwordField
            
            // Error Message
            if let errorMessage = viewModel.errorMessage {
                errorMessageView(errorMessage)
            }
            
            // Sign In / Sign Up Button
            authButton
            
            // Switch Mode Button
            switchModeButton
            
            Spacer()
        }
        .padding(.horizontal, 32)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Subviews
    
    /// App logo and branding section
    private var appLogo: some View {
        VStack(spacing: 8) {
            Image(systemName: "message.fill")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)
                .accessibilityLabel("MessageAI logo")
            
            Text("MessageAI")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(viewModel.isSignUpMode ? "Create your account" : "Welcome back")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    /// Email text field with appropriate keyboard configuration
    private var emailField: some View {
        TextField("Email", text: $viewModel.email)
            .keyboardType(.emailAddress)
            .textContentType(.emailAddress)
            .autocapitalization(.none)
            .disableAutocorrection(true)
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)
            .accessibilityLabel("Email")
            .accessibilityHint("Enter your email address")
    }
    
    /// Password secure field with password autofill support
    private var passwordField: some View {
        SecureField("Password", text: $viewModel.password)
            .textContentType(.password)
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)
            .accessibilityLabel("Password")
            .accessibilityHint("Enter your password")
    }
    
    /// Error message view with red text
    private func errorMessageView(_ message: String) -> some View {
        Text(message)
            .foregroundColor(.red)
            .font(.caption)
            .multilineTextAlignment(.center)
            .accessibilityLabel("Error: \(message)")
    }
    
    /// Primary authentication button (Sign In / Sign Up)
    private var authButton: some View {
        Button(action: {
            Task {
                if viewModel.isSignUpMode {
                    await viewModel.signUp()
                } else {
                    await viewModel.signIn()
                }
            }
        }) {
            HStack {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                        .accessibilityLabel(viewModel.isSignUpMode ? "Signing up" : "Signing in")
                } else {
                    Text(viewModel.isSignUpMode ? "Sign Up" : "Sign In")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(viewModel.isLoading ? Color.gray : Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .disabled(viewModel.isLoading)
        .accessibilityLabel(viewModel.isSignUpMode ? "Sign Up" : "Sign In")
        .accessibilityHint(viewModel.isSignUpMode ? "Create a new account" : "Sign in with your email and password")
    }
    
    /// Button to toggle between sign-in and sign-up modes
    private var switchModeButton: some View {
        Button(action: {
            viewModel.toggleMode()
        }) {
            Text(viewModel.isSignUpMode
                 ? "Already have an account? Sign In"
                 : "Don't have an account? Sign Up")
                .font(.subheadline)
                .foregroundColor(.accentColor)
        }
        .accessibilityLabel(viewModel.isSignUpMode ? "Switch to Sign In" : "Switch to Sign Up")
        .accessibilityHint("Switch between sign in and sign up modes")
    }
}

// MARK: - Preview

struct AuthView_Previews: PreviewProvider {
    static var previews: some View {
        // Preview with mock repository for SwiftUI previews
        Group {
            // Light mode
            AuthView(viewModel: AuthViewModel(authRepository: MockAuthRepositoryForPreview()))
                .preferredColorScheme(.light)
            
            // Dark mode
            AuthView(viewModel: AuthViewModel(authRepository: MockAuthRepositoryForPreview()))
                .preferredColorScheme(.dark)
        }
    }
}

/// Mock repository for SwiftUI previews only
private class MockAuthRepositoryForPreview: AuthRepositoryProtocol {
    func signIn(email: String, password: String) async throws -> User {
        User(id: "preview", email: email, displayName: "Preview User", isOnline: true, lastSeen: Date(), createdAt: Date())
    }
    
    func signUp(email: String, password: String) async throws -> User {
        User(id: "preview", email: email, displayName: "Preview User", isOnline: true, lastSeen: Date(), createdAt: Date())
    }
    
    func signOut() async throws {}
    
    func getCurrentUser() async throws -> User? { nil }
    
    func observeAuthState() -> AnyPublisher<User?, Never> {
        Just(nil).eraseToAnyPublisher()
    }
}

