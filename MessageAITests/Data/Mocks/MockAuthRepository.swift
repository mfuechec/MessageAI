//
//  MockAuthRepository.swift
//  MessageAITests
//
//  Created by Dev Agent (James) on 10/20/25.
//  Story 1.5: Authentication UI & Flow
//

import Foundation
import Combine
@testable import MessageAI

/// Mock implementation of AuthRepositoryProtocol for testing
///
/// This mock allows tests to:
/// - Verify repository methods are called correctly
/// - Simulate success and failure scenarios
/// - Test authentication logic without Firebase dependencies
/// - Control return values and errors
class MockAuthRepository: AuthRepositoryProtocol {
    
    // MARK: - Tracking Properties
    
    /// Indicates if signIn was called
    var signInCalled = false
    
    /// Indicates if signUp was called
    var signUpCalled = false
    
    /// Indicates if signOut was called
    var signOutCalled = false
    
    /// Indicates if getCurrentUser was called
    var getCurrentUserCalled = false
    
    // MARK: - Mock Configuration
    
    /// Controls whether operations should fail
    var shouldFail = false
    
    /// Mock user to return on successful operations
    var mockUser: User?
    
    /// Mock error to throw on failure
    var mockError: Error?
    
    /// Captured email from last signIn/signUp call
    var capturedEmail: String?
    
    /// Captured password from last signIn/signUp call
    var capturedPassword: String?
    
    // MARK: - AuthRepositoryProtocol Implementation
    
    func signIn(email: String, password: String) async throws -> User {
        signInCalled = true
        capturedEmail = email
        capturedPassword = password
        
        if shouldFail {
            throw mockError ?? NSError(domain: "auth/wrong-password", code: -1)
        }
        
        return mockUser ?? User(
            id: "test-user",
            email: email,
            displayName: "Test User",
            isOnline: true,
            lastSeen: Date(),
            createdAt: Date()
        )
    }
    
    func signUp(email: String, password: String) async throws -> User {
        signUpCalled = true
        capturedEmail = email
        capturedPassword = password
        
        if shouldFail {
            throw mockError ?? NSError(domain: "auth/email-already-in-use", code: -1)
        }
        
        return mockUser ?? User(
            id: "new-user",
            email: email,
            displayName: "New User",
            isOnline: true,
            lastSeen: Date(),
            createdAt: Date()
        )
    }
    
    func signOut() async throws {
        signOutCalled = true
        
        if shouldFail {
            throw mockError ?? NSError(domain: "auth/sign-out-failed", code: -1)
        }
    }
    
    func getCurrentUser() async throws -> User? {
        getCurrentUserCalled = true
        
        if shouldFail {
            throw mockError ?? NSError(domain: "auth/get-user-failed", code: -1)
        }
        
        return mockUser
    }
    
    func observeAuthState() -> AnyPublisher<User?, Never> {
        Just(mockUser).eraseToAnyPublisher()
    }
    
    // MARK: - Helper Methods
    
    /// Resets all tracking flags and mock data
    func reset() {
        signInCalled = false
        signUpCalled = false
        signOutCalled = false
        getCurrentUserCalled = false
        shouldFail = false
        mockUser = nil
        mockError = nil
        capturedEmail = nil
        capturedPassword = nil
    }
}

