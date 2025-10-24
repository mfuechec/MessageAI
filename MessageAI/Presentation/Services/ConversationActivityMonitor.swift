//
//  ConversationActivityMonitor.swift
//  MessageAI
//
//  Created by Claude Code on 10/23/25.
//  Epic 6 - Story 6.1: Conversation Activity Monitoring & Trigger Logic
//

import Foundation
import Combine

/// Conversation state for activity monitoring
enum ConversationState {
    case active        // Currently receiving messages
    case paused        // No messages for pause threshold
    case thresholdExceeded  // Exceeded message threshold
}

/// Monitors conversation activity and triggers AI notification analysis (Epic 6 - Story 6.1)
///
/// Responsibilities:
/// - Track message timing per conversation
/// - Detect conversation pauses (e.g., 120 seconds of inactivity)
/// - Detect high-activity conversations (e.g., 20+ messages in 10 minutes)
/// - Trigger analysis when appropriate
/// - Suppress analysis for active conversations (user is viewing)
/// - Debounce analysis (max once per 5 minutes per conversation)
@MainActor
final class ConversationActivityMonitor: ObservableObject {

    // MARK: - Configuration

    /// Pause threshold in seconds (default: 120s)
    var pauseThresholdSeconds: Int = 120

    /// Message threshold for high-activity detection (default: 20 messages)
    var messageThresholdCount: Int = 20

    /// Time window for message threshold (default: 10 minutes)
    var messageThresholdWindowSeconds: Int = 600

    /// Debounce window to prevent analysis spam (default: 5 minutes)
    var debounceWindowSeconds: Int = 300

    // MARK: - State

    /// Last message timestamp per conversation
    private var lastMessageTime: [String: Date] = [:]

    /// Message timestamps for threshold detection (sliding window)
    private var messageTimestamps: [String: [Date]] = [:]

    /// Pending analysis triggers (cancelled when new message arrives)
    private var pendingTriggers: [String: Task<Void, Never>] = [:]

    /// Last analysis timestamp per conversation (for debouncing)
    private var lastAnalysisTime: [String: Date] = [:]

    /// Currently active conversation ID (user is viewing)
    private var activeConversationId: String?

    // MARK: - Dependencies

    private let repository: NotificationAnalysisRepositoryProtocol

    // MARK: - Initialization

    init(repository: NotificationAnalysisRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Public Methods

    /// Called when a new message arrives in a conversation
    ///
    /// - Parameters:
    ///   - conversationId: The conversation that received a message
    ///   - messageId: Optional message ID for tracking
    func onNewMessage(conversationId: String, messageId: String? = nil) {
        let now = Date()

        // Update last message time
        lastMessageTime[conversationId] = now

        // Track message in sliding window
        var timestamps = messageTimestamps[conversationId] ?? []
        timestamps.append(now)

        // Remove old timestamps outside window
        let windowStart = now.addingTimeInterval(-Double(messageThresholdWindowSeconds))
        timestamps = timestamps.filter { $0 >= windowStart }
        messageTimestamps[conversationId] = timestamps

        // Cancel existing pending trigger
        pendingTriggers[conversationId]?.cancel()

        // Check if threshold exceeded
        if timestamps.count >= messageThresholdCount {
            print("📊 [ActivityMonitor] Conversation \(conversationId) exceeded message threshold (\(timestamps.count) messages)")
            // Will trigger analysis when conversation pauses
        }

        // Schedule pause detection trigger
        schedulePauseTrigger(for: conversationId)
    }

    /// Set the currently active conversation (user is viewing)
    ///
    /// - Parameter conversationId: The conversation being viewed, or nil if none
    func setActiveConversation(_ conversationId: String?) {
        self.activeConversationId = conversationId

        // Cancel pending trigger for active conversation
        if let conversationId = conversationId {
            pendingTriggers[conversationId]?.cancel()
            print("🚫 [ActivityMonitor] Cancelled trigger for active conversation: \(conversationId)")
        }
    }

    /// Reset monitoring state for a conversation
    ///
    /// - Parameter conversationId: The conversation to reset
    func resetConversation(_ conversationId: String) {
        lastMessageTime.removeValue(forKey: conversationId)
        messageTimestamps.removeValue(forKey: conversationId)
        pendingTriggers[conversationId]?.cancel()
        pendingTriggers.removeValue(forKey: conversationId)
        lastAnalysisTime.removeValue(forKey: conversationId)
    }

    /// Get current conversation state
    ///
    /// - Parameter conversationId: The conversation to check
    /// - Returns: Current state of the conversation
    func getConversationState(_ conversationId: String) -> ConversationState {
        guard let lastMessage = lastMessageTime[conversationId] else {
            return .paused
        }

        let timeSinceLastMessage = Date().timeIntervalSince(lastMessage)

        if timeSinceLastMessage < Double(pauseThresholdSeconds) {
            let messageCount = messageTimestamps[conversationId]?.count ?? 0
            if messageCount >= messageThresholdCount {
                return .thresholdExceeded
            }
            return .active
        } else {
            return .paused
        }
    }

    // MARK: - Private Methods

    /// Schedule a trigger to analyze conversation after pause threshold
    ///
    /// - Parameter conversationId: The conversation to monitor
    private func schedulePauseTrigger(for conversationId: String) {
        let task = Task {
            // Wait for pause threshold
            try? await Task.sleep(nanoseconds: UInt64(pauseThresholdSeconds) * 1_000_000_000)

            // Check if still paused (not cancelled by new message)
            guard !Task.isCancelled else {
                print("🔄 [ActivityMonitor] Pause trigger cancelled for \(conversationId)")
                return
            }

            guard let lastMessage = lastMessageTime[conversationId] else {
                return
            }

            let timeSinceLastMessage = Date().timeIntervalSince(lastMessage)

            // Verify conversation still paused
            guard timeSinceLastMessage >= Double(pauseThresholdSeconds) else {
                return
            }

            // Trigger analysis
            await triggerAnalysis(for: conversationId)
        }

        pendingTriggers[conversationId] = task
    }

    /// Trigger AI notification analysis for a conversation
    ///
    /// - Parameter conversationId: The conversation to analyze
    private func triggerAnalysis(for conversationId: String) async {
        // Check if should trigger
        guard shouldTriggerAnalysis(for: conversationId) else {
            return
        }

        print("🔍 [ActivityMonitor] Triggering analysis for conversation: \(conversationId)")

        // Record analysis time
        lastAnalysisTime[conversationId] = Date()

        // TODO: Get current user ID from auth state
        let userId = "current-user-id"  // Placeholder - will be injected

        do {
            let decision = try await repository.analyzeConversationForNotification(
                conversationId: conversationId,
                userId: userId
            )

            print("✅ [ActivityMonitor] Analysis complete:")
            print("   shouldNotify: \(decision.shouldNotify)")
            print("   priority: \(decision.priority)")

            // TODO: Story 6.6 - Trigger actual push notification if shouldNotify == true

        } catch {
            print("❌ [ActivityMonitor] Analysis failed: \(error.localizedDescription)")
        }
    }

    /// Check if analysis should be triggered for a conversation
    ///
    /// - Parameter conversationId: The conversation to check
    /// - Returns: True if analysis should proceed
    private func shouldTriggerAnalysis(for conversationId: String) -> Bool {
        // Don't analyze if user is viewing this conversation
        if activeConversationId == conversationId {
            print("🚫 [ActivityMonitor] Skipping analysis - user viewing conversation")
            return false
        }

        // Check debouncing (max once per debounce window)
        if let lastAnalysis = lastAnalysisTime[conversationId] {
            let timeSinceLastAnalysis = Date().timeIntervalSince(lastAnalysis)
            if timeSinceLastAnalysis < Double(debounceWindowSeconds) {
                print("⏱️  [ActivityMonitor] Skipping analysis - debounce window (\(Int(timeSinceLastAnalysis))s < \(debounceWindowSeconds)s)")
                return false
            }
        }

        return true
    }
}
