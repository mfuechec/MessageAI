import Foundation
import MessageKit

/// MessageKit-compatible message structure for displaying messages in MessagesCollectionView
struct MessageKitMessage: MessageType {
    var sender: SenderType
    var messageId: String
    var sentDate: Date
    var kind: MessageKind
    var status: MessageStatus
    
    init(message: Message, displayName: String) {
        self.sender = MessageKitSender(senderId: message.senderId, displayName: displayName)
        self.messageId = message.id
        self.sentDate = message.timestamp
        self.kind = .text(message.text)
        self.status = message.status
    }
}

/// Sender conforming to MessageKit's SenderType protocol
struct MessageKitSender: SenderType {
    var senderId: String
    var displayName: String
}

