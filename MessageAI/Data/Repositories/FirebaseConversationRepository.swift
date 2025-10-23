import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

/*
 Firestore Collection: conversations/
 
 Structure:
 - Document ID: conversation.id (UUID)
 - Fields: All Conversation entity properties
 - Indexes: participantIds (array-contains) for queries
 
 Queries:
 - Get conversations by user: .whereField("participantIds", arrayContains: userId)
 - Sort by last message: .order(by: "lastMessageTimestamp", descending: true)
 */

/// Firebase implementation of ConversationRepositoryProtocol
///
/// Manages conversation metadata, participant lists, and unread counts in Firestore.
final class FirebaseConversationRepository: ConversationRepositoryProtocol {
    
    // MARK: - Properties
    
    private let db: Firestore
    private var activeListeners: [ListenerRegistration] = []
    
    // MARK: - Initialization
    
    init(firebaseService: FirebaseService) {
        self.db = firebaseService.firestore
    }
    
    deinit {
        // Clean up listeners to prevent memory leaks
        activeListeners.forEach { $0.remove() }
    }
    
    // MARK: - ConversationRepositoryProtocol
    
    func getConversation(id: String) async throws -> Conversation {
        do {
            let document = try await db.collection("conversations").document(id).getDocument()
            
            guard document.exists else {
                print("❌ Conversation not found: \(id)")
                throw RepositoryError.conversationNotFound(id)
            }
            
            guard let data = document.data() else {
                print("❌ Conversation document has no data: \(id)")
                throw RepositoryError.decodingError(NSError(domain: "FirebaseConversationRepository", code: -1))
            }
            
            let conversation = try Firestore.Decoder.default.decode(Conversation.self, from: data)
            print("✅ Conversation fetched: \(id)")
            return conversation
        } catch let error as RepositoryError {
            throw error
        } catch let error as DecodingError {
            print("❌ Get conversation failed (decoding): \(error.localizedDescription)")
            throw RepositoryError.decodingError(error)
        } catch {
            print("❌ Get conversation failed: \(error.localizedDescription)")
            throw RepositoryError.networkError(error)
        }
    }
    
    func createConversation(participantIds: [String]) async throws -> Conversation {
        let conversation = Conversation(
            id: UUID().uuidString,
            participantIds: participantIds,
            createdAt: Date(),
            isGroup: participantIds.count > 2
        )
        
        do {
            let data = try Firestore.Encoder.default.encode(conversation)
            
            // DEBUG: Log what we're trying to create
            print("📝 Creating conversation:")
            print("   ID: \(conversation.id)")
            print("   Participants: \(participantIds)")
            print("   Current Auth UID: \(Auth.auth().currentUser?.uid ?? "NOT AUTHENTICATED")")
            print("   Data keys: \(data.keys.sorted())")
            
            try await db.collection("conversations").document(conversation.id).setData(data)
            print("✅ Conversation created: \(conversation.id) with \(participantIds.count) participants")
            return conversation
        } catch let error as EncodingError {
            print("❌ Create conversation failed (encoding): \(error.localizedDescription)")
            throw RepositoryError.encodingError(error)
        } catch {
            print("❌ Create conversation failed: \(error.localizedDescription)")
            print("   Error details: \(error)")
            throw RepositoryError.networkError(error)
        }
    }
    
    func getOrCreateConversation(participantIds: [String]) async throws -> Conversation {
        print("🔍 Looking for existing conversation with participants: \(participantIds)")
        
        do {
            // 1. Sort participant IDs for consistent comparison
            let sortedIds = participantIds.sorted()
            
            guard !sortedIds.isEmpty else {
                print("❌ Cannot create conversation with no participants")
                throw RepositoryError.invalidInput
            }
            
            // 2. Get current user ID to query only conversations they're in
            guard let currentUserId = Auth.auth().currentUser?.uid else {
                print("❌ User not authenticated")
                throw RepositoryError.unauthorized
            }
            
            // 3. Query Firestore for conversations containing CURRENT USER
            // (Security rules only allow reading conversations the user is part of)
            print("🔍 Querying conversations where current user \(currentUserId) is participant")
            let snapshot = try await db.collection("conversations")
                .whereField("participantIds", arrayContains: currentUserId)
                .getDocuments()
            
            // 3. Check each conversation for exact match
            for document in snapshot.documents {
                guard let conversation = try? Firestore.Decoder.default.decode(
                    Conversation.self,
                    from: document.data()
                ) else {
                    continue
                }
                
                let existingIds = conversation.participantIds.sorted()
                
                // Exact match found (same participants, same count)
                if existingIds == sortedIds {
                    print("✅ Found existing conversation: \(conversation.id)")
                    return conversation
                }
            }
            
            // 4. No match found - create new conversation
            print("🆕 Creating new conversation with sorted IDs: \(sortedIds)")
            return try await createConversation(participantIds: sortedIds)
            
        } catch let error as RepositoryError {
            throw error
        } catch {
            print("❌ Get or create conversation failed: \(error.localizedDescription)")
            throw RepositoryError.networkError(error)
        }
    }
    
    func observeConversations(userId: String) -> AnyPublisher<[Conversation], Never> {
        let subject = PassthroughSubject<[Conversation], Never>()

        // CRITICAL FIX: Maintain local state to prevent duplicates on reconnection
        // When network toggles, Firestore re-emits all documents. We need to track
        // what we already have and only process actual changes.
        var conversationsCache: [String: Conversation] = [:]

        let listener = db.collection("conversations")
            .whereField("participantIds", arrayContains: userId)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("❌ Observe conversations error: \(error.localizedDescription)")
                    subject.send([])
                    return
                }

                guard let snapshot = snapshot else {
                    subject.send([])
                    return
                }

                // CRITICAL FIX: Use documentChanges to avoid duplicates on reconnection
                // This processes only actual changes (added/modified/removed), not all documents
                let changes = snapshot.documentChanges

                if !changes.isEmpty {
                    print("🔄 Processing \(changes.count) conversation change(s)")

                    for change in changes {
                        let docId = change.document.documentID

                        switch change.type {
                        case .added:
                            if let conversation = try? Firestore.Decoder.default.decode(Conversation.self, from: change.document.data()) {
                                conversationsCache[docId] = conversation
                                print("➕ Added conversation: \(docId)")
                            }

                        case .modified:
                            if let conversation = try? Firestore.Decoder.default.decode(Conversation.self, from: change.document.data()) {
                                conversationsCache[docId] = conversation
                                print("✏️ Modified conversation: \(docId)")
                            }

                        case .removed:
                            conversationsCache.removeValue(forKey: docId)
                            print("🗑️ Removed conversation: \(docId)")
                        }
                    }
                }

                // Sort by last message timestamp (most recent first)
                let conversations = Array(conversationsCache.values)
                let sorted = conversations.sorted { conv1, conv2 in
                    guard let time1 = conv1.lastMessageTimestamp else { return false }
                    guard let time2 = conv2.lastMessageTimestamp else { return true }
                    return time1 > time2
                }

                print("✅ Conversations updated: \(sorted.count) conversations for user \(userId)")
                subject.send(sorted)
            }

        // Store listener for cleanup
        activeListeners.append(listener)

        return subject.eraseToAnyPublisher()
    }
    
    func updateUnreadCount(conversationId: String, userId: String, count: Int) async throws {
        do {
            try await db.collection("conversations").document(conversationId).updateData([
                "unreadCounts.\(userId)": count
            ])
            print("✅ Unread count updated: conversation \(conversationId), user \(userId) -> \(count)")
        } catch {
            print("❌ Update unread count failed: \(error.localizedDescription)")
            throw RepositoryError.networkError(error)
        }
    }
    
    func markAsRead(conversationId: String, userId: String) async throws {
        try await updateUnreadCount(conversationId: conversationId, userId: userId, count: 0)
    }
    
    func updateConversation(id: String, updates: [String: Any]) async throws {
        do {
            print("🔄 [FirebaseConversationRepository] Updating conversation: \(id)")
            print("  📝 Updates: \(updates)")

            try await db.collection("conversations").document(id).updateData(updates)

            print("✅ [FirebaseConversationRepository] Firestore updateData() completed")
            print("  💡 Snapshot listener should trigger for all participants...")
        } catch {
            print("❌ [FirebaseConversationRepository] Update conversation failed: \(error.localizedDescription)")
            throw RepositoryError.networkError(error)
        }
    }

    func updateTypingState(conversationId: String, userId: String, isTyping: Bool) async throws {
        do {
            let conversationRef = db.collection("conversations").document(conversationId)

            if isTyping {
                // Add user to typingUsers array (no duplicates thanks to arrayUnion)
                try await conversationRef.updateData([
                    "typingUsers": FieldValue.arrayUnion([userId])
                ])
                print("✅ Added \(userId) to typingUsers in conversation \(conversationId)")
            } else {
                // Remove user from typingUsers array
                try await conversationRef.updateData([
                    "typingUsers": FieldValue.arrayRemove([userId])
                ])
                print("✅ Removed \(userId) from typingUsers in conversation \(conversationId)")
            }
        } catch {
            print("❌ Failed to update typing state: \(error.localizedDescription)")
            throw RepositoryError.networkError(error)
        }
    }

    // MARK: - Pagination (Story 2.11 - AC #3)

    func loadMoreConversations(userId: String, lastConversation: Conversation?, limit: Int) async throws -> [Conversation] {
        do {
            var query = db.collection("conversations")
                .whereField("participantIds", arrayContains: userId)
                .order(by: "lastMessageTimestamp", descending: true)
                .limit(to: limit)

            // Cursor-based pagination: start after the last conversation
            if let lastConv = lastConversation,
               let lastTimestamp = lastConv.lastMessageTimestamp {
                query = query.start(after: [lastTimestamp])
            }

            let snapshot = try await query.getDocuments()

            let conversations = snapshot.documents.compactMap { doc -> Conversation? in
                guard let conversation = try? doc.data(as: Conversation.self) else {
                    print("⚠️ Failed to decode conversation: \(doc.documentID)")
                    return nil
                }
                return conversation
            }

            print("📄 [Pagination] Loaded \(conversations.count) older conversations (requested limit: \(limit))")
            return conversations

        } catch {
            print("❌ Failed to load more conversations: \(error.localizedDescription)")
            throw RepositoryError.networkError(error)
        }
    }

    // MARK: - Offline-First Loading

    func getConversationsFromCache(userId: String) async throws -> [Conversation] {
        do {
            // Query cache ONLY (no network request)
            let query = db.collection("conversations")
                .whereField("participantIds", arrayContains: userId)
                .order(by: "lastMessageTimestamp", descending: true)

            // Use cache source explicitly - this returns immediately with cached data
            let snapshot = try await query.getDocuments(source: .cache)

            let conversations = snapshot.documents.compactMap { doc -> Conversation? in
                guard let conversation = try? Firestore.Decoder.default.decode(
                    Conversation.self,
                    from: doc.data()
                ) else {
                    print("⚠️ Failed to decode cached conversation: \(doc.documentID)")
                    return nil
                }
                return conversation
            }

            print("💾 [Cache] Loaded \(conversations.count) conversations from cache for user \(userId)")
            return conversations

        } catch let error as NSError where error.domain == FirestoreErrorDomain {
            // Cache miss or unavailable - return empty array (not an error)
            if error.code == FirestoreErrorCode.unavailable.rawValue {
                print("💾 [Cache] No cached conversations available")
                return []
            }
            throw RepositoryError.networkError(error)
        } catch {
            print("❌ Failed to load conversations from cache: \(error.localizedDescription)")
            throw RepositoryError.networkError(error)
        }
    }
}

