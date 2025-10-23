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
        messageIds: [String]?,
        bypassCache: Bool = false
    ) async throws -> ThreadSummary {
        print("🟢 [FirebaseAIService] summarizeThread() called")
        print("   Conversation ID: \(conversationId)")
        print("   Bypass cache: \(bypassCache)")

        let response = try await cloudFunctionsService.callSummarizeThread(
            conversationId: conversationId,
            messageIds: messageIds,
            bypassCache: bypassCache
        )

        print("🟢 [FirebaseAIService] Cloud Function response received")
        print("   Success: \(response.success)")
        print("   Cached: \(response.cached)")

        // Parse timestamp
        let generatedAt: Date
        if let date = ISO8601DateFormatter().date(from: response.timestamp) {
            generatedAt = date
        } else {
            print("⚠️  [FirebaseAIService] Failed to parse timestamp: \(response.timestamp), using Date()")
            generatedAt = Date()
        }

        // Map priority messages from DTO to domain entities
        print("🔍 [FirebaseAIService] Mapping priority messages from DTO")
        print("   Response priorityMessages count: \(response.priorityMessages?.count ?? 0)")

        let priorityMessages = (response.priorityMessages ?? []).map { dto in
            print("   Mapping DTO: text=\(dto.text.prefix(30))..., sourceMessageId=\(dto.sourceMessageId), priority=\(dto.priority)")
            return PriorityMessage(
                text: dto.text,
                sourceMessageId: dto.sourceMessageId,
                priority: dto.priority
            )
        }

        print("✅ [FirebaseAIService] Mapped \(priorityMessages.count) priority messages to domain entities")

        let summary = ThreadSummary(
            summary: response.summary,
            keyPoints: response.keyPoints ?? [],
            priorityMessages: priorityMessages,
            participants: response.participants ?? [],
            dateRange: response.dateRange ?? "",
            generatedAt: generatedAt,
            cached: response.cached,
            messagesSinceCache: response.messagesSinceCache
        )

        print("✅ [FirebaseAIService] Mapped to ThreadSummary successfully")
        print("   Messages since cache: \(response.messagesSinceCache)")
        print("   Priority messages in ThreadSummary: \(summary.priorityMessages.count)")

        return summary
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
