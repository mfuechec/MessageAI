import SwiftUI

/// Shows list of users who have read a message in group chat (AC #7)
struct ReadReceiptDetailView: View {
    let message: Message
    let participants: [User]
    let currentUserId: String
    @SwiftUI.Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("Read By (\(message.readBy.count))") {
                    ForEach(readByUsers) { user in
                        HStack(spacing: 12) {
                            // Avatar
                            if let photoURL = user.profileImageURL, let url = URL(string: photoURL) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 40, height: 40)
                                            .clipShape(Circle())
                                    case .failure, .empty:
                                        initialsCircle(for: user)
                                    @unknown default:
                                        initialsCircle(for: user)
                                    }
                                }
                            } else {
                                initialsCircle(for: user)
                            }
                            
                            VStack(alignment: .leading) {
                                Text(user.displayName)
                                    .font(.body)
                                
                                if user.id == message.senderId {
                                    Text("Sender")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                        }
                        .accessibilityLabel("\(user.displayName) has read this message")
                    }
                }
                
                if !unreadUsers.isEmpty {
                    Section("Not Read Yet (\(unreadUsers.count))") {
                        ForEach(unreadUsers) { user in
                            HStack(spacing: 12) {
                                // Avatar
                                if let photoURL = user.profileImageURL, let url = URL(string: photoURL) {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 40, height: 40)
                                                .clipShape(Circle())
                                        case .failure, .empty:
                                            initialsCircle(for: user)
                                        @unknown default:
                                            initialsCircle(for: user)
                                        }
                                    }
                                } else {
                                    initialsCircle(for: user)
                                }
                                
                                Text(user.displayName)
                                    .font(.body)
                                
                                Spacer()
                                
                                Image(systemName: "circle")
                                    .foregroundColor(.gray)
                            }
                            .accessibilityLabel("\(user.displayName) has not read this message yet")
                        }
                    }
                }
            }
            .navigationTitle("Read Receipts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .accessibilityLabel("Close read receipts")
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var readByUsers: [User] {
        participants.filter { user in
            message.readBy.contains(user.id)
        }
    }
    
    private var unreadUsers: [User] {
        participants.filter { user in
            !message.readBy.contains(user.id) && user.id != currentUserId
        }
    }
    
    // MARK: - Helper Views
    
    private func initialsCircle(for user: User) -> some View {
        Circle()
            .fill(Color.blue)
            .frame(width: 40, height: 40)
            .overlay(
                Text(user.displayInitials)
                    .foregroundColor(.white)
                    .font(.subheadline)
            )
    }
}

