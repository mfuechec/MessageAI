//
//  NotificationSimulator.swift
//  MessageAI
//
//  Simulates push notifications in simulator by triggering local notifications
//  when real messages arrive via Firestore listeners
//
//  Only active in DEBUG builds and simulator
//

import Foundation
import Combine
import UserNotifications

#if DEBUG
/// Simulates push notifications in the simulator
///
/// This class watches for new messages in Firestore and triggers local notifications
/// to simulate the push notification experience. This allows testing the full flow:
/// User A sends message → User B gets notification (even in simulator!)
///
/// **How it works:**
/// 1. Listens to all conversations for the current user
/// 2. Detects when new messages arrive
/// 3. Triggers local notification if:
///    - Message is from another user (not self)
///    - User is NOT viewing that conversation
///    - App is in foreground or background
///
/// **Usage:**
/// ```swift
/// let simulator = NotificationSimulator(
///     conversationRepository: conversationRepository,
///     messageRepository: messageRepository,
///     userRepository: userRepository,
///     currentUserId: userId
/// )
/// simulator.start()
/// ```
@MainActor
class NotificationSimulator: ObservableObject {
    
    private let conversationRepository: ConversationRepositoryProtocol
    private let messageRepository: MessageRepositoryProtocol
    private let userRepository: UserRepositoryProtocol
    private let currentUserId: String
    
    private var cancellables = Set<AnyCancellable>()
    private var lastMessageIds: [String: String] = [:] // conversationId -> lastMessageId
    
    private var isEnabled = true // Can be toggled
    
    init(
        conversationRepository: ConversationRepositoryProtocol,
        messageRepository: MessageRepositoryProtocol,
        userRepository: UserRepositoryProtocol,
        currentUserId: String
    ) {
        self.conversationRepository = conversationRepository
        self.messageRepository = messageRepository
        self.userRepository = userRepository
        self.currentUserId = currentUserId
    }
    
    /// Starts watching for new messages
    func start() {
        guard isEnabled else { return }
        
        print("🔔 [NotificationSimulator] Started (DEBUG mode)")
        print("   Will trigger local notifications for incoming messages")
        
        // Watch all conversations
        conversationRepository.observeConversations(userId: currentUserId)
            .sink { [weak self] conversations in
                guard let self = self else { return }
                
                // For each conversation, watch for new messages
                for conversation in conversations {
                    self.watchConversation(conversation)
                }
            }
            .store(in: &cancellables)
    }
    
    /// Stops the simulator
    func stop() {
        cancellables.removeAll()
        print("🔔 [NotificationSimulator] Stopped")
    }
    
    /// Watches a specific conversation for new messages
    private func watchConversation(_ conversation: Conversation) {
        messageRepository.observeMessages(conversationId: conversation.id)
            .sink { [weak self] messages in
                guard let self = self else { return }
                
                // Get the most recent message
                guard let latestMessage = messages.max(by: { $0.timestamp < $1.timestamp }) else {
                    return
                }
                
                // Check if this is a NEW message (not seen before)
                let previousMessageId = self.lastMessageIds[conversation.id]
                let isNewMessage = previousMessageId != latestMessage.id
                
                // Update tracking
                self.lastMessageIds[conversation.id] = latestMessage.id
                
                // Only trigger notification for new messages from other users
                guard isNewMessage,
                      latestMessage.senderId != self.currentUserId else {
                    return
                }
                
                // Check if user is viewing this conversation
                let isViewingConversation = ChatViewModel.currentlyViewingConversationId == conversation.id
                if isViewingConversation {
                    print("🔔 [NotificationSimulator] Skipping notification (user viewing conversation)")
                    return
                }
                
                // Trigger local notification
                print("🔔 [NotificationSimulator] New message detected! Triggering notification...")
                Task {
                    await self.triggerNotification(
                        for: latestMessage,
                        in: conversation
                    )
                }
            }
            .store(in: &cancellables)
    }
    
    /// Triggers a local notification for a message
    private func triggerNotification(for message: Message, in conversation: Conversation) async {
        // Fetch sender info
        guard let sender = try? await userRepository.getUser(id: message.senderId) else {
            print("⚠️ [NotificationSimulator] Could not fetch sender info")
            return
        }
        
        let center = UNUserNotificationCenter.current()
        
        // Create notification content
        let content = UNMutableNotificationContent()
        
        // Format title based on conversation type
        if conversation.isGroup {
            let groupName = conversation.groupName ?? "Group Chat"
            content.title = "\(sender.displayName) in \(groupName)"
        } else {
            content.title = sender.displayName
        }
        
        // Message preview
        content.body = message.isDeleted ? "[Message deleted]" : message.text
        content.sound = .default
        
        // Add conversation info for deep linking
        content.userInfo = [
            "conversationId": conversation.id,
            "messageId": message.id,
            "senderId": message.senderId,
            "isSimulated": true
        ]
        
        // Trigger immediately
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // nil = trigger immediately
        )
        
        do {
            try await center.add(request)
            print("✅ [NotificationSimulator] Notification triggered:")
            print("   From: \(sender.displayName)")
            print("   Message: \(message.text)")
            print("   Conversation: \(conversation.id)")
        } catch {
            print("❌ [NotificationSimulator] Failed to trigger notification: \(error)")
        }
    }
}
#endif

