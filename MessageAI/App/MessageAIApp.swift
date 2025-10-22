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
import UserNotifications

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

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        
        // Set up notification handling
        UNUserNotificationCenter.current().delegate = self
        
        // Set up FCM token handling
        Messaging.messaging().delegate = self
        
        // Register for remote notifications (triggers APNs token request)
        application.registerForRemoteNotifications()
        
        print("✅ AppDelegate initialized - Push notification setup complete")
        
        return true
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
    
    // MARK: - Notification Tap Handling
    
    /// Called when user taps notification (foreground or background)
    ///
    /// Extracts conversationId from notification payload and posts
    /// NotificationCenter event for deep linking to conversation.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        print("🔔 Notification tapped:")
        print("   User Info: \(userInfo)")
        
        // Deep link to conversation
        if let conversationId = userInfo["conversationId"] as? String {
            print("   📲 Opening conversation: \(conversationId)")
            
            // Post notification for ConversationsListView to handle
            NotificationCenter.default.post(
                name: NSNotification.Name("OpenConversation"),
                object: nil,
                userInfo: ["conversationId": conversationId]
            )
        }
        
        completionHandler()
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

        // Clean up expired temporary images from previous sessions (Story 2.7)
        ImageCacheManager.cleanupExpiredImages()

        // Story 2.10 QA Fix: Inject UserRepository into AppDelegate
        appDelegate.userRepository = DIContainer.shared.userRepository
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
