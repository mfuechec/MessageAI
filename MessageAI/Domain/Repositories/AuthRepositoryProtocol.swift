import Foundation
import Combine

/// Protocol defining authentication operations (implemented in Data layer)
protocol AuthRepositoryProtocol {
    /// Sign in with email and password
    /// - Parameters:
    ///   - email: User email
    ///   - password: User password
    /// - Returns: Authenticated user entity
    func signIn(email: String, password: String) async throws -> User
    
    /// Sign up new user with email and password
    /// - Parameters:
    ///   - email: User email
    ///   - password: User password
    /// - Returns: Newly created user entity
    func signUp(email: String, password: String) async throws -> User
    
    /// Sign out current user
    func signOut() async throws
    
    /// Get currently authenticated user
    /// - Returns: Current user or nil if not authenticated
    func getCurrentUser() async throws -> User?
    
    /// Observe authentication state changes
    /// - Returns: Publisher emitting user changes (nil when signed out)
    func observeAuthState() -> AnyPublisher<User?, Never>
}

