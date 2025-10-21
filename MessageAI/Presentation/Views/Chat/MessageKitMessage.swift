import Foundation
import MessageKit

/// MessageKit-compatible message structure for displaying messages in MessagesCollectionView
struct MessageKitMessage: MessageType {
    var sender: SenderType
    var messageId: String
    var sentDate: Date
    var kind: MessageKind
    var status: MessageStatus
    var isDeleted: Bool
    
    init(message: Message, displayName: String) {
        self.sender = MessageKitSender(senderId: message.senderId, displayName: displayName)
        self.messageId = message.id
        self.sentDate = message.timestamp
        self.status = message.status
        self.isDeleted = message.isDeleted
        
        // Show "[Message deleted]" placeholder for deleted messages
        if message.isDeleted {
            self.kind = .text("[Message deleted]")
        } else {
            self.kind = .text(message.text)
        }
    }
}

/// Sender conforming to MessageKit's SenderType protocol
struct MessageKitSender: SenderType {
    var senderId: String
    var displayName: String
}

