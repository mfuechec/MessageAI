//
//  CloudFunctionsService.swift
//  MessageAI
//
//  Created by Dev Agent (James) on 10/23/25.
//  Story 3.1: Cloud Functions Infrastructure for AI Services
//

import Foundation
import FirebaseFunctions

/// Service for calling Firebase Cloud Functions
///
/// Low-level network wrapper that handles HTTP calls to Cloud Functions
/// with authentication, error handling, and response parsing.
class CloudFunctionsService {
    private let functions: Functions

    init() {
        self.functions = Functions.functions()
    }

    // MARK: - AI Cloud Functions

    /// Call summarizeThread Cloud Function
    ///
    /// - Parameters:
    ///   - conversationId: The conversation to summarize
    ///   - messageIds: Optional specific message IDs
    /// - Returns: Summary response from Cloud Function
    /// - Throws: AIServiceError on failure
    func callSummarizeThread(
        conversationId: String,
        messageIds: [String]? = nil
    ) async throws -> SummaryResponse {
        let data: [String: Any] = [
            "conversationId": conversationId,
            "messageIds": messageIds ?? []
        ]

        do {
            let result = try await functions.httpsCallable("summarizeThread").call(data)

            guard let response = result.data as? [String: Any] else {
                throw AIServiceError.unknown("Invalid response format from Cloud Function")
            }

            return try parseSummaryResponse(response)
        } catch let error as AIServiceError {
            throw error
        } catch let error as NSError {
            throw mapFirebaseFunctionsError(error)
        }
    }

    /// Call extractActionItems Cloud Function
    ///
    /// - Parameters:
    ///   - conversationId: The conversation to analyze
    ///   - messageIds: Optional specific message IDs
    /// - Returns: Action items response from Cloud Function
    /// - Throws: AIServiceError on failure
    func callExtractActionItems(
        conversationId: String,
        messageIds: [String]? = nil
    ) async throws -> ActionItemsResponse {
        let data: [String: Any] = [
            "conversationId": conversationId,
            "messageIds": messageIds ?? []
        ]

        do {
            let result = try await functions.httpsCallable("extractActionItems").call(data)

            guard let response = result.data as? [String: Any] else {
                throw AIServiceError.unknown("Invalid response format from Cloud Function")
            }

            return try parseActionItemsResponse(response)
        } catch let error as AIServiceError {
            throw error
        } catch let error as NSError {
            throw mapFirebaseFunctionsError(error)
        }
    }

    /// Call generateSmartSearchResults Cloud Function
    ///
    /// - Parameters:
    ///   - query: The search query
    ///   - conversationIds: Optional specific conversations to search
    /// - Returns: Search results response from Cloud Function
    /// - Throws: AIServiceError on failure
    func callGenerateSmartSearchResults(
        query: String,
        conversationIds: [String]? = nil
    ) async throws -> SearchResultsResponse {
        let data: [String: Any] = [
            "query": query,
            "conversationIds": conversationIds ?? []
        ]

        do {
            let result = try await functions.httpsCallable("generateSmartSearchResults").call(data)

            guard let response = result.data as? [String: Any] else {
                throw AIServiceError.unknown("Invalid response format from Cloud Function")
            }

            return try parseSearchResultsResponse(response)
        } catch let error as AIServiceError {
            throw error
        } catch let error as NSError {
            throw mapFirebaseFunctionsError(error)
        }
    }

    // MARK: - Response Parsing

    private func parseSummaryResponse(_ data: [String: Any]) throws -> SummaryResponse {
        guard let success = data["success"] as? Bool,
              let summary = data["summary"] as? String,
              let cached = data["cached"] as? Bool,
              let timestamp = data["timestamp"] as? String else {
            throw AIServiceError.unknown("Missing required fields in summary response")
        }

        let keyPoints = data["keyPoints"] as? [String]
        let participants = data["participants"] as? [String]
        let dateRange = data["dateRange"] as? String

        return SummaryResponse(
            success: success,
            summary: summary,
            keyPoints: keyPoints,
            participants: participants,
            dateRange: dateRange,
            cached: cached,
            timestamp: timestamp
        )
    }

    private func parseActionItemsResponse(_ data: [String: Any]) throws -> ActionItemsResponse {
        guard let success = data["success"] as? Bool,
              let cached = data["cached"] as? Bool,
              let timestamp = data["timestamp"] as? String,
              let actionItemsData = data["actionItems"] as? [[String: Any]] else {
            throw AIServiceError.unknown("Missing required fields in action items response")
        }

        let actionItems = try actionItemsData.map { itemData -> ActionItemDTO in
            guard let task = itemData["task"] as? String,
                  let assignee = itemData["assignee"] as? String,
                  let sourceMessageId = itemData["sourceMessageId"] as? String,
                  let priority = itemData["priority"] as? String else {
                throw AIServiceError.unknown("Invalid action item format")
            }

            let assigneeId = itemData["assigneeId"] as? String
            let deadline = itemData["deadline"] as? String

            return ActionItemDTO(
                task: task,
                assignee: assignee,
                assigneeId: assigneeId,
                deadline: deadline,
                sourceMessageId: sourceMessageId,
                priority: priority
            )
        }

        return ActionItemsResponse(
            success: success,
            actionItems: actionItems,
            cached: cached,
            timestamp: timestamp
        )
    }

    private func parseSearchResultsResponse(_ data: [String: Any]) throws -> SearchResultsResponse {
        guard let success = data["success"] as? Bool,
              let cached = data["cached"] as? Bool,
              let timestamp = data["timestamp"] as? String,
              let resultsData = data["results"] as? [[String: Any]] else {
            throw AIServiceError.unknown("Missing required fields in search results response")
        }

        let results = try resultsData.map { resultData -> SearchResultDTO in
            guard let messageId = resultData["messageId"] as? String,
                  let conversationId = resultData["conversationId"] as? String,
                  let snippet = resultData["snippet"] as? String,
                  let relevanceScore = resultData["relevanceScore"] as? Double,
                  let senderName = resultData["senderName"] as? String else {
                throw AIServiceError.unknown("Invalid search result format")
            }

            // timestamp is optional
            var timestamp: Date?
            if let timestampData = resultData["timestamp"] {
                // Handle Firestore Timestamp
                if let seconds = (timestampData as? [String: Any])?["_seconds"] as? Double {
                    timestamp = Date(timeIntervalSince1970: seconds)
                }
            }

            return SearchResultDTO(
                messageId: messageId,
                conversationId: conversationId,
                snippet: snippet,
                relevanceScore: relevanceScore,
                timestamp: timestamp,
                senderName: senderName
            )
        }

        return SearchResultsResponse(
            success: success,
            results: results,
            cached: cached,
            timestamp: timestamp
        )
    }

    // MARK: - Error Mapping

    private func mapFirebaseFunctionsError(_ error: NSError) -> AIServiceError {
        if let code = FunctionsErrorCode(rawValue: error.code) {
            switch code {
            case .unauthenticated:
                return .unauthenticated
            case .permissionDenied:
                return .unauthenticated
            case .resourceExhausted:
                return .rateLimitExceeded
            case .deadlineExceeded:
                return .timeout
            case .unavailable, .internal:
                return .serviceUnavailable
            case .invalidArgument:
                return .invalidInput(error.localizedDescription)
            default:
                return .unknown(error.localizedDescription)
            }
        }
        return .unknown(error.localizedDescription)
    }
}

// MARK: - Response DTOs

struct SummaryResponse {
    let success: Bool
    let summary: String
    let keyPoints: [String]?
    let participants: [String]?
    let dateRange: String?
    let cached: Bool
    let timestamp: String
}

struct ActionItemsResponse {
    let success: Bool
    let actionItems: [ActionItemDTO]
    let cached: Bool
    let timestamp: String
}

struct ActionItemDTO {
    let task: String
    let assignee: String
    let assigneeId: String?
    let deadline: String?
    let sourceMessageId: String
    let priority: String
}

struct SearchResultsResponse {
    let success: Bool
    let results: [SearchResultDTO]
    let cached: Bool
    let timestamp: String
}

struct SearchResultDTO {
    let messageId: String
    let conversationId: String
    let snippet: String
    let relevanceScore: Double
    let timestamp: Date?
    let senderName: String
}
