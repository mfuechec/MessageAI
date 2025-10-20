//
//  MockUserRepository.swift
//  MessageAITests
//
//  Created by Dev Agent on 2025-10-20.
//

import Foundation
import Combine
@testable import MessageAI

/// Mock implementation of UserRepositoryProtocol for testing
/// Follows consistent mock pattern established in Story 1.5
class MockUserRepository: UserRepositoryProtocol {
    
    // MARK: - Tracking Properties
    
    var getUserCalled = false
    var updateUserCalled = false
    var observeUserPresenceCalled = false
    var updateOnlineStatusCalled = false
    
    // MARK: - Configurable Behavior
    
    var shouldFail = false
    var mockUser: User?
    var mockError: Error = NSError(domain: "mock-error", code: -1, userInfo: [NSLocalizedDescriptionKey: "Mock error"])
    
    // MARK: - Captured Parameters
    
    var capturedUserId: String?
    var capturedUser: User?
    var capturedIsOnline: Bool?
    
    // MARK: - UserRepositoryProtocol Implementation
    
    func getUser(id: String) async throws -> User {
        getUserCalled = true
        capturedUserId = id
        
        if shouldFail {
            throw mockError
        }
        
        guard let user = mockUser else {
            throw NSError(domain: "mock-error", code: -1, userInfo: [NSLocalizedDescriptionKey: "No mock user configured"])
        }
        
        return user
    }
    
    func updateUser(_ user: User) async throws {
        updateUserCalled = true
        capturedUser = user
        
        if shouldFail {
            throw mockError
        }
        
        // Simulate successful update
        mockUser = user
    }
    
    func observeUserPresence(userId: String) -> AnyPublisher<Bool, Never> {
        observeUserPresenceCalled = true
        capturedUserId = userId
        
        // Return a simple publisher that emits false
        return Just(false).eraseToAnyPublisher()
    }
    
    func updateOnlineStatus(isOnline: Bool) async throws {
        updateOnlineStatusCalled = true
        capturedIsOnline = isOnline
        
        if shouldFail {
            throw mockError
        }
    }
    
    // MARK: - Helper Methods
    
    /// Resets all tracking flags and captured parameters
    func reset() {
        getUserCalled = false
        updateUserCalled = false
        observeUserPresenceCalled = false
        updateOnlineStatusCalled = false
        shouldFail = false
        mockUser = nil
        capturedUserId = nil
        capturedUser = nil
        capturedIsOnline = nil
    }
}

