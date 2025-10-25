//
//  SearchViewModel.swift
//  MessageAI
//
//  Tier 3 Semantic Search Implementation
//

import Foundation
import Combine

/// ViewModel for AI-powered semantic search
///
/// Manages search state and coordinates with FirebaseSearchRepository
/// to perform semantic search using OpenAI embeddings.
@MainActor
class SearchViewModel: ObservableObject {
    // MARK: - Published State

    /// Current search query text
    @Published var searchQuery = ""

    /// Search results from AI semantic search
    @Published var results: [AISearchResult] = []

    /// Whether a search is currently in progress
    @Published var isSearching = false

    /// Error message to display to user
    @Published var errorMessage: String?

    /// Selected conversation IDs to filter search (nil = search all)
    @Published var selectedConversationIds: [String]?

    // MARK: - Dependencies

    private let searchRepository: SearchRepositoryProtocol
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Constants

    private let minQueryLength = 3
    private let debounceInterval: TimeInterval = 0.5 // 500ms debounce
    private let defaultResultLimit = 20

    // MARK: - Initialization

    init(searchRepository: SearchRepositoryProtocol) {
        self.searchRepository = searchRepository
        setupSearchDebounce()
    }

    // MARK: - Setup

    /// Setup debounced search to avoid excessive API calls
    private func setupSearchDebounce() {
        $searchQuery
            .debounce(for: .seconds(debounceInterval), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                Task { @MainActor in
                    await self?.performSearch(query)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Public Methods

    /// Perform semantic search with current query
    func performSearch(_ query: String) async {
        // Clear results if query is empty
        guard !query.isEmpty else {
            results = []
            errorMessage = nil
            return
        }

        // Require minimum query length
        guard query.count >= minQueryLength else {
            results = []
            errorMessage = nil
            return
        }

        isSearching = true
        errorMessage = nil

        do {
            // Call repository to perform semantic search
            results = try await searchRepository.semanticSearch(
                query: query,
                conversationIds: selectedConversationIds,
                limit: defaultResultLimit
            )

            // Clear error on success
            errorMessage = nil

        } catch let error as SearchError {
            // Handle known search errors
            errorMessage = error.errorDescription
            results = []

        } catch {
            // Handle unknown errors
            errorMessage = "Search failed: \(error.localizedDescription)"
            results = []
        }

        isSearching = false
    }

    /// Clear all search state
    func clearSearch() {
        searchQuery = ""
        results = []
        errorMessage = nil
        selectedConversationIds = nil
    }

    /// Filter search to specific conversations
    func filterConversations(_ conversationIds: [String]?) {
        selectedConversationIds = conversationIds

        // Re-run search if query exists
        if !searchQuery.isEmpty {
            Task {
                await performSearch(searchQuery)
            }
        }
    }

    /// Get relevance percentage for display (0-100)
    func relevancePercentage(for result: AISearchResult) -> Int {
        Int(result.relevanceScore * 100)
    }

    /// Check if result is highly relevant (> 80% similarity)
    func isHighlyRelevant(_ result: AISearchResult) -> Bool {
        result.relevanceScore > 0.8
    }

    /// Get formatted timestamp for display
    func formattedTimestamp(for result: AISearchResult) -> String {
        guard let timestamp = result.timestamp else {
            return "Unknown time"
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}
