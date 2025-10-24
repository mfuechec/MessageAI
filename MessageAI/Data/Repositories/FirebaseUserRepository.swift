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
    
    func getUsers(ids: [String]) async throws -> [User] {
        var users: [User] = []
        
        // Fetch each user individually
        // Note: For production, consider batch fetching with Firestore "in" queries (max 10 at a time)
        for id in ids {
            do {
                let user = try await getUser(id: id)
                users.append(user)
            } catch {
                print("⚠️ Failed to load user \(id): \(error.localizedDescription) - Skipping")
                // Continue loading other users (graceful degradation)
            }
        }
        
        print("✅ Fetched \(users.count)/\(ids.count) users")
        return users
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
            print("🔵 [FirebaseUserRepo] updateUser called for user ID: \(user.id)")
            print("🔵 [FirebaseUserRepo] User email: \(user.email)")
            print("🔵 [FirebaseUserRepo] User displayName: \(user.displayName)")
            print("🔵 [FirebaseUserRepo] User profileImageURL: \(String(describing: user.profileImageURL))")
            
            let data = try Firestore.Encoder.default.encode(user)
            print("🔵 [FirebaseUserRepo] Encoded data keys: \(data.keys.sorted())")
            if let profileURL = data["profileImageURL"] {
                print("🔵 [FirebaseUserRepo] Encoded profileImageURL value: \(profileURL)")
            } else {
                print("⚠️ [FirebaseUserRepo] profileImageURL NOT in encoded data!")
            }
            
            print("🔵 [FirebaseUserRepo] Calling Firestore setData for document: users/\(user.id)")
            try await db.collection("users").document(user.id).setData(data)
            print("✅ [FirebaseUserRepo] User updated: \(user.id)")
            print("✅ [FirebaseUserRepo] Firestore write completed successfully")
        } catch let error as EncodingError {
            print("❌ [FirebaseUserRepo] Update user failed (encoding): \(error.localizedDescription)")
            throw RepositoryError.encodingError(error)
        } catch {
            print("❌ [FirebaseUserRepo] Update user failed: \(error.localizedDescription)")
            print("❌ [FirebaseUserRepo] Error type: \(type(of: error))")
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

    /// Update current conversation ID for notification suppression (Story 2.10 QA Fix)
    func updateCurrentConversation(conversationId: String?) async throws {
        guard let currentUserId = auth.currentUser?.uid else {
            print("❌ Update current conversation failed: No authenticated user")
            throw RepositoryError.unauthorized
        }

        do {
            if let conversationId = conversationId {
                // Set conversation ID in users collection (Story 2.10)
                try await db.collection("users").document(currentUserId).updateData([
                    "currentConversationId": conversationId
                ])

                // Set activity in user_activity collection (Story 6.6)
                try await db.collection("user_activity").document(currentUserId).setData([
                    "userId": currentUserId,
                    "activeConversationId": conversationId,
                    "timestamp": FieldValue.serverTimestamp()
                ])

                print("✅ Current conversation updated: \(currentUserId) -> \(conversationId)")
            } else {
                // Clear conversation ID in users collection (Story 2.10)
                try await db.collection("users").document(currentUserId).updateData([
                    "currentConversationId": FieldValue.delete()
                ])

                // Delete activity document (Story 6.6)
                try await db.collection("user_activity").document(currentUserId).delete()

                print("✅ Current conversation cleared: \(currentUserId)")
            }
        } catch {
            print("❌ Update current conversation failed: \(error.localizedDescription)")
            throw RepositoryError.networkError(error)
        }
    }

    /// Update FCM token for push notifications (Story 2.10 QA Fix)
    func updateFCMToken(_ token: String, userId: String?) async throws {
        let targetUserId = userId ?? auth.currentUser?.uid

        guard let targetUserId = targetUserId else {
            print("❌ Update FCM token failed: No user ID provided")
            throw RepositoryError.unauthorized
        }

        do {
            try await db.collection("users").document(targetUserId).updateData([
                "fcmToken": token,
                "fcmTokenUpdatedAt": FieldValue.serverTimestamp()
            ])
            print("✅ FCM token updated for user: \(targetUserId)")
        } catch {
            print("❌ Update FCM token failed: \(error.localizedDescription)")
            throw RepositoryError.networkError(error)
        }
    }
}

