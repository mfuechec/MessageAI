import Foundation
import FirebaseFirestore
import FirebaseFunctions

/// Firebase implementation of notification history repository (Epic 6 - Story 6.5)
final class FirebaseNotificationHistoryRepository: NotificationHistoryRepositoryProtocol {

    private let db = Firestore.firestore()
    private let functions = Functions.functions()

    // MARK: - Get Recent Decisions

    func getRecentDecisions(userId: String, limit: Int = 20) async throws -> [NotificationHistoryEntry] {
        print("📚 [NotificationHistory] Fetching recent decisions for user: \(userId)")

        do {
            let snapshot = try await db.collection("notification_decisions")
                .whereField("userId", isEqualTo: userId)
                .order(by: "timestamp", descending: true)
                .limit(to: limit)
                .getDocuments()

            print("✅ [NotificationHistory] Found \(snapshot.documents.count) decisions")

            var entries: [NotificationHistoryEntry] = []

            for document in snapshot.documents {
                let data = document.data()

                guard let conversationId = data["conversationId"] as? String,
                      let timestamp = data["timestamp"] as? Timestamp else {
                    print("⚠️  [NotificationHistory] Skipping invalid document: \(document.documentID)")
                    continue
                }

                // Fetch conversation name
                var conversationName = "Unknown Conversation"
                do {
                    let convDoc = try await db.collection("conversations").document(conversationId).getDocument()
                    if let convData = convDoc.data() {
                        if let groupName = convData["groupName"] as? String {
                            conversationName = groupName
                        } else if let participantIds = convData["participantIds"] as? [String] {
                            // For 1:1 chats, get other user's name
                            let otherUserId = participantIds.first { $0 != userId } ?? ""
                            if !otherUserId.isEmpty {
                                let userDoc = try await db.collection("users").document(otherUserId).getDocument()
                                conversationName = userDoc.data()?["displayName"] as? String ?? "Unknown User"
                            }
                        }
                    }
                } catch {
                    print("⚠️  [NotificationHistory] Failed to fetch conversation name: \(error)")
                }

                // Parse priority
                let priorityString = data["priority"] as? String ?? "low"
                let priority = NotificationPriority(rawValue: priorityString) ?? .low

                let entry = NotificationHistoryEntry(
                    id: document.documentID,
                    conversationId: conversationId,
                    conversationName: conversationName,
                    messageId: data["messageId"] as? String ?? "",
                    notificationText: data["notificationText"] as? String ?? "",
                    aiReasoning: data["aiReasoning"] as? String ?? "",
                    timestamp: timestamp.dateValue(),
                    decision: NotificationDecision(
                        shouldNotify: data["decision"] as? Bool ?? false,
                        reason: data["aiReasoning"] as? String ?? "",
                        notificationText: data["notificationText"] as? String,
                        priority: priority,
                        timestamp: timestamp.dateValue(),
                        conversationId: conversationId,
                        messageIds: nil
                    ),
                    userFeedback: data["userFeedback"] as? String
                )

                entries.append(entry)
            }

            return entries

        } catch {
            print("❌ [NotificationHistory] Failed to fetch decisions: \(error)")
            throw RepositoryError.unknown(error)
        }
    }

    // MARK: - Submit Feedback

    func submitFeedback(
        userId: String,
        conversationId: String,
        messageId: String,
        feedback: String
    ) async throws {
        print("👍 [NotificationHistory] Submitting feedback: \(feedback) for message: \(messageId)")

        do {
            let data: [String: Any] = [
                "conversationId": conversationId,
                "messageId": messageId,
                "feedback": feedback
            ]

            _ = try await functions.httpsCallable("submitNotificationFeedback").call(data)
            print("✅ [NotificationHistory] Feedback submitted successfully")

        } catch {
            print("❌ [NotificationHistory] Failed to submit feedback: \(error)")
            throw RepositoryError.unknown(error)
        }
    }
}
