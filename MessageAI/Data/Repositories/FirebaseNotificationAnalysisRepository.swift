import Foundation
import FirebaseFunctions

/// Firebase implementation of NotificationAnalysisRepositoryProtocol (Epic 6 - Story 6.1)
///
/// Calls `analyzeForNotification` Cloud Function to determine notification decisions
final class FirebaseNotificationAnalysisRepository: NotificationAnalysisRepositoryProtocol {

    // MARK: - Properties

    private let functions: Functions

    // MARK: - Initialization

    init(firebaseService: FirebaseService) {
        self.functions = Functions.functions()
    }

    // MARK: - NotificationAnalysisRepositoryProtocol

    func analyzeConversationForNotification(
        conversationId: String,
        userId: String
    ) async throws -> NotificationDecision {
        do {
            // Call Cloud Function
            let callable = functions.httpsCallable("analyzeForNotification")
            let data: [String: Any] = [
                "conversationId": conversationId,
                "userId": userId
            ]

            print("📞 Calling analyzeForNotification Cloud Function")
            print("   conversationId: \(conversationId)")
            print("   userId: \(userId)")

            let result = try await callable.call(data)

            guard let resultData = result.data as? [String: Any] else {
                print("❌ Invalid response format from Cloud Function")
                throw RepositoryError.decodingError(
                    NSError(domain: "FirebaseNotificationAnalysisRepository", code: -1)
                )
            }

            // Parse response
            guard let shouldNotify = resultData["shouldNotify"] as? Bool,
                  let reason = resultData["reason"] as? String,
                  let priorityString = resultData["priority"] as? String,
                  let priority = NotificationPriority(rawValue: priorityString) else {
                print("❌ Missing required fields in Cloud Function response")
                throw RepositoryError.decodingError(
                    NSError(domain: "FirebaseNotificationAnalysisRepository", code: -2)
                )
            }

            let notificationText = resultData["notificationText"] as? String
            let timestamp = Date()

            let decision = NotificationDecision(
                shouldNotify: shouldNotify,
                reason: reason,
                notificationText: notificationText,
                priority: priority,
                timestamp: timestamp,
                conversationId: conversationId,
                messageIds: resultData["messageIds"] as? [String]
            )

            print("✅ Notification decision received:")
            print("   shouldNotify: \(decision.shouldNotify)")
            print("   priority: \(decision.priority)")
            print("   reason: \(decision.reason)")

            // Detect if using fallback heuristics instead of AI
            if decision.reason.lowercased().contains("fallback") ||
               decision.reason.lowercased().contains("heuristic") {
                print("⚠️ WARNING: Using fallback heuristics instead of AI analysis")
                print("   This usually means:")
                print("   1. Firestore indexes are still building (check Firebase Console)")
                print("   2. OpenAI API key not configured")
                print("   3. Cloud Function error (check Firebase logs)")
            }

            return decision

        } catch {
            print("❌ Failed to analyze conversation for notification: \(error.localizedDescription)")

            // Check if Cloud Function doesn't exist yet (Story 6.3)
            if let nsError = error as NSError?,
               nsError.domain == "com.firebase.functions" {
                print("ℹ️  Cloud Function not deployed yet (will be implemented in Story 6.3)")
            }

            throw RepositoryError.networkError(error)
        }
    }
}
