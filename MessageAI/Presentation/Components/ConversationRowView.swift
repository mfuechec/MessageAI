import SwiftUI

/// Row view component for displaying conversation summary
struct ConversationRowView: View {
    let conversation: Conversation
    let displayName: String
    let unreadCount: Int
    let formattedTimestamp: String
    
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
    
    private var profileImage: some View {
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
            formattedTimestamp: "1h ago"
        )
        .previewLayout(.sizeThatFits)
        .padding()
    }
}

