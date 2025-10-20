import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

/// Firebase implementation of AuthRepositoryProtocol
///
/// Manages user authentication using Firebase Auth and creates/updates user documents in Firestore.
/// Coordinates between Firebase Auth (authentication) and Firestore (user profile data).
final class FirebaseAuthRepository: AuthRepositoryProtocol {
    
    // MARK: - Properties
    
    private let auth: Auth
    private let userRepository: UserRepositoryProtocol
    private var authStateListenerHandle: AuthStateDidChangeListenerHandle?
    
    // MARK: - Initialization
    
    init(firebaseService: FirebaseService, userRepository: UserRepositoryProtocol) {
        self.auth = firebaseService.auth
        self.userRepository = userRepository
    }
    
    deinit {
        // Remove auth state listener
        if let handle = authStateListenerHandle {
            auth.removeStateDidChangeListener(handle)
        }
    }
    
    // MARK: - AuthRepositoryProtocol
    
    func signIn(email: String, password: String) async throws -> User {
        do {
            let authResult = try await auth.signIn(withEmail: email, password: password)
            let userId = authResult.user.uid
            
            // Fetch user document from Firestore
            let user = try await userRepository.getUser(id: userId)
            
            // Update online status
            try await userRepository.updateOnlineStatus(isOnline: true)
            
            print("✅ Sign in successful: \(userId)")
            return user
        } catch let error as RepositoryError {
            throw error
        } catch {
            print("❌ Sign in failed: \(error.localizedDescription)")
            throw RepositoryError.networkError(error)
        }
    }
    
    func signUp(email: String, password: String) async throws -> User {
        do {
            let authResult = try await auth.createUser(withEmail: email, password: password)
            let userId = authResult.user.uid
            
            // Create user document in Firestore
            let user = User(
                id: userId,
                email: email,
                displayName: email.components(separatedBy: "@").first ?? "User",
                isOnline: true,
                lastSeen: Date(),
                createdAt: Date()
            )
            
            try await userRepository.updateUser(user)
            
            print("✅ Sign up successful: \(userId)")
            return user
        } catch let error as RepositoryError {
            throw error
        } catch {
            print("❌ Sign up failed: \(error.localizedDescription)")
            throw RepositoryError.networkError(error)
        }
    }
    
    func signOut() async throws {
        do {
            // Update online status before signing out
            if auth.currentUser != nil {
                try? await userRepository.updateOnlineStatus(isOnline: false)
            }
            
            try auth.signOut()
            print("✅ Sign out successful")
        } catch {
            print("❌ Sign out failed: \(error.localizedDescription)")
            throw RepositoryError.networkError(error)
        }
    }
    
    func getCurrentUser() async throws -> User? {
        guard let firebaseUser = auth.currentUser else {
            return nil
        }
        
        do {
            let user = try await userRepository.getUser(id: firebaseUser.uid)
            return user
        } catch let error as RepositoryError where error.isUserNotFound {
            // User is authenticated but profile not found in Firestore
            print("⚠️ Authenticated user has no Firestore profile: \(firebaseUser.uid)")
            return nil
        } catch {
            throw error
        }
    }
    
    func observeAuthState() -> AnyPublisher<User?, Never> {
        let subject = PassthroughSubject<User?, Never>()
        
        authStateListenerHandle = auth.addStateDidChangeListener { [weak self] _, firebaseUser in
            guard let self = self else { return }
            
            Task {
                if let firebaseUser = firebaseUser {
                    do {
                        let user = try await self.userRepository.getUser(id: firebaseUser.uid)
                        print("✅ Auth state: User signed in (\(firebaseUser.uid))")
                        subject.send(user)
                    } catch {
                        print("❌ Auth state: Failed to fetch user profile (\(firebaseUser.uid))")
                        subject.send(nil)
                    }
                } else {
                    print("✅ Auth state: User signed out")
                    subject.send(nil)
                }
            }
        }
        
        return subject.eraseToAnyPublisher()
    }
}

// MARK: - Helper Extensions

private extension RepositoryError {
    var isUserNotFound: Bool {
        if case .userNotFound = self {
            return true
        }
        return false
    }
}

