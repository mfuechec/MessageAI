import Foundation
import SwiftUI
import Combine

/// Centralized app-level state (replaces static variables in ViewModels)
/// - Thread-safe: All access must be on MainActor
/// - Lifecycle: State persists across views but clears on sign-out
@MainActor
class AppState: ObservableObject {
    static let shared = AppState()

    // Currently viewing conversation (for notification suppression)
    @Published var currentlyViewingConversationId: String?

    private init() {}

    /// Clear all state (call on sign-out)
    func clearState() {
        currentlyViewingConversationId = nil
        print("🧹 AppState cleared")
    }
}
