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
import FirebaseFirestore
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
    
    /// Saves FCM token to Firestore user document
    ///
    /// Token is used by Cloud Functions to send push notifications
    /// to specific devices when messages arrive.
    private func saveFCMToken(_ token: String) async {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("⚠️ No authenticated user - FCM token not saved")
            return
        }
        
        let db = Firestore.firestore()
        
        do {
            try await db.collection("users").document(userId).updateData([
                "fcmToken": token,
                "fcmTokenUpdatedAt": FieldValue.serverTimestamp()
            ])
            print("✅ FCM token saved to Firestore for user: \(userId)")
        } catch {
            print("❌ Failed to save FCM token: \(error.localizedDescription)")
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
        
        // Check if user is currently viewing this conversation
        if let conversationId = userInfo["conversationId"] as? String {
            let isViewingConversation = ChatViewModel.currentlyViewingConversationId == conversationId
            
            if isViewingConversation {
                // User is viewing conversation - don't show notification
                print("   ⏭️ Suppressed (user viewing conversation)")
                completionHandler([])
                return
            }
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
