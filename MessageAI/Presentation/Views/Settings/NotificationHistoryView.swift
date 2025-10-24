import SwiftUI

/// View displaying notification decision history with feedback options (Epic 6 - Story 6.5)
struct NotificationHistoryView: View {
    @StateObject var viewModel: NotificationHistoryViewModel
    @SwiftUI.Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading && viewModel.history.isEmpty {
                    ProgressView("Loading notification history...")
                } else if viewModel.history.isEmpty {
                    emptyStateView
                } else {
                    historyList
                }
            }
            .navigationTitle("Notification History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .task {
                await viewModel.loadHistory()
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.slash")
                .font(.system(size: 64))
                .foregroundColor(.gray)

            Text("No Notification History")
                .font(.headline)

            Text("You haven't received any smart notifications yet.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }

    // MARK: - History List

    private var historyList: some View {
        List {
            Section {
                Text("Last 20 smart notification decisions")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ForEach(viewModel.history) { entry in
                NotificationHistoryRowView(
                    entry: entry,
                    onFeedback: { feedback in
                        Task {
                            await viewModel.submitFeedback(for: entry, feedback: feedback)
                        }
                    }
                )
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - History Row View

struct NotificationHistoryRowView: View {
    let entry: NotificationHistoryEntry
    let onFeedback: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Conversation name + timestamp
            HStack {
                Text(entry.conversationName)
                    .font(.headline)

                Spacer()

                Text(entry.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Notification text
            if !entry.notificationText.isEmpty {
                Text(entry.notificationText)
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }

            // AI reasoning (expandable)
            DisclosureGroup("AI Reasoning") {
                Text(entry.aiReasoning)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }

            // Decision badge
            HStack {
                if entry.decision.shouldNotify {
                    Label("Notified", systemImage: "bell.fill")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(priorityColor(entry.decision.priority))
                        .cornerRadius(8)
                } else {
                    Label("Suppressed", systemImage: "bell.slash")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray)
                        .cornerRadius(8)
                }

                Spacer()

                // Feedback buttons
                feedbackButtons
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Feedback Buttons

    @ViewBuilder
    private var feedbackButtons: some View {
        if let feedback = entry.userFeedback {
            // Feedback already provided
            HStack(spacing: 8) {
                if feedback == "helpful" {
                    Label("Helpful", systemImage: "hand.thumbsup.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Label("Not Helpful", systemImage: "hand.thumbsdown.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        } else {
            // Feedback buttons
            HStack(spacing: 12) {
                Button(action: {
                    onFeedback("helpful")
                }) {
                    Image(systemName: "hand.thumbsup")
                        .foregroundColor(.green)
                }
                .buttonStyle(.borderless)

                Button(action: {
                    onFeedback("not_helpful")
                }) {
                    Image(systemName: "hand.thumbsdown")
                        .foregroundColor(.red)
                }
                .buttonStyle(.borderless)
            }
        }
    }

    // MARK: - Priority Color

    private func priorityColor(_ priority: NotificationPriority) -> Color {
        switch priority {
        case .high:
            return .red
        case .medium:
            return .orange
        case .low:
            return .blue
        }
    }
}

// MARK: - Preview

struct NotificationHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        let mockRepository = MockNotificationHistoryRepository()
        let viewModel = NotificationHistoryViewModel(
            repository: mockRepository,
            userId: "user123"
        )

        NotificationHistoryView(viewModel: viewModel)
    }
}

// MARK: - Mock Repository (for preview)

class MockNotificationHistoryRepository: NotificationHistoryRepositoryProtocol {
    func getRecentDecisions(userId: String, limit: Int) async throws -> [NotificationHistoryEntry] {
        return [
            NotificationHistoryEntry(
                id: "1",
                conversationId: "conv1",
                conversationName: "Team Chat",
                messageId: "msg1",
                notificationText: "John mentioned you in Team Chat",
                aiReasoning: "User was mentioned directly in a team conversation",
                timestamp: Date().addingTimeInterval(-3600),
                decision: NotificationDecision(
                    shouldNotify: true,
                    reason: "Direct mention",
                    notificationText: "John mentioned you",
                    priority: .high,
                    timestamp: Date().addingTimeInterval(-3600),
                    conversationId: "conv1",
                    messageIds: ["msg1"]
                ),
                userFeedback: "helpful"
            ),
            NotificationHistoryEntry(
                id: "2",
                conversationId: "conv2",
                conversationName: "Sarah",
                messageId: "msg2",
                notificationText: "Sarah: Can you review the PR?",
                aiReasoning: "Question directed at user requiring response",
                timestamp: Date().addingTimeInterval(-7200),
                decision: NotificationDecision(
                    shouldNotify: true,
                    reason: "Question for user",
                    notificationText: "Sarah asked a question",
                    priority: .medium,
                    timestamp: Date().addingTimeInterval(-7200),
                    conversationId: "conv2",
                    messageIds: ["msg2"]
                ),
                userFeedback: nil
            )
        ]
    }

    func submitFeedback(userId: String, conversationId: String, messageId: String, feedback: String) async throws {
        // Mock submission
    }
}
