//
//  AuthViewModelTests.swift
//  MessageAITests
//
//  Created by Dev Agent (James) on 10/20/25.
//  Story 1.5: Authentication UI & Flow
//

import XCTest
import Combine
@testable import MessageAI

/// Unit tests for AuthViewModel
///
/// Tests cover:
/// - Successful sign-in and sign-up flows
/// - Error handling and error message display
/// - Form validation (email format, password length)
/// - Mode toggling between sign-in and sign-up
/// - Authentication state observation
@MainActor
final class AuthViewModelTests: XCTestCase {
    
    // MARK: - Properties
    
    var mockRepository: MockAuthRepository!
    var sut: AuthViewModel!
    var cancellables: Set<AnyCancellable>!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        mockRepository = MockAuthRepository()
        sut = AuthViewModel(authRepository: mockRepository)
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables = nil
        sut = nil
        mockRepository = nil
        super.tearDown()
    }
    
    // MARK: - Sign In Tests
    
    func testSignIn_Success_SetsCurrentUser() async throws {
        // Given
        let testEmail = "test@example.com"
        let testPassword = "password123"
        sut.email = testEmail
        sut.password = testPassword
        
        // When
        await sut.signIn()
        
        // Then
        XCTAssertTrue(mockRepository.signInCalled, "signIn should be called on repository")
        XCTAssertNotNil(sut.currentUser, "currentUser should be set after successful sign-in")
        XCTAssertEqual(sut.currentUser?.email, testEmail, "currentUser email should match input")
        XCTAssertNil(sut.errorMessage, "errorMessage should be nil on success")
        XCTAssertFalse(sut.isLoading, "isLoading should be false after completion")
    }
    
    func testSignIn_Failure_ShowsError() async throws {
        // Given
        mockRepository.shouldFail = true
        mockRepository.mockError = NSError(domain: "auth/wrong-password", code: -1)
        sut.email = "test@example.com"
        sut.password = "wrongpassword"
        
        // When
        await sut.signIn()
        
        // Then
        XCTAssertTrue(mockRepository.signInCalled, "signIn should be called on repository")
        XCTAssertNotNil(sut.errorMessage, "errorMessage should be set on failure")
        XCTAssertNil(sut.currentUser, "currentUser should be nil on failure")
        XCTAssertFalse(sut.isLoading, "isLoading should be false after completion")
    }
    
    func testSignIn_InvalidEmail_ShowsValidationError() async throws {
        // Given
        sut.email = "invalid-email"
        sut.password = "password123"
        
        // When
        await sut.signIn()
        
        // Then
        XCTAssertFalse(mockRepository.signInCalled, "signIn should NOT be called with invalid email")
        XCTAssertNotNil(sut.errorMessage, "errorMessage should be set for validation failure")
        XCTAssertEqual(sut.errorMessage, "Please enter a valid email address")
    }
    
    func testSignIn_ShortPassword_ShowsValidationError() async throws {
        // Given
        sut.email = "test@example.com"
        sut.password = "12345" // Only 5 characters, minimum is 6
        
        // When
        await sut.signIn()
        
        // Then
        XCTAssertFalse(mockRepository.signInCalled, "signIn should NOT be called with short password")
        XCTAssertNotNil(sut.errorMessage, "errorMessage should be set for validation failure")
        XCTAssertEqual(sut.errorMessage, "Password must be at least 6 characters")
    }
    
    func testSignIn_LoadingState_SetCorrectly() async throws {
        // Given
        sut.email = "test@example.com"
        sut.password = "password123"
        
        // When
        XCTAssertFalse(sut.isLoading, "isLoading should start as false")
        
        // Start sign-in without awaiting to check intermediate state
        Task {
            await sut.signIn()
        }
        
        // Give a tiny delay for async task to start
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        // Note: In real Firebase calls, isLoading would be true during the call
        // Our mock completes instantly, so we mainly verify it's false after completion
        
        // Wait for completion
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        // Then
        XCTAssertFalse(sut.isLoading, "isLoading should be false after completion")
    }
    
    // MARK: - Sign Up Tests
    
    func testSignUp_Success_CreatesUser() async throws {
        // Given
        let testEmail = "newuser@example.com"
        let testPassword = "password123"
        sut.email = testEmail
        sut.password = testPassword
        sut.isSignUpMode = true
        
        // When
        await sut.signUp()
        
        // Then
        XCTAssertTrue(mockRepository.signUpCalled, "signUp should be called on repository")
        XCTAssertNotNil(sut.currentUser, "currentUser should be set after successful sign-up")
        XCTAssertEqual(sut.currentUser?.email, testEmail, "currentUser email should match input")
        XCTAssertNil(sut.errorMessage, "errorMessage should be nil on success")
        XCTAssertFalse(sut.isLoading, "isLoading should be false after completion")
    }
    
    func testSignUp_Failure_ShowsError() async throws {
        // Given
        mockRepository.shouldFail = true
        mockRepository.mockError = NSError(domain: "auth/email-already-in-use", code: -1)
        sut.email = "existing@example.com"
        sut.password = "password123"
        sut.isSignUpMode = true
        
        // When
        await sut.signUp()
        
        // Then
        XCTAssertTrue(mockRepository.signUpCalled, "signUp should be called on repository")
        XCTAssertNotNil(sut.errorMessage, "errorMessage should be set on failure")
        XCTAssertNil(sut.currentUser, "currentUser should be nil on failure")
        XCTAssertFalse(sut.isLoading, "isLoading should be false after completion")
    }
    
    func testSignUp_InvalidEmail_ShowsValidationError() async throws {
        // Given
        sut.email = "not-an-email"
        sut.password = "password123"
        sut.isSignUpMode = true
        
        // When
        await sut.signUp()
        
        // Then
        XCTAssertFalse(mockRepository.signUpCalled, "signUp should NOT be called with invalid email")
        XCTAssertNotNil(sut.errorMessage, "errorMessage should be set for validation failure")
        XCTAssertEqual(sut.errorMessage, "Please enter a valid email address")
    }
    
    func testSignUp_ShortPassword_ShowsValidationError() async throws {
        // Given
        sut.email = "test@example.com"
        sut.password = "abc" // Only 3 characters
        sut.isSignUpMode = true
        
        // When
        await sut.signUp()
        
        // Then
        XCTAssertFalse(mockRepository.signUpCalled, "signUp should NOT be called with short password")
        XCTAssertNotNil(sut.errorMessage, "errorMessage should be set for validation failure")
        XCTAssertEqual(sut.errorMessage, "Password must be at least 6 characters")
    }
    
    // MARK: - Form Validation Tests
    
    func testValidateForm_InvalidEmail_ReturnsFalse() {
        // Given
        sut.email = "invalid-email"
        sut.password = "password123"
        
        // When
        let result = sut.validateForm()
        
        // Then
        XCTAssertFalse(result, "validateForm should return false for invalid email")
        XCTAssertNotNil(sut.errorMessage, "errorMessage should be set")
        XCTAssertEqual(sut.errorMessage, "Please enter a valid email address")
    }
    
    func testValidateForm_ShortPassword_ReturnsFalse() {
        // Given
        sut.email = "test@example.com"
        sut.password = "short"
        
        // When
        let result = sut.validateForm()
        
        // Then
        XCTAssertFalse(result, "validateForm should return false for short password")
        XCTAssertNotNil(sut.errorMessage, "errorMessage should be set")
        XCTAssertEqual(sut.errorMessage, "Password must be at least 6 characters")
    }
    
    func testValidateForm_ValidInputs_ReturnsTrue() {
        // Given
        sut.email = "valid@example.com"
        sut.password = "validpass123"
        
        // When
        let result = sut.validateForm()
        
        // Then
        XCTAssertTrue(result, "validateForm should return true for valid inputs")
    }
    
    func testValidateForm_EmptyEmail_ReturnsFalse() {
        // Given
        sut.email = ""
        sut.password = "password123"
        
        // When
        let result = sut.validateForm()
        
        // Then
        XCTAssertFalse(result, "validateForm should return false for empty email")
        XCTAssertNotNil(sut.errorMessage, "errorMessage should be set")
    }
    
    func testValidateForm_EmptyPassword_ReturnsFalse() {
        // Given
        sut.email = "test@example.com"
        sut.password = ""
        
        // When
        let result = sut.validateForm()
        
        // Then
        XCTAssertFalse(result, "validateForm should return false for empty password")
        XCTAssertNotNil(sut.errorMessage, "errorMessage should be set")
    }
    
    // MARK: - Mode Toggle Tests
    
    func testToggleMode_SwitchesAuthMode() {
        // Given
        let initialMode = sut.isSignUpMode
        sut.errorMessage = "Some error"
        
        // When
        sut.toggleMode()
        
        // Then
        XCTAssertNotEqual(sut.isSignUpMode, initialMode, "isSignUpMode should toggle")
        XCTAssertNil(sut.errorMessage, "errorMessage should be cleared when toggling mode")
    }
    
    func testToggleMode_MultipleTimes_WorksCorrectly() {
        // Given
        XCTAssertFalse(sut.isSignUpMode, "Should start in sign-in mode")
        
        // When/Then
        sut.toggleMode()
        XCTAssertTrue(sut.isSignUpMode, "Should switch to sign-up mode")
        
        sut.toggleMode()
        XCTAssertFalse(sut.isSignUpMode, "Should switch back to sign-in mode")
        
        sut.toggleMode()
        XCTAssertTrue(sut.isSignUpMode, "Should switch to sign-up mode again")
    }
    
    // MARK: - Error Localization Tests
    
    func testLocalizeError_InvalidEmail() {
        // Given
        let error = NSError(domain: "auth/invalid-email", code: -1)
        
        // When
        let message = sut.localizeError(error)
        
        // Then
        XCTAssertEqual(message, "Please enter a valid email address")
    }
    
    func testLocalizeError_WeakPassword() {
        // Given
        let error = NSError(domain: "auth/weak-password", code: -1)
        
        // When
        let message = sut.localizeError(error)
        
        // Then
        XCTAssertEqual(message, "Password must be at least 6 characters")
    }
    
    func testLocalizeError_EmailAlreadyInUse() {
        // Given
        let error = NSError(domain: "auth/email-already-in-use", code: -1)
        
        // When
        let message = sut.localizeError(error)
        
        // Then
        XCTAssertEqual(message, "An account with this email already exists")
    }
    
    func testLocalizeError_UserNotFound() {
        // Given
        let error = NSError(domain: "auth/user-not-found", code: -1)
        
        // When
        let message = sut.localizeError(error)
        
        // Then
        XCTAssertEqual(message, "No account found with this email")
    }
    
    func testLocalizeError_WrongPassword() {
        // Given
        let error = NSError(domain: "auth/wrong-password", code: -1)
        
        // When
        let message = sut.localizeError(error)
        
        // Then
        XCTAssertEqual(message, "Incorrect password")
    }
    
    func testLocalizeError_NetworkError() {
        // Given
        let error = NSError(domain: "auth/network-request-failed", code: -1)
        
        // When
        let message = sut.localizeError(error)
        
        // Then
        XCTAssertEqual(message, "Network error. Please check your connection.")
    }
    
    func testLocalizeError_UnknownError() {
        // Given
        let error = NSError(domain: "auth/unknown-error", code: -1)
        
        // When
        let message = sut.localizeError(error)
        
        // Then
        XCTAssertEqual(message, "Authentication failed. Please try again.")
    }
    
    // MARK: - Auth State Observation Tests
    
    func testObserveAuthState_UpdatesCurrentUser() async throws {
        // Given
        let testUser = User(
            id: "observed-user",
            email: "observed@example.com",
            displayName: "Observed User",
            isOnline: true,
            lastSeen: Date(),
            createdAt: Date()
        )
        mockRepository.mockUser = testUser
        
        // Create new ViewModel to trigger observeAuthState in init
        let newSut = AuthViewModel(authRepository: mockRepository)
        
        // Small delay to allow Combine to propagate
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        
        // Then
        XCTAssertNotNil(newSut.currentUser, "currentUser should be set from auth state observer")
        XCTAssertEqual(newSut.currentUser?.id, testUser.id)
    }
}

