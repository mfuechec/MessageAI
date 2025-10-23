//
//  AIServiceProtocol.swift
//  MessageAI
//
//  Created by Dev Agent (James) on 10/23/25.
//  Story 3.1: Cloud Functions Infrastructure for AI Services
//

import Foundation

/// Protocol for AI service operations
///
/// Defines the interface for AI-powered features like thread summarization,
/// action item extraction, and smart search. Implementations call Cloud Functions
/// that handle the actual AI processing.
protocol AIServiceProtocol {
    /// Summarize a conversation thread
    ///
    /// - Parameters:
    ///   - conversationId: The conversation to summarize
    ///   - messageIds: Optional specific message IDs to summarize (nil = last 100 messages)
    /// - Returns: Thread summary with key points and participants
    /// - Throws: AIServiceError if the request fails
    func summarizeThread(
        conversationId: String,
        messageIds: [String]?,
        bypassCache: Bool
    ) async throws -> ThreadSummary

    /// Extract action items from a conversation
    ///
    /// - Parameters:
    ///   - conversationId: The conversation to analyze
    ///   - messageIds: Optional specific message IDs to analyze (nil = last 100 messages)
    /// - Returns: Array of action items with assignees and deadlines
    /// - Throws: AIServiceError if the request fails
    func extractActionItems(
        conversationId: String,
        messageIds: [String]?
    ) async throws -> [AIActionItem]

    /// Perform AI-enhanced semantic search across conversations
    ///
    /// - Parameters:
    ///   - query: The search query (natural language or keywords)
    ///   - conversationIds: Optional specific conversations to search (nil = all user's conversations)
    /// - Returns: Array of search results ranked by relevance
    /// - Throws: AIServiceError if the request fails
    func generateSmartSearchResults(
        query: String,
        conversationIds: [String]?
    ) async throws -> [AISearchResult]
}

/// Errors that can occur when using AI services
enum AIServiceError: LocalizedError {
    case unauthenticated
    case rateLimitExceeded
    case serviceUnavailable
    case timeout
    case invalidInput(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .unauthenticated:
            return "Please sign in to use AI features."
        case .rateLimitExceeded:
            return "You've reached your daily limit of 100 AI requests. Please try again tomorrow."
        case .serviceUnavailable:
            return "AI service is temporarily unavailable. Please try again later."
        case .timeout:
            return "AI request took too long. Please try again with fewer messages."
        case .invalidInput(let message):
            return "Invalid input: \(message)"
        case .unknown(let message):
            return "An error occurred: \(message)"
        }
    }
}
