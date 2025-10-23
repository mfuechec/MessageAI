//
//  FirebaseAIService.swift
//  MessageAI
//
//  Created by Dev Agent (James) on 10/23/25.
//  Story 3.1: Cloud Functions Infrastructure for AI Services
//

import Foundation

/// Firebase implementation of AI service
///
/// Implements AIServiceProtocol by wrapping CloudFunctionsService.
/// Maps Cloud Function responses to domain entities and handles errors.
class FirebaseAIService: AIServiceProtocol {
    private let cloudFunctionsService: CloudFunctionsService

    init(cloudFunctionsService: CloudFunctionsService) {
        self.cloudFunctionsService = cloudFunctionsService
    }

    // MARK: - AIServiceProtocol Implementation

    func summarizeThread(
        conversationId: String,
        messageIds: [String]?
    ) async throws -> ThreadSummary {
        let response = try await cloudFunctionsService.callSummarizeThread(
            conversationId: conversationId,
            messageIds: messageIds
        )

        // Parse timestamp
        let generatedAt: Date
        if let date = ISO8601DateFormatter().date(from: response.timestamp) {
            generatedAt = date
        } else {
            generatedAt = Date()
        }

        return ThreadSummary(
            summary: response.summary,
            keyPoints: response.keyPoints ?? [],
            participants: response.participants ?? [],
            dateRange: response.dateRange ?? "",
            generatedAt: generatedAt,
            cached: response.cached
        )
    }

    func extractActionItems(
        conversationId: String,
        messageIds: [String]?
    ) async throws -> [AIActionItem] {
        let response = try await cloudFunctionsService.callExtractActionItems(
            conversationId: conversationId,
            messageIds: messageIds
        )

        return response.actionItems.map { dto in
            AIActionItem(
                task: dto.task,
                assignee: dto.assignee,
                assigneeId: dto.assigneeId,
                deadline: dto.deadline,
                sourceMessageId: dto.sourceMessageId,
                priority: dto.priority
            )
        }
    }

    func generateSmartSearchResults(
        query: String,
        conversationIds: [String]?
    ) async throws -> [AISearchResult] {
        let response = try await cloudFunctionsService.callGenerateSmartSearchResults(
            query: query,
            conversationIds: conversationIds
        )

        return response.results.map { dto in
            AISearchResult(
                messageId: dto.messageId,
                conversationId: dto.conversationId,
                snippet: dto.snippet,
                relevanceScore: dto.relevanceScore,
                timestamp: dto.timestamp,
                senderName: dto.senderName
            )
        }
    }
}
