import Foundation
import Combine

/// Protocol defining user data operations (implemented in Data layer)
protocol UserRepositoryProtocol {
    /// Get a single user by ID
    /// - Parameter id: The user ID
    /// - Returns: The user entity
    func getUser(id: String) async throws -> User
    
    /// Get multiple users by their IDs
    /// - Parameter ids: Array of user IDs to fetch
    /// - Returns: Array of User entities (skips missing users)
    func getUsers(ids: [String]) async throws -> [User]
    
    /// Get all users in the system (for user selection view)
    /// [Source: docs/architecture/data-models.md#user-queries]
    /// - Returns: Array of all User entities
    func getAllUsers() async throws -> [User]
    
    /// Update user profile data
    /// - Parameter user: The user entity with updated data
    func updateUser(_ user: User) async throws
    
    /// Observe user presence status in real-time
    /// - Parameter userId: The user ID to observe
    /// - Returns: Publisher emitting online status changes
    func observeUserPresence(userId: String) -> AnyPublisher<Bool, Never>
    
    /// Update current user's online status
    /// - Parameter isOnline: True if online, false if offline
    func updateOnlineStatus(isOnline: Bool) async throws
}

