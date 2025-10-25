//
//  MockSearchRepository.swift
//  MessageAITests
//
//  Mock implementation of SearchRepositoryProtocol for testing
//

import Foundation
@testable import MessageAI

class MockSearchRepository: SearchRepositoryProtocol {
    // MARK: - Mock Configuration

    /// Results to return from semantic search
    var semanticSearchResult: [AISearchResult] = []

    /// Error to throw from semantic search
    var shouldThrowError: SearchError?

    /// Track if search was called
    var searchWasCalled = false

    /// Track last query used
    var lastQuery: String?

    /// Track last conversation IDs used
    var lastConversationIds: [String]?

    /// Track last limit used
    var lastLimit: Int?

    /// Custom callback when search is performed
    var onSearch: (() -> Void)?

    // MARK: - SearchRepositoryProtocol Implementation

    func semanticSearch(
        query: String,
        conversationIds: [String]?,
        limit: Int
    ) async throws -> [AISearchResult] {
        searchWasCalled = true
        lastQuery = query
        lastConversationIds = conversationIds
        lastLimit = limit

        onSearch?()

        if let error = shouldThrowError {
            throw error
        }

        return semanticSearchResult
    }

    // MARK: - Helper Methods

    /// Reset all tracked state
    func reset() {
        semanticSearchResult = []
        shouldThrowError = nil
        searchWasCalled = false
        lastQuery = nil
        lastConversationIds = nil
        lastLimit = nil
        onSearch = nil
    }
}
