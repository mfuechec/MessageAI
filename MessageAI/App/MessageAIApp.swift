//
//  MessageAIApp.swift
//  MessageAI
//
//  Created by Mark Fuechec on 10/20/25.
//  Updated by Dev Agent (James) on 10/20/25 - Story 1.5
//

import SwiftUI
import FirebaseMessaging
import FirebaseAuth
import FirebaseFunctions
import UserNotifications
import Kingfisher

// MARK: - AppDelegate for Push Notifications

/// AppDelegate handles push notification registration and delivery
///
/// Responsibilities:
/// - Register for remote notifications via APNs
/// - Handle FCM token updates and save to Firestore
/// - Manage foreground notification presentation
/// - Handle notification taps for deep linking
/// - Suppress notifications when user is viewing the conversation
class AppDelegate: NSObject, UIApplicationDelegate, MessagingDelegate, UNUserNotificationCenterDelegate {

    // MARK: - Dependencies (Story 2.10 QA Fix - Use repository pattern)
    var userRepository: UserRepositoryProtocol?
    var messageRepository: MessageRepositoryProtocol?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {

        // Set up notification handling
        UNUserNotificationCenter.current().delegate = self

        // Set up FCM token handling
        Messaging.messaging().delegate = self

        // Setup interactive notification actions (Story 6.5 & 6.6)
        setupNotificationActions()

        // Register for remote notifications (triggers APNs token request)
        application.registerForRemoteNotifications()

        print("✅ AppDelegate initialized - Push notification setup complete")

        return true
    }

    // MARK: - Notification Actions Setup (Story 6.5 & 6.6)

    /// Setup interactive notification actions
    ///
    /// Actions include:
    /// - Helpful/Not Helpful feedback (Story 6.5)
    /// - Quick reply (Story 6.6)
    /// - Mark as read (Story 6.6)
    private func setupNotificationActions() {
        // Feedback actions (Story 6.5)
        let helpfulAction = UNNotificationAction(
            identifier: "HELPFUL_ACTION",
            title: "👍 Helpful",
            options: []
        )

        let notHelpfulAction = UNNotificationAction(
            identifier: "NOT_HELPFUL_ACTION",
            title: "👎 Not Helpful",
            options: []
        )

        // Quick reply action (Story 6.6)
        let replyAction = UNTextInputNotificationAction(
            identifier: "REPLY_ACTION",
            title: "Reply",
            options: [],
            textInputButtonTitle: "Send",
            textInputPlaceholder: "Type a message..."
        )

        // Mark as read action (Story 6.6)
        let markReadAction = UNNotificationAction(
            identifier: "MARK_READ_ACTION",
            title: "Mark Read",
            options: [.destructive]
        )

        // Create category with all actions
        let smartNotificationCategory = UNNotificationCategory(
            identifier: "SMART_NOTIFICATION_CATEGORY",
            actions: [replyAction, markReadAction, helpfulAction, notHelpfulAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        UNUserNotificationCenter.current().setNotificationCategories([smartNotificationCategory])

        print("✅ Interactive notification actions configured")
    }
    
    // MARK: - FCM Token Handling
    
    /// Called when FCM token is received or refreshed
    ///
    /// Token refresh occurs:
    /// - On first app install
    /// - On app reinstall
    /// - When user clears app data
    /// - Periodically (Firebase handles this automatically)
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else {
            print("⚠️ FCM token is nil")
            return
        }
        
        print("✅ FCM Token received: \(token)")
        
        // Save token to Firestore for current user
        Task {
            await saveFCMToken(token)
        }
    }
    
    /// Saves FCM token to Firestore user document with retry logic
    ///
    /// Story 2.10a: Implements exponential backoff retry (3 attempts: 1s, 2s, 4s)
    /// Story 2.10 QA Fix: Uses UserRepositoryProtocol instead of direct Firestore access
    /// Token is used by Cloud Functions to send push notifications
    /// to specific devices when messages arrive.
    private func saveFCMToken(_ token: String) async {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("⚠️ No authenticated user - FCM token not saved")
            return
        }

        guard let repository = userRepository else {
            print("❌ [QA FIX] UserRepository not injected - cannot save FCM token")
            return
        }

        var retryCount = 0
        let maxRetries = 3

        while retryCount < maxRetries {
            do {
                try await repository.updateFCMToken(token, userId: userId)
                print("✅ [QA FIX] FCM token saved via repository for user: \(userId)")
                return  // Success - exit retry loop

            } catch {
                retryCount += 1

                if retryCount < maxRetries {
                    // Exponential backoff: 1s, 2s, 4s
                    let delay = UInt64(pow(2.0, Double(retryCount - 1)) * 1_000_000_000)
                    try? await Task.sleep(nanoseconds: delay)
                    print("⚠️ FCM token save failed (attempt \(retryCount)/\(maxRetries)), retrying...")
                } else {
                    print("❌ Failed to save FCM token after \(maxRetries) attempts: \(error.localizedDescription)")
                    // Token will be retried on next app launch
                }
            }
        }
    }
    
    // MARK: - Foreground Notification Handling
    
    /// Called when notification arrives while app is in foreground
    ///
    /// Decides whether to show notification banner based on:
    /// - Is user currently viewing this conversation? (suppress if true)
    /// - Is notification relevant? (always show if not viewing)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        
        print("🔔 Foreground notification received:")
        print("   Title: \(notification.request.content.title)")
        print("   Body: \(notification.request.content.body)")

        // Check if user is currently viewing this conversation (using AppState)
        if let conversationId = userInfo["conversationId"] as? String {
            Task { @MainActor in
                let isViewingConversation = AppState.shared.currentlyViewingConversationId == conversationId

                if isViewingConversation {
                    // User is viewing conversation - don't show notification
                    print("   ⏭️ Suppressed (user viewing conversation)")
                    completionHandler([])
                } else {
                    // Show banner notification with sound and badge
                    print("   ✅ Showing notification banner")
                    completionHandler([.banner, .sound, .badge])
                }
            }
            return
        }
        
        // Show banner notification with sound and badge
        print("   ✅ Showing notification banner")
        completionHandler([.banner, .sound, .badge])
    }
    
    // MARK: - Notification Action Handling (Story 6.5 & 6.6)

    /// Called when user interacts with notification (tap or action button)
    ///
    /// Handles:
    /// - Notification tap (default action) → Deep link to conversation
    /// - Helpful/Not Helpful feedback buttons → Submit feedback
    /// - Quick reply → Send message directly
    /// - Mark as read → Update message read status
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let conversationId = userInfo["conversationId"] as? String ?? ""
        let messageId = userInfo["messageId"] as? String ?? ""

        print("🔔 Notification interaction:")
        print("   Action: \(response.actionIdentifier)")
        print("   ConversationId: \(conversationId)")
        print("   MessageId: \(messageId)")

        switch response.actionIdentifier {
        case "REPLY_ACTION":
            // Quick reply action (Story 6.6)
            guard let textResponse = response as? UNTextInputNotificationResponse else {
                print("❌ Invalid text input response")
                completionHandler()
                return
            }
            handleQuickReply(conversationId: conversationId, text: textResponse.userText)

        case "MARK_READ_ACTION":
            // Mark as read action (Story 6.6)
            handleMarkAsRead(conversationId: conversationId, messageId: messageId)

        case "HELPFUL_ACTION":
            // Helpful feedback (Story 6.5)
            submitFeedback(conversationId: conversationId, messageId: messageId, feedback: "helpful")

        case "NOT_HELPFUL_ACTION":
            // Not helpful feedback (Story 6.5)
            submitFeedback(conversationId: conversationId, messageId: messageId, feedback: "not_helpful")

        case UNNotificationDefaultActionIdentifier:
            // User tapped notification body - deep link to conversation
            handleDeepLink(conversationId: conversationId, messageId: messageId)

        default:
            print("⚠️ Unknown action identifier: \(response.actionIdentifier)")
        }

        completionHandler()
    }

    // MARK: - Action Handlers

    /// Handle quick reply from notification (Story 6.6)
    private func handleQuickReply(conversationId: String, text: String) {
        Task {
            guard let userId = Auth.auth().currentUser?.uid else {
                print("❌ No authenticated user for quick reply")
                return
            }

            guard let repository = messageRepository else {
                print("❌ MessageRepository not injected")
                return
            }

            do {
                let message = Message(
                    id: UUID().uuidString,
                    conversationId: conversationId,
                    senderId: userId,
                    text: text,
                    timestamp: Date(),
                    status: .sending,
                    statusUpdatedAt: Date(),
                    attachments: [],
                    editHistory: nil,
                    editCount: 0,
                    isEdited: false,
                    isDeleted: false,
                    deletedAt: nil,
                    deletedBy: nil,
                    readBy: [userId],
                    readCount: 1,
                    isPriority: false,
                    priorityReason: nil,
                    schemaVersion: 1
                )

                try await repository.sendMessage(message)
                print("✅ Quick reply sent successfully")

                // Show confirmation notification
                await showNotification(title: "Message Sent", body: "Your reply was sent successfully")

            } catch {
                print("❌ Failed to send quick reply: \(error)")

                // Show error notification and open app
                await showNotification(title: "Send Failed", body: "Tap to open app and try again")
                handleDeepLink(conversationId: conversationId, messageId: nil)
            }
        }
    }

    /// Handle mark as read action (Story 6.6)
    private func handleMarkAsRead(conversationId: String, messageId: String) {
        Task {
            guard let userId = Auth.auth().currentUser?.uid else {
                print("❌ No authenticated user for mark as read")
                return
            }

            guard let repository = messageRepository else {
                print("❌ MessageRepository not injected")
                return
            }

            do {
                try await repository.markMessagesAsRead(messageIds: [messageId], userId: userId)
                print("✅ Message marked as read")

                // Remove notification from notification center
                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [messageId])

            } catch {
                print("❌ Failed to mark as read: \(error)")
            }
        }
    }

    /// Submit feedback for notification decision (Story 6.5)
    private func submitFeedback(conversationId: String, messageId: String, feedback: String) {
        Task {
            guard Auth.auth().currentUser != nil else {
                print("❌ No authenticated user for feedback")
                return
            }

            // Call Cloud Function: submitNotificationFeedback
            // Note: Cloud Function gets userId from auth context
            let functions = FirebaseFunctions.Functions.functions()
            let data: [String: Any] = [
                "conversationId": conversationId,
                "messageId": messageId,
                "feedback": feedback
            ]

            do {
                _ = try await functions.httpsCallable("submitNotificationFeedback").call(data)
                print("✅ Feedback submitted: \(feedback)")
            } catch {
                print("❌ Failed to submit feedback: \(error)")
            }
        }
    }

    /// Handle deep link to conversation (Story 6.6)
    private func handleDeepLink(conversationId: String, messageId: String?) {
        print("📲 Deep linking to conversation: \(conversationId), message: \(messageId ?? "none")")

        // Post notification for DeepLinkHandler to handle
        NotificationCenter.default.post(
            name: NSNotification.Name("OpenConversation"),
            object: nil,
            userInfo: [
                "conversationId": conversationId,
                "messageId": messageId ?? ""
            ]
        )
    }

    /// Show local notification
    private func showNotification(title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        try? await UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - APNs Token Handling (for debugging)
    
    /// Called when APNs token is successfully registered
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // Forward APNs token to Firebase Messaging
        Messaging.messaging().apnsToken = deviceToken
        
        let tokenParts = deviceToken.map { String(format: "%02.2hhx", $0) }
        let token = tokenParts.joined()
        print("✅ APNs device token: \(token)")
    }
    
    /// Called when APNs token registration fails
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("❌ Failed to register for remote notifications: \(error.localizedDescription)")
    }
}

// MARK: - Main App

@main
struct MessageAIApp: App {

    // AppDelegate for push notification handling
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    /// Authentication ViewModel for managing user sign-in/sign-up state
    /// StateObject ensures ViewModel persists across app lifecycle
    @StateObject private var authViewModel = DIContainer.shared.makeAuthViewModel()

    /// Initialize Firebase on app launch
    /// Explicitly call configure() to set up Firebase with environment-specific settings
    init() {
        FirebaseService.shared.configure()

        // Configure Kingfisher cache limits for optimal image caching (Phase 2 - Issue #2 Fix)
        configureImageCache()

        // Clean up expired temporary images from previous sessions (Story 2.7)
        ImageCacheManager.cleanupExpiredImages()

        // Story 2.10 QA Fix: Inject UserRepository into AppDelegate
        appDelegate.userRepository = DIContainer.shared.userRepository

        // Story 6.5 & 6.6: Inject MessageRepository for notification actions
        appDelegate.messageRepository = DIContainer.shared.messageRepository
    }

    /// Configure Kingfisher image cache limits
    ///
    /// Optimized for user profile images with persistent disk + memory caching.
    /// Prevents wrong user image flashes during rapid scrolling or view recycling.
    private func configureImageCache() {
        let cache = KingfisherManager.shared.cache

        // Memory cache: 50 MB, max 100 images
        cache.memoryStorage.config.totalCostLimit = 50 * 1024 * 1024  // 50 MB
        cache.memoryStorage.config.countLimit = 100  // Max 100 images in memory
        cache.memoryStorage.config.expiration = .days(7)  // Keep in memory for 7 days

        // Disk cache: 200 MB, expires after 30 days
        cache.diskStorage.config.sizeLimit = 200 * 1024 * 1024  // 200 MB
        cache.diskStorage.config.expiration = .days(30)  // Auto-cleanup after 30 days

        print("✅ Kingfisher cache configured (Memory: 50MB/100 images, Disk: 200MB/30 days)")
    }
    
    var body: some Scene {
        WindowGroup {
            // Conditional navigation based on authentication state
            // Firebase Auth automatically restores authenticated session on app launch
            if let currentUser = authViewModel.currentUser {
                // Check if user needs profile setup
                if needsProfileSetup(currentUser) {
                    // Create ProfileSetupViewModel with authViewModel for navigation updates
                    let profileViewModel = ProfileSetupViewModel(
                        userRepository: DIContainer.shared.userRepository,
                        authRepository: DIContainer.shared.authRepository,
                        storageRepository: DIContainer.shared.storageRepository,
                        currentUser: currentUser,
                        authViewModel: authViewModel
                    )
                    ProfileSetupView(viewModel: profileViewModel, authViewModel: authViewModel)
                } else {
                    // Show Conversations List after profile setup complete
                    ConversationsListView(
                        viewModel: DIContainer.shared.makeConversationsListViewModel(currentUserId: currentUser.id)
                    )
                    .environmentObject(authViewModel)
                    .onAppear {
                        // Request notification permissions after authentication and profile setup
                        Task {
                            await authViewModel.requestNotificationPermissions()
                        }
                    }
                }
            } else {
                AuthView(viewModel: authViewModel)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Determines if user needs to complete profile setup
    /// - Parameter user: The authenticated user
    /// - Returns: True if profile setup is needed, false otherwise
    ///
    /// Note: Uses UserDefaults for MVP. Production should use a `hasCompletedProfileSetup: Bool`
    /// flag in the User entity stored in Firestore.
    private func needsProfileSetup(_ user: User) -> Bool {
        // Check if user has completed profile setup (persisted in UserDefaults)
        let hasCompleted = UserDefaults.standard.bool(forKey: "hasCompletedProfileSetup_\(user.id)")
        return !hasCompleted
    }
}
