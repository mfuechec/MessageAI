//
//  SearchViewModelTests.swift
//  MessageAITests
//
//  Unit tests for SearchViewModel
//

import XCTest
@testable import MessageAI

@MainActor
class SearchViewModelTests: XCTestCase {
    var mockRepository: MockSearchRepository!
    var viewModel: SearchViewModel!

    override func setUp() async throws {
        mockRepository = MockSearchRepository()
        viewModel = SearchViewModel(searchRepository: mockRepository)
    }

    override func tearDown() async throws {
        mockRepository = nil
        viewModel = nil
    }

    // MARK: - Initialization Tests

    func testInitialization() {
        // Verify initial state
        XCTAssertEqual(viewModel.searchQuery, "")
        XCTAssertEqual(viewModel.results.count, 0)
        XCTAssertFalse(viewModel.isSearching)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertNil(viewModel.selectedConversationIds)
    }

    // MARK: - Search Tests

    func testSemanticSearch_Success() async throws {
        // Given
        let expectedResults = [
            AISearchResult(
                messageId: "msg1",
                conversationId: "conv1",
                snippet: "Project deadline is Friday",
                relevanceScore: 0.92,
                timestamp: Date(),
                senderName: "Alice"
            )
        ]
        mockRepository.semanticSearchResult = expectedResults

        // When
        await viewModel.performSearch("deadline")

        // Then
        XCTAssertEqual(viewModel.results.count, 1)
        XCTAssertEqual(viewModel.results.first?.messageId, "msg1")
        XCTAssertEqual(viewModel.results.first?.relevanceScore, 0.92)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isSearching)
    }

    func testSemanticSearch_EmptyQuery() async throws {
        // Given
        mockRepository.semanticSearchResult = [
            AISearchResult(
                messageId: "msg1",
                conversationId: "conv1",
                snippet: "Test",
                relevanceScore: 0.9,
                timestamp: Date(),
                senderName: "Alice"
            )
        ]

        // When
        await viewModel.performSearch("")

        // Then
        XCTAssertEqual(viewModel.results.count, 0)
        XCTAssertFalse(mockRepository.searchWasCalled)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testSemanticSearch_QueryTooShort() async throws {
        // Given
        mockRepository.semanticSearchResult = [
            AISearchResult(
                messageId: "msg1",
                conversationId: "conv1",
                snippet: "Test",
                relevanceScore: 0.9,
                timestamp: Date(),
                senderName: "Alice"
            )
        ]

        // When
        await viewModel.performSearch("ab") // Only 2 characters

        // Then
        XCTAssertEqual(viewModel.results.count, 0)
        XCTAssertFalse(mockRepository.searchWasCalled)
    }

    func testSemanticSearch_MinimumQueryLength() async throws {
        // Given
        let expectedResults = [
            AISearchResult(
                messageId: "msg1",
                conversationId: "conv1",
                snippet: "Test",
                relevanceScore: 0.9,
                timestamp: Date(),
                senderName: "Alice"
            )
        ]
        mockRepository.semanticSearchResult = expectedResults

        // When
        await viewModel.performSearch("abc") // Exactly 3 characters (minimum)

        // Then
        XCTAssertEqual(viewModel.results.count, 1)
        XCTAssertTrue(mockRepository.searchWasCalled)
    }

    func testSemanticSearch_RateLimitError() async throws {
        // Given
        mockRepository.shouldThrowError = .rateLimitExceeded

        // When
        await viewModel.performSearch("test query")

        // Then
        XCTAssertTrue(viewModel.results.isEmpty)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.errorMessage!.contains("Too many searches"))
        XCTAssertFalse(viewModel.isSearching)
    }

    func testSemanticSearch_UnauthenticatedError() async throws {
        // Given
        mockRepository.shouldThrowError = .unauthenticated

        // When
        await viewModel.performSearch("test query")

        // Then
        XCTAssertTrue(viewModel.results.isEmpty)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.errorMessage!.contains("sign in"))
    }

    func testSemanticSearch_ServiceUnavailable() async throws {
        // Given
        mockRepository.shouldThrowError = .serviceUnavailable

        // When
        await viewModel.performSearch("test query")

        // Then
        XCTAssertTrue(viewModel.results.isEmpty)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.errorMessage!.contains("unavailable"))
    }

    func testSemanticSearch_UnknownError() async throws {
        // Given
        mockRepository.shouldThrowError = .unknown("Custom error message")

        // When
        await viewModel.performSearch("test query")

        // Then
        XCTAssertTrue(viewModel.results.isEmpty)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.errorMessage!.contains("Custom error message"))
    }

    // MARK: - Debounce Tests

    func testDebounce_OnlyLastQueryExecuted() async throws {
        // Given
        var searchCount = 0
        mockRepository.onSearch = { searchCount += 1 }
        mockRepository.semanticSearchResult = []

        // When - Set query multiple times rapidly
        viewModel.searchQuery = "abc"
        viewModel.searchQuery = "abcd"
        viewModel.searchQuery = "abcde"

        // Wait for debounce (0.5 seconds + buffer)
        try await Task.sleep(nanoseconds: 700_000_000) // 0.7 seconds

        // Then - Should only search once with final query
        XCTAssertEqual(searchCount, 1, "Should only search once after debounce")
        XCTAssertEqual(mockRepository.lastQuery, "abcde", "Should use last query")
    }

    // MARK: - Clear Search Tests

    func testClearSearch() async throws {
        // Given - Set up search state
        viewModel.searchQuery = "test query"
        viewModel.results = [
            AISearchResult(
                messageId: "msg1",
                conversationId: "conv1",
                snippet: "Test",
                relevanceScore: 0.9,
                timestamp: Date(),
                senderName: "Alice"
            )
        ]
        viewModel.errorMessage = "Some error"
        viewModel.selectedConversationIds = ["conv1", "conv2"]

        // When
        viewModel.clearSearch()

        // Then
        XCTAssertEqual(viewModel.searchQuery, "")
        XCTAssertEqual(viewModel.results.count, 0)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertNil(viewModel.selectedConversationIds)
    }

    // MARK: - Filter Conversations Tests

    func testFilterConversations() async throws {
        // Given
        let conversationIds = ["conv1", "conv2"]
        mockRepository.semanticSearchResult = [
            AISearchResult(
                messageId: "msg1",
                conversationId: "conv1",
                snippet: "Test",
                relevanceScore: 0.9,
                timestamp: Date(),
                senderName: "Alice"
            )
        ]
        viewModel.searchQuery = "test"

        // Wait for initial debounce
        try await Task.sleep(nanoseconds: 600_000_000)

        // When
        viewModel.filterConversations(conversationIds)

        // Wait for search to complete
        try await Task.sleep(nanoseconds: 100_000_000)

        // Then
        XCTAssertEqual(viewModel.selectedConversationIds, conversationIds)
        XCTAssertEqual(mockRepository.lastConversationIds, conversationIds)
    }

    // MARK: - Relevance Tests

    func testRelevancePercentage() {
        // Given
        let result = AISearchResult(
            messageId: "msg1",
            conversationId: "conv1",
            snippet: "Test",
            relevanceScore: 0.856,
            timestamp: Date(),
            senderName: "Alice"
        )

        // When
        let percentage = viewModel.relevancePercentage(for: result)

        // Then
        XCTAssertEqual(percentage, 85)
    }

    func testIsHighlyRelevant_True() {
        // Given
        let result = AISearchResult(
            messageId: "msg1",
            conversationId: "conv1",
            snippet: "Test",
            relevanceScore: 0.92,
            timestamp: Date(),
            senderName: "Alice"
        )

        // When/Then
        XCTAssertTrue(viewModel.isHighlyRelevant(result))
    }

    func testIsHighlyRelevant_False() {
        // Given
        let result = AISearchResult(
            messageId: "msg1",
            conversationId: "conv1",
            snippet: "Test",
            relevanceScore: 0.75,
            timestamp: Date(),
            senderName: "Alice"
        )

        // When/Then
        XCTAssertFalse(viewModel.isHighlyRelevant(result))
    }

    func testIsHighlyRelevant_Boundary() {
        // Given - Exactly at threshold
        let result = AISearchResult(
            messageId: "msg1",
            conversationId: "conv1",
            snippet: "Test",
            relevanceScore: 0.8,
            timestamp: Date(),
            senderName: "Alice"
        )

        // When/Then
        XCTAssertFalse(viewModel.isHighlyRelevant(result))
    }

    // MARK: - Multiple Results Tests

    func testSemanticSearch_MultipleResults() async throws {
        // Given
        let expectedResults = [
            AISearchResult(
                messageId: "msg1",
                conversationId: "conv1",
                snippet: "First result",
                relevanceScore: 0.95,
                timestamp: Date(),
                senderName: "Alice"
            ),
            AISearchResult(
                messageId: "msg2",
                conversationId: "conv1",
                snippet: "Second result",
                relevanceScore: 0.85,
                timestamp: Date(),
                senderName: "Bob"
            ),
            AISearchResult(
                messageId: "msg3",
                conversationId: "conv2",
                snippet: "Third result",
                relevanceScore: 0.75,
                timestamp: Date(),
                senderName: "Charlie"
            )
        ]
        mockRepository.semanticSearchResult = expectedResults

        // When
        await viewModel.performSearch("test query")

        // Then
        XCTAssertEqual(viewModel.results.count, 3)
        XCTAssertEqual(viewModel.results[0].relevanceScore, 0.95)
        XCTAssertEqual(viewModel.results[1].relevanceScore, 0.85)
        XCTAssertEqual(viewModel.results[2].relevanceScore, 0.75)
    }

    // MARK: - Error Recovery Tests

    func testSemanticSearch_ErrorRecovery() async throws {
        // Given - First search fails
        mockRepository.shouldThrowError = .serviceUnavailable

        // When - First search
        await viewModel.performSearch("test query")

        // Then - Error displayed
        XCTAssertTrue(viewModel.results.isEmpty)
        XCTAssertNotNil(viewModel.errorMessage)

        // Given - Second search succeeds
        mockRepository.shouldThrowError = nil
        mockRepository.semanticSearchResult = [
            AISearchResult(
                messageId: "msg1",
                conversationId: "conv1",
                snippet: "Success",
                relevanceScore: 0.9,
                timestamp: Date(),
                senderName: "Alice"
            )
        ]

        // When - Second search
        await viewModel.performSearch("test query 2")

        // Then - Success, error cleared
        XCTAssertEqual(viewModel.results.count, 1)
        XCTAssertNil(viewModel.errorMessage)
    }
}
