//
//  SummaryView.swift
//  MessageAI
//
//  Created by Claude Code on 10/23/25.
//  Story 3.2: Thread Summarization Feature
//

import SwiftUI

/// Modal view for displaying AI-generated thread summaries
///
/// Presents conversation summaries with:
/// - Key points in bullet format
/// - Main decisions and topics
/// - Participant information
/// - Date range covered
/// - Regenerate and close actions
struct SummaryView: View {
    @ObservedObject var viewModel: SummaryViewModel
    @SwiftUI.Environment(\.presentationMode) private var presentationMode

    var body: some View {
        NavigationView {
            ZStack {
                if viewModel.isLoading {
                    loadingView
                } else if let errorMessage = viewModel.errorMessage {
                    errorView(message: errorMessage)
                } else if let summary = viewModel.summary {
                    summaryContentView(summary: summary)
                } else {
                    emptyView
                }
            }
            .navigationTitle("AI Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }

                if viewModel.summary != nil && !viewModel.isLoading {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Regenerate") {
                            Task {
                                await viewModel.regenerateSummary()
                            }
                        }
                        .disabled(viewModel.isLoading)
                    }
                }
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Analyzing conversation...")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("This may take up to 10 seconds")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)

            Text("Failed to Generate Summary")
                .font(.headline)

            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Try Again") {
                Task {
                    await viewModel.loadSummary()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.gray)

            Text("No Summary Available")
                .font(.headline)

            Button("Generate Summary") {
                Task {
                    await viewModel.loadSummary()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Summary Content View

    private func summaryContentView(summary: ThreadSummary) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Metadata header
                metadataSection(summary: summary)

                // 1. THREAD SUMMARY (First - condensed to 1-2 sentences)
                summarySection(summary: summary)

                // 2. PRIORITY MESSAGES
                priorityMessagesSection()

                // 3. ACTION ITEMS
                actionItemsSection()

                // 4. DECISION TRACKING
                decisionsSection()

                // Participants & Date Range at bottom
                HStack(spacing: 20) {
                    if !summary.participants.isEmpty {
                        participantsSection(summary: summary)
                    }

                    if !summary.dateRange.isEmpty {
                        dateRangeSection(summary: summary)
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Summary Sections

    private func metadataSection(summary: ThreadSummary) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.generatedAtText)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if viewModel.isCached {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                        Text("Cached result")
                            .font(.caption2)
                    }
                    .foregroundColor(.green)

                    // Show staleness indicator if there are new messages
                    if summary.messagesSinceCache > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                            Text("(\(summary.messagesSinceCache) new \(summary.messagesSinceCache == 1 ? "message" : "messages") since summary)")
                                .font(.caption2)
                        }
                        .foregroundColor(.orange)
                    }
                }
            }

            Spacer()
        }
    }

    private func summarySection(summary: ThreadSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("📝 Summary", systemImage: "doc.text")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            Text(summary.summary)
                .font(.body)
                .lineSpacing(2)
                .foregroundColor(.primary)
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    private func participantsSection(summary: ThreadSummary) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "person.2.fill")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(summary.participants.joined(separator: ", "))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func dateRangeSection(summary: ThreadSummary) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "calendar")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(summary.dateRange)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - AI Feature Sections

    private func priorityMessagesSection() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("⚠️ Priority Messages", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.orange)

            // TODO: Replace with actual priority messages from AI
            VStack(alignment: .leading, spacing: 8) {
                bulletPoint(
                    icon: "exclamationmark.circle.fill",
                    color: .red,
                    text: "Production server is down - needs immediate attention (Alice)"
                )
                bulletPoint(
                    icon: "exclamationmark.circle.fill",
                    color: .orange,
                    text: "Client waiting for proposal approval - can't wait (You)"
                )
                bulletPoint(
                    icon: "exclamationmark.circle.fill",
                    color: .orange,
                    text: "Security vulnerabilities found - patch by EOD (Bob)"
                )
            }
        }
        .padding(12)
        .background(Color.orange.opacity(0.08))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }

    private func actionItemsSection() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("✅ Action Items", systemImage: "checkmark.circle.fill")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.blue)

            // TODO: Replace with actual action items from AI
            VStack(alignment: .leading, spacing: 8) {
                bulletPoint(
                    icon: "circle",
                    color: .blue,
                    text: "Finish quarterly report by Friday EOD (Sarah)"
                )
                bulletPoint(
                    icon: "circle",
                    color: .blue,
                    text: "Send contract to John before tomorrow's meeting"
                )
                bulletPoint(
                    icon: "circle",
                    color: .blue,
                    text: "Review pull request #234 before deploy"
                )
                bulletPoint(
                    icon: "circle",
                    color: .blue,
                    text: "Update documentation by Wednesday"
                )
            }
        }
        .padding(12)
        .background(Color.blue.opacity(0.08))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }

    private func decisionsSection() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("🎯 Decisions", systemImage: "checkmark.seal.fill")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.green)

            // TODO: Replace with actual decisions from AI
            VStack(alignment: .leading, spacing: 8) {
                bulletPoint(
                    icon: "checkmark.circle.fill",
                    color: .green,
                    text: "Team decided to go with option B for architecture"
                )
                bulletPoint(
                    icon: "checkmark.circle.fill",
                    color: .green,
                    text: "Launch postponed to next Monday for quality"
                )
                bulletPoint(
                    icon: "checkmark.circle.fill",
                    color: .green,
                    text: "Using PostgreSQL instead of MongoDB (Alice)"
                )
                bulletPoint(
                    icon: "checkmark.circle.fill",
                    color: .green,
                    text: "Moving forward with React migration next sprint"
                )
            }
        }
        .padding(12)
        .background(Color.green.opacity(0.08))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Helper Views

    private func bulletPoint(icon: String, color: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
                .frame(width: 12)
                .padding(.top, 2)

            Text(text)
                .font(.body)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct SummaryView_Previews: PreviewProvider {
    static var previews: some View {
        // Mock AIService for preview
        class MockAIService: AIServiceProtocol {
            func summarizeThread(conversationId: String, messageIds: [String]?, bypassCache: Bool) async throws -> ThreadSummary {
                // Simulate network delay
                try await Task.sleep(nanoseconds: 1_000_000_000)

                return ThreadSummary(
                    summary: "This is a preview summary of the conversation. The team discussed the implementation of AI features, focusing on thread summarization and action item extraction. Several key decisions were made regarding the architecture and user experience.",
                    keyPoints: [
                        "Decided to use Clean Architecture for the AI features",
                        "Thread summaries should be 150-300 words maximum",
                        "Cache summaries for 24 hours to reduce API costs",
                        "Display summaries in a modal with key points highlighted"
                    ],
                    participants: ["Alice", "Bob", "Charlie"],
                    dateRange: "Oct 20 - Oct 23, 2025",
                    generatedAt: Date().addingTimeInterval(-300), // 5 minutes ago
                    cached: true,
                    messagesSinceCache: 5  // Preview shows staleness indicator
                )
            }

            func extractActionItems(conversationId: String, messageIds: [String]?) async throws -> [AIActionItem] {
                []
            }

            func generateSmartSearchResults(query: String, conversationIds: [String]?) async throws -> [AISearchResult] {
                []
            }
        }

        let viewModel = SummaryViewModel(
            conversationId: "preview-conversation",
            aiService: MockAIService()
        )

        return Group {
            // Loading state
            SummaryView(viewModel: {
                let vm = SummaryViewModel(
                    conversationId: "preview",
                    aiService: MockAIService()
                )
                vm.isLoading = true
                return vm
            }())
            .previewDisplayName("Loading")

            // Success state
            SummaryView(viewModel: {
                let vm = SummaryViewModel(
                    conversationId: "preview",
                    aiService: MockAIService()
                )
                Task { @MainActor in
                    await vm.loadSummary()
                }
                return vm
            }())
            .previewDisplayName("Success")

            // Error state
            SummaryView(viewModel: {
                let vm = SummaryViewModel(
                    conversationId: "preview",
                    aiService: MockAIService()
                )
                vm.errorMessage = "Failed to generate summary. The AI service is temporarily unavailable."
                return vm
            }())
            .previewDisplayName("Error")
        }
    }
}
#endif
