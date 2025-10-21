//
//  GroupMemberListView.swift
//  MessageAI
//
//  Created by Dev Agent (James) on 10/21/25.
//  Story 2.1: Group Chat Functionality
//

import SwiftUI

/// View displaying all participants in a group conversation
struct GroupMemberListView: View {
    let participants: [User]
    @SwiftUI.Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List(participants) { user in
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
                    
                    // User info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.displayName)
                            .font(.headline)
                        
                        Text(user.email)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Presence indicator (3 states: online, recently offline, offline)
                    let status = user.presenceStatus
                    let rgb = status.color
                    let accessibilityText: String = {
                        switch status {
                        case .online: return "Online"
                        case .recentlyOffline: return "Recently offline"
                        case .offline: return "Offline"
                        }
                    }()
                    
                    Circle()
                        .fill(Color(red: rgb.red, green: rgb.green, blue: rgb.blue))
                        .frame(width: 10, height: 10)
                        .accessibilityLabel(accessibilityText)
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(user.displayName), \(user.email), \(user.isOnline ? "online" : "offline")")
            }
            .navigationTitle("Group Members")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .accessibilityLabel("Close group members")
                }
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func initialsCircle(for user: User) -> some View {
        Circle()
            .fill(Color.blue)
            .frame(width: 40, height: 40)
            .overlay(
                Text(user.displayName.prefix(2).uppercased())
                    .foregroundColor(.white)
                    .font(.subheadline)
            )
    }
}

// MARK: - Preview

struct GroupMemberListView_Previews: PreviewProvider {
    static var previews: some View {
        let participants = [
            User(id: "1", email: "alice@test.com", displayName: "Alice", isOnline: true, createdAt: Date()),
            User(id: "2", email: "bob@test.com", displayName: "Bob", isOnline: true, createdAt: Date()),
            User(id: "3", email: "charlie@test.com", displayName: "Charlie", isOnline: false, createdAt: Date())
        ]
        
        GroupMemberListView(participants: participants)
    }
}

