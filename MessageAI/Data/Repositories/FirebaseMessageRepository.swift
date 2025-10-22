import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

/*
 Firestore Collection: messages/
 
 Structure:
 - Document ID: message.id (UUID)
 - Fields: All Message entity properties
 - Indexes: conversationId + timestamp (composite)
 
 Queries:
 - Get messages by conversation: .whereField("conversationId", isEqualTo: id)
 - Sort by timestamp: .order(by: "timestamp", descending: false)
 - Pagination: .limit(to: 50)
 */

/// Firebase implementation of MessageRepositoryProtocol
///
/// Manages message CRUD operations and real-time synchronization with Firestore.
/// Implements offline-first architecture where writes are queued when offline.
final class FirebaseMessageRepository: MessageRepositoryProtocol {
    
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
    
    // MARK: - MessageRepositoryProtocol
    
    func sendMessage(_ message: Message) async throws {
        do {
            let data = try Firestore.Encoder.default.encode(message)
            try await db.collection("messages").document(message.id).setData(data)
            print("✅ Message sent: \(message.id)")
        } catch let error as EncodingError {
            print("❌ Send message failed (encoding): \(error.localizedDescription)")
            throw RepositoryError.encodingError(error)
        } catch {
            print("❌ Send message failed: \(error.localizedDescription)")
            throw RepositoryError.networkError(error)
        }
    }
    
    func observeMessages(conversationId: String) -> AnyPublisher<[Message], Never> {
        let subject = PassthroughSubject<[Message], Never>()
        
        let listener = db.collection("messages")
            .whereField("conversationId", isEqualTo: conversationId)
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("❌ Observe messages error: \(error.localizedDescription)")
                    subject.send([])
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    subject.send([])
                    return
                }
                
                let messages = documents.compactMap { doc -> Message? in
                    try? Firestore.Decoder.default.decode(Message.self, from: doc.data())
                }
                
                print("✅ Messages updated: \(messages.count) messages in conversation \(conversationId)")
                subject.send(messages)
            }
        
        // Store listener for cleanup
        activeListeners.append(listener)
        
        return subject.eraseToAnyPublisher()
    }
    
    func getMessages(conversationId: String, limit: Int) async throws -> [Message] {
        do {
            let snapshot = try await db.collection("messages")
                .whereField("conversationId", isEqualTo: conversationId)
                .order(by: "timestamp", descending: false)
                .limit(to: limit)
                .getDocuments()
            
            let messages = snapshot.documents.compactMap { doc -> Message? in
                try? Firestore.Decoder.default.decode(Message.self, from: doc.data())
            }
            
            print("✅ Fetched \(messages.count) messages for conversation \(conversationId)")
            return messages
        } catch let error as DecodingError {
            print("❌ Get messages failed (decoding): \(error.localizedDescription)")
            throw RepositoryError.decodingError(error)
        } catch {
            print("❌ Get messages failed: \(error.localizedDescription)")
            throw RepositoryError.networkError(error)
        }
    }
    
    func updateMessageStatus(messageId: String, status: MessageStatus) async throws {
        do {
            try await db.collection("messages").document(messageId).updateData([
                "status": status.rawValue
            ])
            print("✅ Message status updated: \(messageId) -> \(status.rawValue)")
        } catch {
            print("❌ Update message status failed: \(error.localizedDescription)")
            throw RepositoryError.networkError(error)
        }
    }
    
    func editMessage(id: String, newText: String) async throws {
        do {
            // Fetch current message to get previous text for history
            let document = try await db.collection("messages").document(id).getDocument()
            guard let data = document.data(),
                  let currentText = data["text"] as? String else {
                throw RepositoryError.messageNotFound(id)
            }
            
            // Create edit history entry with previous text
            let editEntry = MessageEdit(
                text: currentText,
                editedAt: Date()
            )
            let editData = try Firestore.Encoder.default.encode(editEntry)
            
            try await db.collection("messages").document(id).updateData([
                "text": newText,
                "isEdited": true,
                "editHistory": FieldValue.arrayUnion([editData])
            ])
            print("✅ Message edited: \(id)")
        } catch let error as RepositoryError {
            throw error
        } catch let error as EncodingError {
            print("❌ Edit message failed (encoding): \(error.localizedDescription)")
            throw RepositoryError.encodingError(error)
        } catch {
            print("❌ Edit message failed: \(error.localizedDescription)")
            throw RepositoryError.networkError(error)
        }
    }
    
    func deleteMessage(id: String) async throws {
        do {
            // Get current user ID for deletedBy field
            guard let currentUserId = Auth.auth().currentUser?.uid else {
                throw RepositoryError.unauthorized
            }
            
            try await db.collection("messages").document(id).updateData([
                "isDeleted": true,
                "text": "", // Remove text for privacy compliance
                "deletedAt": FieldValue.serverTimestamp(),
                "deletedBy": currentUserId
            ])
            print("✅ Message deleted: \(id)")
        } catch let error as RepositoryError {
            throw error
        } catch {
            print("❌ Delete message failed: \(error.localizedDescription)")
            throw RepositoryError.networkError(error)
        }
    }
    
    func markMessagesAsRead(messageIds: [String], userId: String) async throws {
        guard !messageIds.isEmpty else {
            print("📖 [REPOSITORY] No messages to mark as read")
            return
        }
        
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("📖 [REPOSITORY] markMessagesAsRead()")
        print("   User ID: \(userId.prefix(10))...")
        print("   Message Count: \(messageIds.count)")
        
        // Use batch write for atomic operation (AC #4)
        let batch = db.batch()
        
        for messageId in messageIds {
            print("   📝 Batching update for message: \(messageId.prefix(12))...")
            let messageRef = db.collection("messages").document(messageId)
            
            let updates: [String: Any] = [
                "readBy": FieldValue.arrayUnion([userId]),
                "readCount": FieldValue.increment(Int64(1)),
                "status": MessageStatus.read.rawValue,
                "statusUpdatedAt": FieldValue.serverTimestamp()
            ]
            
            print("      Updates: readBy+=[\(userId.prefix(8))...], readCount+1, status=read")
            
            batch.updateData(updates, forDocument: messageRef)
        }
        
        do {
            print("   🔄 Committing batch to Firestore...")
            try await batch.commit()
            print("✅ [REPOSITORY] Successfully marked \(messageIds.count) messages as read in Firestore")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        } catch {
            print("❌ [REPOSITORY] Failed to mark messages as read: \(error)")
            print("   Error details: \(error.localizedDescription)")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            throw RepositoryError.networkError(error)
        }
    }
}

