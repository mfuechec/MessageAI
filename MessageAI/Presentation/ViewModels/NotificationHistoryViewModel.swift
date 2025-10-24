import Foundation
import Combine

/// ViewModel for managing notification decision history (Epic 6 - Story 6.5)
@MainActor
final class NotificationHistoryViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var history: [NotificationHistoryEntry] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Private Properties

    private let repository: NotificationHistoryRepositoryProtocol
    private let userId: String

    // MARK: - Initialization

    init(repository: NotificationHistoryRepositoryProtocol, userId: String) {
        self.repository = repository
        self.userId = userId
    }

    // MARK: - Public Methods

    /// Load notification history for the current user
    func loadHistory() async {
        isLoading = true
        errorMessage = nil

        do {
            history = try await repository.getRecentDecisions(userId: userId, limit: 20)
            print("✅ [NotificationHistoryVM] Loaded \(history.count) history entries")
        } catch {
            errorMessage = "Failed to load notification history: \(error.localizedDescription)"
            print("❌ [NotificationHistoryVM] Failed to load history: \(error)")
        }

        isLoading = false
    }

    /// Submit feedback for a notification
    ///
    /// - Parameters:
    ///   - entry: The history entry to provide feedback for
    ///   - feedback: "helpful" or "not_helpful"
    func submitFeedback(for entry: NotificationHistoryEntry, feedback: String) async {
        do {
            try await repository.submitFeedback(
                userId: userId,
                conversationId: entry.conversationId,
                messageId: entry.messageId,
                feedback: feedback
            )

            // Update local entry
            if let index = history.firstIndex(where: { $0.id == entry.id }) {
                var updatedEntry = entry
                updatedEntry.userFeedback = feedback
                history[index] = updatedEntry
            }

            print("✅ [NotificationHistoryVM] Feedback submitted: \(feedback)")

        } catch {
            errorMessage = "Failed to submit feedback: \(error.localizedDescription)"
            print("❌ [NotificationHistoryVM] Failed to submit feedback: \(error)")
        }
    }
}
