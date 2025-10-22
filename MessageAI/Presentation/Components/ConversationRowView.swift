import SwiftUI
import Kingfisher

/// Row view component for displaying conversation summary
struct ConversationRowView: View {
    let conversation: Conversation
    let displayName: String
    let unreadCount: Int
    let formattedTimestamp: String
    let participants: [User]  // For group avatar display
    
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
                
                HStack {
                    Text(conversation.lastMessage ?? "No messages yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    Spacer()
                    
                    if unreadCount > 0 {
                        unreadBadge
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(displayName), \(conversation.lastMessage ?? "No messages"), \(formattedTimestamp), \(unreadCount) unread")
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
            .background(Color.accentColor)
            .clipShape(Capsule())
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
            participants: [user1, user2]
        )
        .previewLayout(.sizeThatFits)
        .padding()
    }
}

