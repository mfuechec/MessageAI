//
//  SummaryViewModel.swift
//  MessageAI
//
//  Created by Claude Code on 10/23/25.
//  Story 3.2: Thread Summarization Feature
//

import Foundation
import Combine
import FirebaseFirestore

/// ViewModel for managing thread summarization feature
///
/// Handles AI-powered conversation summarization including:
/// - Loading and caching summaries
/// - Regenerating summaries on demand
/// - Error handling and loading states
/// - Timestamp tracking for cache validation
@MainActor
class SummaryViewModel: ObservableObject, Identifiable {
    // MARK: - Identifiable
    let id = UUID()
    // MARK: - Published Properties

    /// Current summary, nil if not yet loaded
    @Published var summary: ThreadSummary? {
        didSet {
            print("🔄 [SummaryViewModel] summary changed: \(oldValue != nil ? "had summary" : "nil") → \(summary != nil ? "has summary" : "nil")")
        }
    }

    /// Loading state indicator (starts true since we always load on init)
    @Published var isLoading = true {
        didSet {
            print("🔄 [SummaryViewModel] isLoading changed: \(oldValue) → \(isLoading)")
        }
    }

    /// Error message if summary generation failed
    @Published var errorMessage: String?

    // MARK: - Dependencies

    private let aiService: AIServiceProtocol
    private let conversationId: String
    private let userId: String
    private let messageIds: [String]?
    private let db = Firestore.firestore()

    // MARK: - Initialization

    /// Initialize SummaryViewModel with required dependencies
    ///
    /// - Parameters:
    ///   - conversationId: The conversation to summarize
    ///   - userId: Current user ID for per-user cache
    ///   - messageIds: Optional specific message IDs to summarize (nil = last 100 messages)
    ///   - aiService: AI service for generating summaries
    init(
        conversationId: String,
        userId: String,
        messageIds: [String]? = nil,
        aiService: AIServiceProtocol
    ) {
        print("🟢 [SummaryViewModel] init() called")
        print("   conversationId: \(conversationId)")
        print("   userId: \(userId)")
        print("   messageIds count: \(messageIds?.count ?? 0)")
        print("   Initial isLoading: true")

        self.conversationId = conversationId
        self.userId = userId
        self.messageIds = messageIds
        self.aiService = aiService

        print("🟢 [SummaryViewModel] init() complete")
    }

    // MARK: - Public Methods

    /// Load summary for the conversation
    ///
    /// Optimistic loading: First checks Firestore cache for instant display,
    /// then calls Cloud Function only if cache is missing or explicitly bypassed.
    /// Updates published properties with results or errors.
    func loadSummary(bypassCache: Bool = false) async {
        print("🟡 [SummaryViewModel] Starting loadSummary()")
        print("   Conversation ID: \(conversationId)")
        print("   User ID: \(userId)")
        print("   Message IDs: \(messageIds?.count ?? 0)")
        print("   Bypass cache: \(bypassCache)")

        isLoading = true
        errorMessage = nil

        // Step 1: Try to load from Firestore cache first (unless bypassing)
        if !bypassCache {
            do {
                if let cachedSummary = try await loadFromFirestoreCache() {
                    print("✅ [SummaryViewModel] Loaded summary from Firestore cache")
                    print("   Summary length: \(cachedSummary.summary.count) characters")
                    print("   Generated at: \(cachedSummary.generatedAt)")

                    summary = cachedSummary
                    isLoading = false
                    return  // Display cached summary, done!
                } else {
                    print("ℹ️  [SummaryViewModel] No Firestore cache found, will call Cloud Function")
                }
            } catch {
                print("⚠️  [SummaryViewModel] Failed to load from Firestore cache: \(error.localizedDescription)")
                print("   Will fall through to Cloud Function")
            }
        }

        // Step 2: No cache or bypassing - call Cloud Function
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
            print("   Priority messages: \(result.priorityMessages.count)")
            print("   Cached: \(result.cached)")

            // Debug priority messages
            if result.priorityMessages.isEmpty {
                print("⚠️  [SummaryViewModel] No priority messages in ThreadSummary!")
            } else {
                print("🔍 [SummaryViewModel] Priority messages received:")
                for (idx, pm) in result.priorityMessages.enumerated() {
                    print("   [\(idx)] text=\(pm.text.prefix(50))..., sourceMessageId=\(pm.sourceMessageId), priority=\(pm.priority)")
                }
            }

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

    /// Load summary from Firestore cache
    ///
    /// Returns cached summary if available, nil if not found.
    private func loadFromFirestoreCache() async throws -> ThreadSummary? {
        print("📖 [SummaryViewModel] Reading from Firestore cache")
        print("   Path: users/\(userId)/conversation_summaries/\(conversationId)")

        let docRef = db.collection("users")
            .document(userId)
            .collection("conversation_summaries")
            .document(conversationId)

        let snapshot = try await docRef.getDocument()

        guard snapshot.exists else {
            print("   Cache miss - document doesn't exist")
            return nil
        }

        guard let data = snapshot.data() else {
            print("   Cache miss - no data in document")
            return nil
        }

        print("   Cache hit! Parsing summary data")

        // Parse Firestore document into ThreadSummary
        let summary = data["summary"] as? String ?? ""
        let keyPoints = data["keyPoints"] as? [String] ?? []
        let participants = data["participants"] as? [String] ?? []
        let dateRange = data["dateRange"] as? String ?? ""
        let lastMessageId = data["lastMessageId"] as? String
        let messageCount = data["messageCount"] as? Int

        // Parse generatedAt timestamp
        let generatedAt: Date
        if let timestamp = data["generatedAt"] as? Timestamp {
            generatedAt = timestamp.dateValue()
        } else {
            generatedAt = Date()
        }

        // Parse priority messages
        let priorityMessagesData = data["priorityMessages"] as? [[String: Any]] ?? []
        let priorityMessages = priorityMessagesData.compactMap { dict -> PriorityMessage? in
            guard let text = dict["text"] as? String,
                  let sourceMessageId = dict["sourceMessageId"] as? String,
                  let priorityStr = dict["priority"] as? String else {
                return nil
            }
            return PriorityMessage(
                text: text,
                sourceMessageId: sourceMessageId,
                priority: priorityStr
            )
        }

        return ThreadSummary(
            summary: summary,
            keyPoints: keyPoints,
            priorityMessages: priorityMessages,
            participants: participants,
            dateRange: dateRange,
            generatedAt: generatedAt,
            cached: true,
            messagesSinceCache: 0,  // TODO: Calculate staleness in future
            lastMessageId: lastMessageId,
            messageCount: messageCount
        )
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
