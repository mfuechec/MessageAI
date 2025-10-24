import Foundation
import SwiftUI
import Combine

/// Deep link types for navigation
enum DeepLink {
    case conversation(conversationId: String, messageId: String?)
}

/// Story 6.6: Deep Link Handler for Smart Notifications
///
/// Handles notification taps and navigates to conversations with message highlighting
class DeepLinkHandler: ObservableObject {

    /// Published deep link that views can observe
    @Published var activeDeepLink: DeepLink?

    /// Singleton instance
    static let shared = DeepLinkHandler()

    private init() {
        setupNotificationObserver()
    }

    // MARK: - Notification Observer

    /// Setup observer for OpenConversation notifications from AppDelegate
    private func setupNotificationObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenConversation(_:)),
            name: NSNotification.Name("OpenConversation"),
            object: nil
        )
    }

    /// Handle notification tap from AppDelegate
    @objc private func handleOpenConversation(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let conversationId = userInfo["conversationId"] as? String else {
            print("❌ [DeepLinkHandler] Invalid notification userInfo")
            return
        }

        let messageId = userInfo["messageId"] as? String

        print("📲 [DeepLinkHandler] Opening conversation: \(conversationId), message: \(messageId ?? "none")")

        // Publish deep link on main thread
        DispatchQueue.main.async {
            self.activeDeepLink = .conversation(conversationId: conversationId, messageId: messageId)
        }
    }

    // MARK: - Public Methods

    /// Open a conversation programmatically
    func openConversation(conversationId: String, messageId: String? = nil) {
        activeDeepLink = .conversation(conversationId: conversationId, messageId: messageId)
    }

    /// Clear active deep link (called after navigation completes)
    func clearDeepLink() {
        activeDeepLink = nil
    }
}
