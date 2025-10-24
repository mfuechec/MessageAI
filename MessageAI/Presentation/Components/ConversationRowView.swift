import SwiftUI
import Kingfisher

/// Row view component for displaying conversation summary
struct ConversationRowView: View {
    let conversation: Conversation
    let displayName: String
    let unreadCount: Int
    let formattedTimestamp: String
    let participants: [User]  // For group avatar display
    let currentUserId: String  // For read receipt display
    
    /// Accessibility text that includes unread and priority status
    private var accessibilityText: String {
        var text = "\(displayName), \(conversation.lastMessage ?? "No messages"), \(formattedTimestamp)"

        if conversation.hasUnreadPriority {
            text += ", \(conversation.priorityCount) urgent"
        }

        if unreadCount > 0 {
            text += ", \(unreadCount) unread"
        }

        return text
    }

    var body: some View {
        HStack(spacing: 12) {
            // Profile image / avatar
            profileImage

            // Conversation details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(displayName)
                        .font(.headline)
                        .lineLimit(1)

                    Spacer()

                    Text(formattedTimestamp)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack(alignment: .center, spacing: 4) {
                    // Read receipt indicator (for own messages only)
                    if let senderId = conversation.lastMessageSenderId,
                       senderId == currentUserId {
                        readReceiptIndicator
                    }

                    Text(conversation.lastMessage ?? "No messages yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)

                    Spacer()

                    // Priority indicator badge (urgent messages)
                    if conversation.hasUnreadPriority {
                        priorityBadge
                    }

                    // Unread count badge
                    if unreadCount > 0 {
                        unreadBadge
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }
    
    @ViewBuilder
    private var profileImage: some View {
        if conversation.isGroup {
            // Group avatar: multi-participant display
            GroupAvatarView(users: participants, size: 56)
        } else {
            // Single user avatar with profile image and online indicator
            ZStack(alignment: .bottomTrailing) {
                // Avatar (profile image or initials fallback)
                if !participants.isEmpty, 
                   let user = participants.first {
                    if let photoURL = user.profileImageURL,
                       !photoURL.isEmpty,
                       let url = URL(string: photoURL) {
                        // Story 2.11 - AC #4: Optimized image loading with Kingfisher
                        // Uses downsampling to 56x56 for efficient memory usage (reduces ~95% memory vs full image)
                        let _ = print("🖼️ Loading optimized profile image for \(user.displayName)")
                        KFImage(url)
                            .placeholder {
                                initialsCircle
                            }
                            .resizable()
                            .downsampling(size: CGSize(width: 56, height: 56))  // AC #4: Downsample to display size
                            .cacheOriginalImage()
                            .scaledToFill()
                            .frame(width: 56, height: 56)
                            .clipShape(Circle())
                    } else {
                        let _ = print("ℹ️ No profile image for \(user.displayName), showing initials")
                        initialsCircle
                    }
                } else {
                    initialsCircle
                }
                
                // Presence indicator (3 states)
                // Green = online, Yellow = recently offline (<15 min), Gray = offline
                if !participants.isEmpty, let user = participants.first {
                    let status = user.presenceStatus
                    let rgb = status.color
                    
                    Circle()
                        .fill(Color(red: rgb.red, green: rgb.green, blue: rgb.blue))
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle()
                                .stroke(Color(.systemBackground), lineWidth: 2)
                        )
                        .offset(x: -4, y: -4)
                }
            }
        }
    }
    
    private var initialsCircle: some View {
        Circle()
            .fill(Color.accentColor.opacity(0.2))
            .frame(width: 56, height: 56)
            .overlay(
                Text(displayName.prefix(2).uppercased())
                    .font(.title3)
                    .foregroundColor(.accentColor)
            )
    }
    
    private var unreadBadge: some View {
        Text("\(unreadCount)")
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(conversation.hasUnreadPriority ? Color.red : Color.accentColor)
            .clipShape(Capsule())
    }

    /// Priority indicator badge for urgent messages
    private var priorityBadge: some View {
        HStack(spacing: 2) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.caption)
            if conversation.priorityCount > 0 {
                Text("\(conversation.priorityCount)")
                    .font(.caption2)
                    .fontWeight(.bold)
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Color.orange)
        .clipShape(Capsule())
    }

    /// Read receipt indicator for last message (shows for sender only)
    @ViewBuilder
    private var readReceiptIndicator: some View {
        let readByAll: Bool = {
            // Check if all other participants (excluding sender) have read the message
            guard let readBy = conversation.lastMessageReadBy else {
                return false
            }

            // Get all participants except the sender
            let otherParticipants = conversation.participantIds.filter { $0 != currentUserId }

            // Check if all other participants have read the message
            return otherParticipants.allSatisfy { readBy.contains($0) }
        }()

        if readByAll && !conversation.participantIds.filter({ $0 != currentUserId }).isEmpty {
            // All participants have read - show blue double checkmark
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundColor(.blue)
        } else if conversation.lastMessageReadBy != nil {
            // Some have read (or message delivered) - show gray double checkmark
            Image(systemName: "checkmark.circle")
                .font(.caption)
                .foregroundColor(.secondary)
        } else {
            // Message sent but not delivered/read - show single checkmark
            Image(systemName: "checkmark")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview

struct ConversationRowView_Previews: PreviewProvider {
    static var previews: some View {
        let user1 = User(id: "user-1", email: "john@test.com", displayName: "John", isOnline: true, createdAt: Date())
        let user2 = User(id: "user-2", email: "jane@test.com", displayName: "Jane", isOnline: true, createdAt: Date())
        
        let conversation = Conversation(
            id: "conv-1",
            participantIds: ["user-1", "user-2"],
            lastMessage: "Hey, how are you doing?",
            lastMessageTimestamp: Date().addingTimeInterval(-3600),
            createdAt: Date().addingTimeInterval(-86400),
            isGroup: false
        )
        
        ConversationRowView(
            conversation: conversation,
            displayName: "John Doe",
            unreadCount: 3,
            formattedTimestamp: "1h ago",
            participants: [user1, user2],
            currentUserId: "current-user"
        )
        .previewLayout(.sizeThatFits)
        .padding()
    }
}

