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
            .navigationTitle("Thread Summary")
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

                // Main summary text
                summarySection(summary: summary)

                // Key points
                if !summary.keyPoints.isEmpty {
                    keyPointsSection(summary: summary)
                }

                // Participants
                if !summary.participants.isEmpty {
                    participantsSection(summary: summary)
                }

                // Date range
                if !summary.dateRange.isEmpty {
                    dateRangeSection(summary: summary)
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
        VStack(alignment: .leading, spacing: 12) {
            Label("Summary", systemImage: "doc.text")
                .font(.headline)
                .foregroundColor(.primary)

            Text(summary.summary)
                .font(.body)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundColor(.primary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func keyPointsSection(summary: ThreadSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Key Points", systemImage: "list.bullet")
                .font(.headline)
                .foregroundColor(.primary)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(summary.keyPoints.enumerated()), id: \.offset) { _, point in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 6, height: 6)
                            .padding(.top, 7)

                        Text(point)
                            .font(.body)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func participantsSection(summary: ThreadSummary) -> some View {
        HStack(spacing: 12) {
            Label("Participants", systemImage: "person.2")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Text(summary.participants.joined(separator: ", "))
                .font(.body)
                .foregroundColor(.primary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func dateRangeSection(summary: ThreadSummary) -> some View {
        HStack(spacing: 12) {
            Label("Date Range", systemImage: "calendar")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Text(summary.dateRange)
                .font(.body)
                .foregroundColor(.primary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
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
