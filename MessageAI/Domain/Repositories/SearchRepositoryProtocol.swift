//
//  SearchRepositoryProtocol.swift
//  MessageAI
//
//  Tier 3 Semantic Search Implementation
//

import Foundation

/// Repository protocol for AI-powered semantic search
///
/// Provides semantic search capabilities using OpenAI embeddings
/// for finding messages by meaning, not just keywords.
protocol SearchRepositoryProtocol {
    /// Perform semantic search across user's conversations
    ///
    /// Uses OpenAI embeddings to find messages semantically similar to the query.
    /// - Parameters:
    ///   - query: Search query text (e.g., "when is the project deadline?")
    ///   - conversationIds: Optional array of conversation IDs to search within
    ///   - limit: Maximum number of results to return (default: 20)
    /// - Returns: Array of search results sorted by relevance
    /// - Throws: SearchError for failures
    func semanticSearch(
        query: String,
        conversationIds: [String]?,
        limit: Int
    ) async throws -> [AISearchResult]
}

/// Errors that can occur during search operations
enum SearchError: LocalizedError {
    case invalidQuery
    case invalidResponse
    case unauthenticated
    case permissionDenied
    case rateLimitExceeded
    case serviceUnavailable
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidQuery:
            return "Search query must be at least 3 characters"
        case .invalidResponse:
            return "Invalid search response from server"
        case .unauthenticated:
            return "Please sign in to search messages"
        case .permissionDenied:
            return "You don't have access to these conversations"
        case .rateLimitExceeded:
            return "Too many searches. Please try again in a few seconds."
        case .serviceUnavailable:
            return "Search service temporarily unavailable"
        case .unknown(let message):
            return "Search failed: \(message)"
        }
    }
}
