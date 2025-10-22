import Foundation
import MessageKit
import UIKit

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
        } else if let attachment = message.attachments.first, attachment.type == .image {
            // Image message
            let mediaItem = ImageMediaItem(url: attachment.url)
            self.kind = .photo(mediaItem)
        } else {
            // Text message
            self.kind = .text(message.text)
        }
    }
}

/// MediaItem implementation for MessageKit photo messages
struct ImageMediaItem: MediaItem {
    var url: URL?
    var image: UIImage?
    var placeholderImage: UIImage
    var size: CGSize

    init(url: String) {
        self.url = URL(string: url)
        self.image = nil
        self.placeholderImage = UIImage(systemName: "photo") ?? UIImage()
        self.size = CGSize(width: 240, height: 240)  // Max display size
    }
}

/// Sender conforming to MessageKit's SenderType protocol
struct MessageKitSender: SenderType {
    var senderId: String
    var displayName: String
}

