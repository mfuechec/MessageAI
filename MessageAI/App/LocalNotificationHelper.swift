//
//  LocalNotificationHelper.swift
//  MessageAI
//
//  Helper for testing push notifications using local notifications
//  Local notifications work in simulator (unlike real APNs push)
//

import Foundation
import UserNotifications

/// Helper class for scheduling local notifications to test notification handling
///
/// Usage:
/// ```swift
/// // Test foreground notification
/// await LocalNotificationHelper.sendTestNotification(
///     conversationId: "conv-123",
///     senderName: "Alice",
///     messageText: "Hey! Are you free today?",
///     delay: 5.0
/// )
/// ```
@MainActor
class LocalNotificationHelper {
    
    /// Schedules a local notification to test notification handling
    ///
    /// - Parameters:
    ///   - conversationId: The conversation ID for deep linking
    ///   - senderName: Display name of the sender
    ///   - messageText: The message body
    ///   - delay: Delay in seconds before notification appears (default: 5)
    static func sendTestNotification(
        conversationId: String,
        senderName: String,
        messageText: String,
        delay: TimeInterval = 5.0
    ) async {
        let center = UNUserNotificationCenter.current()
        
        // Request permissions if needed
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            guard granted else {
                print("⚠️ Notification permission denied")
                return
            }
        } catch {
            print("❌ Failed to request notification permission: \(error)")
            return
        }
        
        // Create notification content (mimics FCM payload)
        let content = UNMutableNotificationContent()
        content.title = senderName
        content.body = messageText
        content.sound = .default
        content.badge = 1
        
        // Add userInfo for deep linking (same format as FCM)
        content.userInfo = [
            "conversationId": conversationId,
            "messageId": "test-msg-\(UUID().uuidString)",
            "senderId": "test-sender"
        ]
        
        // Schedule notification
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        
        do {
            try await center.add(request)
            print("✅ Local notification scheduled:")
            print("   Title: \(senderName)")
            print("   Body: \(messageText)")
            print("   Conversation ID: \(conversationId)")
            print("   Delay: \(delay)s")
        } catch {
            print("❌ Failed to schedule notification: \(error)")
        }
    }
    
    /// Schedules multiple test notifications with staggered delays
    ///
    /// Useful for testing multiple conversations with unread messages
    static func sendMultipleTestNotifications(count: Int = 3) async {
        let testData = [
            (conversationId: "conv-1", sender: "Alice", message: "Hey! How are you?"),
            (conversationId: "conv-2", sender: "Bob", message: "Meeting at 3pm?"),
            (conversationId: "conv-3", sender: "Charlie", message: "Did you see my email?"),
            (conversationId: "conv-4", sender: "Diana", message: "Thanks for your help!"),
            (conversationId: "conv-5", sender: "Eve", message: "Lunch tomorrow?")
        ]
        
        for i in 0..<min(count, testData.count) {
            let data = testData[i]
            await sendTestNotification(
                conversationId: data.conversationId,
                senderName: data.sender,
                messageText: data.message,
                delay: Double(i * 5 + 5) // Stagger by 5 seconds
            )
        }
        
        print("✅ Scheduled \(min(count, testData.count)) test notifications")
    }
    
    /// Clears all pending and delivered notifications
    static func clearAllNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
        print("✅ Cleared all notifications")
    }
    
    /// Shows pending notifications count
    static func showPendingNotifications() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        print("📊 Pending notifications: \(pending.count)")
        for request in pending {
            print("   - \(request.content.title): \(request.content.body)")
        }
    }
}

