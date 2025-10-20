import Foundation
import Combine

/// Protocol defining user data operations (implemented in Data layer)
protocol UserRepositoryProtocol {
    /// Get a single user by ID
    /// - Parameter id: The user ID
    /// - Returns: The user entity
    func getUser(id: String) async throws -> User
    
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

