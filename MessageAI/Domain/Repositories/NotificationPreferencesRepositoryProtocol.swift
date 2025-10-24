import Foundation
import Combine

/// Protocol defining notification preferences data operations (Epic 6 - Story 6.4)
///
/// Manages user preferences for smart AI-powered notifications
protocol NotificationPreferencesRepositoryProtocol {
    /// Get notification preferences for a user
    /// - Parameter userId: The user ID
    /// - Returns: The user's notification preferences
    /// - Throws: RepositoryError if preferences not found or retrieval fails
    func getPreferences(userId: String) async throws -> NotificationPreferences

    /// Save or update notification preferences
    /// - Parameter preferences: The preferences to save
    /// - Throws: RepositoryError if save operation fails
    func savePreferences(_ preferences: NotificationPreferences) async throws

    /// Observe notification preferences changes in real-time
    /// - Parameter userId: The user ID to observe
    /// - Returns: Publisher emitting preference updates
    func observePreferences(userId: String) -> AnyPublisher<NotificationPreferences, Never>

    /// Check if smart notifications are enabled for a user
    /// - Parameter userId: The user ID
    /// - Returns: True if enabled, false otherwise
    func isEnabled(userId: String) async throws -> Bool

    /// Enable smart notifications (opt-in)
    /// - Parameters:
    ///   - userId: The user ID
    ///   - defaultPreferences: Optional default preferences to use
    /// - Throws: RepositoryError if enable operation fails
    func enableSmartNotifications(userId: String, defaultPreferences: NotificationPreferences?) async throws

    /// Disable smart notifications (opt-out)
    /// - Parameter userId: The user ID
    /// - Throws: RepositoryError if disable operation fails
    func disableSmartNotifications(userId: String) async throws

    /// Delete all notification preferences for a user
    /// - Parameter userId: The user ID
    /// - Throws: RepositoryError if deletion fails
    func deletePreferences(userId: String) async throws
}
