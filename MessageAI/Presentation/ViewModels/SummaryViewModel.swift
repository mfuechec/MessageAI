//
//  SummaryViewModel.swift
//  MessageAI
//
//  Created by Claude Code on 10/23/25.
//  Story 3.2: Thread Summarization Feature
//

import Foundation
import Combine

/// ViewModel for managing thread summarization feature
///
/// Handles AI-powered conversation summarization including:
/// - Loading and caching summaries
/// - Regenerating summaries on demand
/// - Error handling and loading states
/// - Timestamp tracking for cache validation
@MainActor
class SummaryViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Current summary, nil if not yet loaded
    @Published var summary: ThreadSummary?

    /// Loading state indicator
    @Published var isLoading = false

    /// Error message if summary generation failed
    @Published var errorMessage: String?

    // MARK: - Dependencies

    private let aiService: AIServiceProtocol
    private let conversationId: String
    private let messageIds: [String]?

    // MARK: - Initialization

    /// Initialize SummaryViewModel with required dependencies
    ///
    /// - Parameters:
    ///   - conversationId: The conversation to summarize
    ///   - messageIds: Optional specific message IDs to summarize (nil = last 100 messages)
    ///   - aiService: AI service for generating summaries
    init(
        conversationId: String,
        messageIds: [String]? = nil,
        aiService: AIServiceProtocol
    ) {
        self.conversationId = conversationId
        self.messageIds = messageIds
        self.aiService = aiService
    }

    // MARK: - Public Methods

    /// Load summary for the conversation
    ///
    /// Calls AI service to generate or retrieve cached summary.
    /// Updates published properties with results or errors.
    func loadSummary(bypassCache: Bool = false) async {
        print("🟡 [SummaryViewModel] Starting loadSummary()")
        print("   Conversation ID: \(conversationId)")
        print("   Message IDs: \(messageIds?.count ?? 0)")
        print("   Bypass cache: \(bypassCache)")

        isLoading = true
        errorMessage = nil

        do {
            print("🔵 [SummaryViewModel] Calling aiService.summarizeThread()")
            let result = try await aiService.summarizeThread(
                conversationId: conversationId,
                messageIds: messageIds,
                bypassCache: bypassCache
            )

            print("✅ [SummaryViewModel] Received summary successfully")
            print("   Summary length: \(result.summary.count) characters")
            print("   Key points: \(result.keyPoints.count)")
            print("   Cached: \(result.cached)")

            summary = result
            isLoading = false
        } catch let error as AIServiceError {
            print("❌ [SummaryViewModel] AIServiceError caught:")
            print("   Error: \(error)")
            print("   Description: \(error.errorDescription ?? "No description")")
            handleError(error)
        } catch {
            print("❌ [SummaryViewModel] Unknown error caught:")
            print("   Error: \(error)")
            print("   Localized: \(error.localizedDescription)")
            handleError(.unknown(error.localizedDescription))
        }
    }

    /// Regenerate summary (bypass cache)
    ///
    /// Forces a fresh summary generation, ignoring any cached results.
    /// For Story 3.2, this calls the same endpoint. In future stories,
    /// we may add a cache bypass parameter.
    func regenerateSummary() async {
        // Clear existing summary before regenerating
        summary = nil
        // Force fresh generation by bypassing cache
        await loadSummary(bypassCache: true)
    }

    /// Clear current summary and reset state
    func clearSummary() {
        summary = nil
        errorMessage = nil
    }

    // MARK: - Computed Properties

    /// Formatted timestamp showing when summary was generated
    var generatedAtText: String {
        guard let summary = summary else { return "" }

        let now = Date()
        let timeInterval = now.timeIntervalSince(summary.generatedAt)

        // Less than 1 minute ago
        if timeInterval < 60 {
            return "Generated just now"
        }

        // Less than 1 hour ago
        if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "Generated \(minutes) \(minutes == 1 ? "minute" : "minutes") ago"
        }

        // Less than 24 hours ago
        if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "Generated \(hours) \(hours == 1 ? "hour" : "hours") ago"
        }

        // More than 24 hours ago
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "Generated \(formatter.string(from: summary.generatedAt))"
    }

    /// Whether summary is from cache (shows cache indicator)
    var isCached: Bool {
        summary?.cached ?? false
    }

    // MARK: - Private Methods

    private func handleError(_ error: AIServiceError) {
        isLoading = false
        errorMessage = error.errorDescription ?? "An unknown error occurred"
    }
}
