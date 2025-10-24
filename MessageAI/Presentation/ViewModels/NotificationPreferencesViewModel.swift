//
//  NotificationPreferencesViewModel.swift
//  MessageAI
//
//  Created by Claude Code on 10/23/25.
//  Epic 6 - Story 6.4: User Preferences & Opt-In Controls
//

import Foundation
import Combine

/// AI status for notification preferences
enum AIStatus {
    case active
    case usingFallback
    case unavailable
}

/// ViewModel for managing smart notification preferences (Epic 6 - Story 6.4)
///
/// Handles:
/// - Loading and saving notification preferences
/// - Real-time preference updates via Firestore listener
/// - Opt-in/opt-out flow
/// - Testing notification analysis
/// - AI service health status
@MainActor
class NotificationPreferencesViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Current notification preferences
    @Published var preferences: NotificationPreferences

    /// Loading state indicator
    @Published var isLoading = false

    /// Saving state indicator
    @Published var isSaving = false

    /// Error message if operation failed
    @Published var errorMessage: String?

    /// AI service health status
    @Published var aiStatus: AIStatus = .active

    /// Test notification decision result
    @Published var testDecision: NotificationDecision?

    /// Whether test is in progress
    @Published var isTestingNotification = false

    // MARK: - Dependencies

    private let repository: NotificationPreferencesRepositoryProtocol
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    /// Initialize NotificationPreferencesViewModel
    ///
    /// - Parameters:
    ///   - repository: Repository for preferences data operations
    ///   - userId: User ID for preferences
    init(repository: NotificationPreferencesRepositoryProtocol, userId: String) {
        self.repository = repository

        // Initialize with default preferences for this user
        self.preferences = NotificationPreferences(
            userId: userId,
            enabled: true,
            pauseThresholdSeconds: 120,
            activeConversationThreshold: 20,
            quietHoursStart: "22:00",
            quietHoursEnd: "08:00",
            timezone: TimeZone.current.identifier,
            priorityKeywords: ["urgent", "ASAP", "production down", "blocker", "help"],
            maxAnalysesPerHour: 10,
            fallbackStrategy: .simpleRules,
            createdAt: Date(),
            updatedAt: Date()
        )

        // Set up real-time listener for preference changes
        setupRealtimeListener()
    }

    // MARK: - Public Methods

    /// Load preferences from repository
    func loadPreferences() async {
        isLoading = true
        errorMessage = nil

        do {
            preferences = try await repository.getPreferences(userId: preferences.userId)
            print("✅ Preferences loaded for user: \(preferences.userId)")
        } catch {
            // If preferences don't exist, user hasn't opted in yet
            print("ℹ️ No preferences found, using defaults")
            errorMessage = nil  // Not an error if preferences don't exist
        }

        isLoading = false
    }

    /// Save current preferences to repository
    func savePreferences() async {
        isSaving = true
        errorMessage = nil

        // Update timestamp
        preferences.updatedAt = Date()

        do {
            try await repository.savePreferences(preferences)
            print("✅ Preferences saved for user: \(preferences.userId)")
        } catch {
            errorMessage = "Failed to save preferences: \(error.localizedDescription)"
            print("❌ Save preferences failed: \(error)")
        }

        isSaving = false
    }

    /// Enable smart notifications (opt-in)
    func enableSmartNotifications() async {
        isSaving = true
        errorMessage = nil

        do {
            try await repository.enableSmartNotifications(
                userId: preferences.userId,
                defaultPreferences: preferences
            )
            preferences.enabled = true
            print("✅ Smart notifications enabled")
        } catch {
            errorMessage = "Failed to enable smart notifications: \(error.localizedDescription)"
            print("❌ Enable failed: \(error)")
        }

        isSaving = false
    }

    /// Disable smart notifications (opt-out)
    func disableSmartNotifications() async {
        isSaving = true
        errorMessage = nil

        do {
            try await repository.disableSmartNotifications(userId: preferences.userId)
            preferences.enabled = false
            print("✅ Smart notifications disabled")
        } catch {
            errorMessage = "Failed to disable smart notifications: \(error.localizedDescription)"
            print("❌ Disable failed: \(error)")
        }

        isSaving = false
    }

    /// Test notification analysis with recent conversation
    ///
    /// Note: This requires the analyzeForNotification Cloud Function (Story 6.3)
    /// For Story 6.4, this is a placeholder that will be fully implemented in Story 6.3
    func testNotification() async -> NotificationDecision? {
        isTestingNotification = true
        errorMessage = nil

        // TODO: Story 6.3 - Implement actual Cloud Function call
        // For now, return a mock decision

        try? await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second delay

        let mockDecision = NotificationDecision(
            shouldNotify: true,
            reason: "Contains priority keyword 'urgent'",
            notificationText: "John: urgent - need help with production issue",
            priority: .high,
            timestamp: Date()
        )

        testDecision = mockDecision
        isTestingNotification = false

        return mockDecision
    }

    /// Add a priority keyword
    func addPriorityKeyword(_ keyword: String) async {
        guard !keyword.isEmpty,
              !preferences.priorityKeywords.contains(keyword) else {
            return
        }

        preferences.priorityKeywords.append(keyword)
        await savePreferences()
    }

    /// Remove a priority keyword
    func removePriorityKeyword(at index: Int) async {
        guard index < preferences.priorityKeywords.count else { return }

        preferences.priorityKeywords.remove(at: index)
        await savePreferences()
    }

    /// Update pause threshold
    func updatePauseThreshold(_ seconds: Int) async {
        preferences.pauseThresholdSeconds = seconds
        await savePreferences()
    }

    /// Update active conversation threshold
    func updateActiveConversationThreshold(_ messages: Int) async {
        preferences.activeConversationThreshold = messages
        await savePreferences()
    }

    /// Update quiet hours
    func updateQuietHours(start: String, end: String) async {
        preferences.quietHoursStart = start
        preferences.quietHoursEnd = end
        await savePreferences()
    }

    /// Update fallback strategy
    func updateFallbackStrategy(_ strategy: FallbackStrategy) async {
        preferences.fallbackStrategy = strategy
        await savePreferences()
    }

    /// Check AI service health status
    /// TODO: Story 6.3 - Implement actual health check
    func checkAIStatus() async {
        // Placeholder - will be implemented in Story 6.3
        aiStatus = .active
    }

    // MARK: - Private Methods

    /// Set up real-time Firestore listener for preference changes
    private func setupRealtimeListener() {
        repository.observePreferences(userId: preferences.userId)
            .sink { [weak self] updatedPreferences in
                self?.preferences = updatedPreferences
                print("🔄 Preferences updated from Firestore")
            }
            .store(in: &cancellables)
    }
}
