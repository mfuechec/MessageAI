//
//  SearchView.swift
//  MessageAI
//
//  Tier 3 Semantic Search Implementation
//

import SwiftUI

/// Main search view for AI-powered semantic search
///
/// Provides a search interface that uses OpenAI embeddings to find
/// messages by meaning, not just keywords.
struct SearchView: View {
    @StateObject private var viewModel: SearchViewModel
    @FocusState private var isSearchFocused: Bool
    @SwiftUI.Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>

    init(viewModel: SearchViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                searchBar
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                // AI Badge
                HStack {
                    Label("AI Semantic Search", systemImage: "brain")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)

                    Spacer()

                    if viewModel.isSearching {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)

                // Main Content
                if viewModel.isSearching {
                    loadingView
                } else if let errorMessage = viewModel.errorMessage {
                    errorView(errorMessage)
                } else if viewModel.results.isEmpty && !viewModel.searchQuery.isEmpty {
                    emptyResultsView
                } else if !viewModel.results.isEmpty {
                    resultsListView
                } else {
                    placeholderView
                }
            }
            .navigationTitle("Search Messages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    if !viewModel.searchQuery.isEmpty {
                        Button("Clear") {
                            viewModel.clearSearch()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Search by meaning, not just keywords...", text: $viewModel.searchQuery)
                .focused($isSearchFocused)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()

            if !viewModel.searchQuery.isEmpty {
                Button(action: {
                    viewModel.searchQuery = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .onAppear {
            isSearchFocused = true
        }
    }

    // MARK: - Results List

    private var resultsListView: some View {
        List {
            Section {
                ForEach(viewModel.results, id: \.messageId) { result in
                    SearchResultRow(result: result, viewModel: viewModel)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            // TODO: Navigate to message in conversation
                            // Can be implemented when adding deep linking
                        }
                }
            } header: {
                Text("\(viewModel.results.count) results found")
                    .font(.caption)
                    .textCase(.none)
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Searching with AI...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.red)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Try Again") {
                Task {
                    await viewModel.performSearch(viewModel.searchQuery)
                }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty Results

    private var emptyResultsView: some View {
        ContentUnavailableView {
            Label("No Results", systemImage: "magnifyingglass")
        } description: {
            Text("No messages found matching '\(viewModel.searchQuery)'")
        } actions: {
            Button("Clear Search") {
                viewModel.clearSearch()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Placeholder

    private var placeholderView: some View {
        VStack(spacing: 20) {
            Image(systemName: "brain")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            VStack(spacing: 8) {
                Text("AI-Powered Semantic Search")
                    .font(.headline)

                Text("Search finds messages by meaning, not just keywords")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            VStack(alignment: .leading, spacing: 12) {
                ExampleSearchRow(
                    query: "when is the deadline?",
                    finds: "Finds 'project due Friday'"
                )

                ExampleSearchRow(
                    query: "meeting schedule",
                    finds: "Finds 'sync call at 3pm'"
                )

                ExampleSearchRow(
                    query: "urgent issues",
                    finds: "Finds 'critical bug reported'"
                )
            }
            .padding(.top)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let result: AISearchResult
    let viewModel: SearchViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Relevance Score
            HStack {
                Label("\(viewModel.relevancePercentage(for: result))% match", systemImage: "sparkles")
                    .font(.caption2)
                    .foregroundColor(relevanceColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(relevanceColor.opacity(0.1))
                    .cornerRadius(4)

                Spacer()

                if let timestamp = result.timestamp {
                    Text(timestamp, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Message Snippet
            Text(result.snippet)
                .font(.body)
                .lineLimit(3)

            // Sender Name
            Text("From: \(result.senderName)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var relevanceColor: Color {
        if result.relevanceScore > 0.8 {
            return .green
        } else if result.relevanceScore > 0.6 {
            return .orange
        } else {
            return .gray
        }
    }
}

// MARK: - Example Search Row

struct ExampleSearchRow: View {
    let query: String
    let finds: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "arrow.right")
                .foregroundColor(.blue)
                .font(.caption)

            VStack(alignment: .leading, spacing: 4) {
                Text(query)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(finds)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let mockRepository = MockSearchRepository()
    let viewModel = SearchViewModel(searchRepository: mockRepository)
    return SearchView(viewModel: viewModel)
}

// MARK: - Mock Repository for Preview

class MockSearchRepository: SearchRepositoryProtocol {
    func semanticSearch(query: String, conversationIds: [String]?, limit: Int) async throws -> [AISearchResult] {
        // Return mock data for preview
        return [
            AISearchResult(
                messageId: "1",
                conversationId: "conv1",
                snippet: "The project deadline is Friday at 5pm. Make sure all features are complete by then.",
                relevanceScore: 0.92,
                timestamp: Date().addingTimeInterval(-3600),
                senderName: "Alice"
            ),
            AISearchResult(
                messageId: "2",
                conversationId: "conv2",
                snippet: "We need to schedule a sync call to discuss the urgent issues with the API.",
                relevanceScore: 0.85,
                timestamp: Date().addingTimeInterval(-7200),
                senderName: "Bob"
            )
        ]
    }
}
