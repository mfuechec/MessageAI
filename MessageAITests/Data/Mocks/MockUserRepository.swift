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
    var getUsersCalled = false
    var getAllUsersCalled = false
    var updateUserCalled = false
    var observeUserPresenceCalled = false
    var updateOnlineStatusCalled = false
    var updateCurrentConversationCalled = false  // Story 2.10 QA Fix
    var updateFCMTokenCalled = false  // Story 2.10 QA Fix
    
    // MARK: - Configurable Behavior
    
    var shouldFail = false
    var mockUser: User?
    var mockUsers: [User] = []
    var mockError: Error = NSError(domain: "mock-error", code: -1, userInfo: [NSLocalizedDescriptionKey: "Mock error"])
    
    // MARK: - Captured Parameters
    
    var capturedUserId: String?
    var capturedUserIds: [String]?
    var capturedUser: User?
    var capturedIsOnline: Bool?
    var capturedConversationId: String?  // Story 2.10 QA Fix
    var capturedFCMToken: String?  // Story 2.10 QA Fix
    
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
    
    func getUsers(ids: [String]) async throws -> [User] {
        getUsersCalled = true
        capturedUserIds = ids
        
        if shouldFail {
            throw mockError
        }
        
        // Return users from mockUsers that match the requested IDs
        return mockUsers.filter { ids.contains($0.id) }
    }
    
    func getAllUsers() async throws -> [User] {
        getAllUsersCalled = true
        
        if shouldFail {
            throw mockError
        }
        
        return mockUsers
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

    // Story 2.10 QA Fix
    func updateCurrentConversation(conversationId: String?) async throws {
        updateCurrentConversationCalled = true
        capturedConversationId = conversationId

        if shouldFail {
            throw mockError
        }
    }

    // Story 2.10 QA Fix
    func updateFCMToken(_ token: String, userId: String?) async throws {
        updateFCMTokenCalled = true
        capturedFCMToken = token
        capturedUserId = userId

        if shouldFail {
            throw mockError
        }
    }

    // MARK: - Helper Methods
    
    /// Resets all tracking flags and captured parameters
    func reset() {
        getUserCalled = false
        getUsersCalled = false
        getAllUsersCalled = false
        updateUserCalled = false
        observeUserPresenceCalled = false
        updateOnlineStatusCalled = false
        updateCurrentConversationCalled = false
        updateFCMTokenCalled = false
        shouldFail = false
        mockUser = nil
        mockUsers = []
        capturedUserId = nil
        capturedUserIds = nil
        capturedUser = nil
        capturedIsOnline = nil
        capturedConversationId = nil
        capturedFCMToken = nil
    }
}

