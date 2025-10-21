import Foundation
import FirebaseFirestore
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
            try await db.collection("conversations").document(conversation.id).setData(data)
            print("✅ Conversation created: \(conversation.id) with \(participantIds.count) participants")
            return conversation
        } catch let error as EncodingError {
            print("❌ Create conversation failed (encoding): \(error.localizedDescription)")
            throw RepositoryError.encodingError(error)
        } catch {
            print("❌ Create conversation failed: \(error.localizedDescription)")
            throw RepositoryError.networkError(error)
        }
    }
    
    func observeConversations(userId: String) -> AnyPublisher<[Conversation], Never> {
        let subject = PassthroughSubject<[Conversation], Never>()
        
        let listener = db.collection("conversations")
            .whereField("participantIds", arrayContains: userId)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("❌ Observe conversations error: \(error.localizedDescription)")
                    subject.send([])
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    subject.send([])
                    return
                }
                
                let conversations = documents.compactMap { doc -> Conversation? in
                    try? Firestore.Decoder.default.decode(Conversation.self, from: doc.data())
                }
                
                // Sort by last message timestamp (most recent first)
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
            try await db.collection("conversations").document(id).updateData(updates)
            print("✅ Conversation updated: \(id) with \(updates.keys.count) fields")
        } catch {
            print("❌ Update conversation failed: \(error.localizedDescription)")
            throw RepositoryError.networkError(error)
        }
    }
}

