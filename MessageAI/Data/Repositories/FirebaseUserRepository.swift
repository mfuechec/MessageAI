import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

/*
 Firestore Collection: users/
 
 Structure:
 - Document ID: user.id (Firebase Auth UID)
 - Fields: All User entity properties
 - Indexes: None required for MVP
 
 Queries:
 - Get user by ID: document(userId).getDocument()
 - Observe presence: Real-time listener on user document
 */

/// Firebase implementation of UserRepositoryProtocol
///
/// Manages user profile data and presence status in Firestore.
final class FirebaseUserRepository: UserRepositoryProtocol {
    
    // MARK: - Properties
    
    private let db: Firestore
    private let auth: Auth
    private var activeListeners: [ListenerRegistration] = []
    
    // MARK: - Initialization
    
    init(firebaseService: FirebaseService) {
        self.db = firebaseService.firestore
        self.auth = firebaseService.auth
    }
    
    deinit {
        // Clean up listeners to prevent memory leaks
        activeListeners.forEach { $0.remove() }
    }
    
    // MARK: - UserRepositoryProtocol
    
    func getUser(id: String) async throws -> User {
        do {
            let document = try await db.collection("users").document(id).getDocument()
            
            guard document.exists else {
                print("❌ User not found: \(id)")
                throw RepositoryError.userNotFound(id)
            }
            
            guard let data = document.data() else {
                print("❌ User document has no data: \(id)")
                throw RepositoryError.decodingError(NSError(domain: "FirebaseUserRepository", code: -1))
            }
            
            let user = try Firestore.Decoder.default.decode(User.self, from: data)
            print("✅ User fetched: \(id)")
            return user
        } catch let error as RepositoryError {
            throw error
        } catch let error as DecodingError {
            print("❌ Get user failed (decoding): \(error.localizedDescription)")
            throw RepositoryError.decodingError(error)
        } catch {
            print("❌ Get user failed: \(error.localizedDescription)")
            throw RepositoryError.networkError(error)
        }
    }
    
    func getAllUsers() async throws -> [User] {
        do {
            let snapshot = try await db.collection("users").getDocuments()
            
            let users = snapshot.documents.compactMap { doc -> User? in
                try? Firestore.Decoder.default.decode(User.self, from: doc.data())
            }
            
            // Sort alphabetically by display name
            let sortedUsers = users.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
            
            print("✅ Fetched \(sortedUsers.count) users")
            return sortedUsers
            
        } catch let error as DecodingError {
            print("❌ Get all users failed (decoding): \(error.localizedDescription)")
            throw RepositoryError.decodingError(error)
        } catch {
            print("❌ Get all users failed: \(error.localizedDescription)")
            throw RepositoryError.networkError(error)
        }
    }
    
    func updateUser(_ user: User) async throws {
        do {
            let data = try Firestore.Encoder.default.encode(user)
            try await db.collection("users").document(user.id).setData(data)
            print("✅ User updated: \(user.id)")
        } catch let error as EncodingError {
            print("❌ Update user failed (encoding): \(error.localizedDescription)")
            throw RepositoryError.encodingError(error)
        } catch {
            print("❌ Update user failed: \(error.localizedDescription)")
            throw RepositoryError.networkError(error)
        }
    }
    
    func observeUserPresence(userId: String) -> AnyPublisher<Bool, Never> {
        let subject = PassthroughSubject<Bool, Never>()
        
        let listener = db.collection("users").document(userId)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("❌ Observe user presence error: \(error.localizedDescription)")
                    subject.send(false)
                    return
                }
                
                guard let data = snapshot?.data(),
                      let isOnline = data["isOnline"] as? Bool else {
                    subject.send(false)
                    return
                }
                
                print("✅ User presence updated: \(userId) is \(isOnline ? "online" : "offline")")
                subject.send(isOnline)
            }
        
        // Store listener for cleanup
        activeListeners.append(listener)
        
        return subject.eraseToAnyPublisher()
    }
    
    func updateOnlineStatus(isOnline: Bool) async throws {
        guard let currentUserId = auth.currentUser?.uid else {
            print("❌ Update online status failed: No authenticated user")
            throw RepositoryError.unauthorized
        }
        
        do {
            try await db.collection("users").document(currentUserId).updateData([
                "isOnline": isOnline,
                "lastSeen": FieldValue.serverTimestamp()
            ])
            print("✅ Online status updated: \(currentUserId) -> \(isOnline)")
        } catch {
            print("❌ Update online status failed: \(error.localizedDescription)")
            throw RepositoryError.networkError(error)
        }
    }
}

