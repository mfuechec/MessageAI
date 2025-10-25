//
//  FirebaseSearchRepository.swift
//  MessageAI
//
//  Tier 3 Semantic Search Implementation
//

import Foundation
import FirebaseFunctions

/// Firebase implementation of semantic search repository
///
/// Calls the `generateSmartSearchResults` Cloud Function which performs
/// AI-powered semantic search using OpenAI embeddings.
class FirebaseSearchRepository: SearchRepositoryProtocol {
    private let functions = Functions.functions()

    func semanticSearch(
        query: String,
        conversationIds: [String]? = nil,
        limit: Int = 20
    ) async throws -> [AISearchResult] {
        // Validate query length
        guard query.count >= 3 else {
            throw SearchError.invalidQuery
        }

        // Build request data
        var requestData: [String: Any] = [
            "query": query,
            "limit": limit
        ]

        if let conversationIds = conversationIds, !conversationIds.isEmpty {
            requestData["conversationIds"] = conversationIds
        }

        do {
            // Call Cloud Function
            let result = try await functions.httpsCallable("generateSmartSearchResults").call(requestData)

            // Parse response
            guard let data = result.data as? [String: Any],
                  let success = data["success"] as? Bool,
                  success,
                  let results = data["results"] as? [[String: Any]] else {
                throw SearchError.invalidResponse
            }

            // Map to AISearchResult entities
            return try results.compactMap { resultData in
                try mapToSearchResult(resultData)
            }

        } catch let error as NSError {
            // Handle Firebase Functions errors
            if error.domain == FunctionsErrorDomain {
                let code = FunctionsErrorCode(rawValue: error.code)

                switch code {
                case .unauthenticated:
                    throw SearchError.unauthenticated

                case .permissionDenied:
                    throw SearchError.permissionDenied

                case .resourceExhausted:
                    throw SearchError.rateLimitExceeded

                case .unavailable:
                    throw SearchError.serviceUnavailable

                default:
                    throw SearchError.unknown(error.localizedDescription)
                }
            }

            throw SearchError.unknown(error.localizedDescription)
        }
    }

    // MARK: - Private Helpers

    /// Map Cloud Function response to AISearchResult entity
    private func mapToSearchResult(_ data: [String: Any]) throws -> AISearchResult {
        guard let messageId = data["messageId"] as? String,
              let conversationId = data["conversationId"] as? String,
              let snippet = data["snippet"] as? String,
              let relevanceScore = data["relevanceScore"] as? Double,
              let senderName = data["senderName"] as? String else {
            throw SearchError.invalidResponse
        }

        // Parse timestamp (can be Firestore Timestamp or Date)
        var timestamp: Date?
        if let timestampData = data["timestamp"] {
            if let date = timestampData as? Date {
                timestamp = date
            } else if let timestampDict = timestampData as? [String: Any],
                      let seconds = timestampDict["_seconds"] as? TimeInterval {
                timestamp = Date(timeIntervalSince1970: seconds)
            }
        }

        return AISearchResult(
            messageId: messageId,
            conversationId: conversationId,
            snippet: snippet,
            relevanceScore: relevanceScore,
            timestamp: timestamp,
            senderName: senderName
        )
    }
}
