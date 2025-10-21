//
//  GroupAvatarView.swift
//  MessageAI
//
//  Created by Dev Agent (James) on 10/21/25.
//  Story 2.1: Group Chat Functionality
//

import SwiftUI

/// Reusable component that displays multi-participant avatars in various layouts
/// - 2 participants: Side-by-side circular avatars
/// - 3 participants: Triangular arrangement (2 top, 1 bottom)
/// - 4+ participants: 2x2 grid (shows first 4)
struct GroupAvatarView: View {
    let users: [User]
    let size: CGFloat
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.gray.opacity(0.1))
                .frame(width: size, height: size)
            
            switch users.count {
            case 2:
                twoUserLayout
            case 3:
                threeUserLayout
            default:
                fourPlusUserLayout
            }
        }
        .accessibilityLabel(accessibilityText)
    }
    
    // MARK: - Layout Variations
    
    private var twoUserLayout: some View {
        HStack(spacing: 2) {
            miniAvatar(for: users.first, size: size * 0.45)
            if users.count > 1 {
                miniAvatar(for: users[1], size: size * 0.45)
            }
        }
    }
    
    private var threeUserLayout: some View {
        VStack(spacing: 2) {
            HStack(spacing: 2) {
                miniAvatar(for: users.first, size: size * 0.35)
                if users.count > 1 {
                    miniAvatar(for: users[1], size: size * 0.35)
                }
            }
            if users.count > 2 {
                miniAvatar(for: users[2], size: size * 0.35)
            }
        }
    }
    
    private var fourPlusUserLayout: some View {
        VStack(spacing: 2) {
            HStack(spacing: 2) {
                miniAvatar(for: users.first, size: size * 0.45)
                miniAvatar(for: users.safeIndex(1), size: size * 0.45)
            }
            HStack(spacing: 2) {
                miniAvatar(for: users.safeIndex(2), size: size * 0.45)
                // Show 4th avatar or "+N" indicator
                if users.count > 4 {
                    additionalUsersIndicator(count: users.count - 3, size: size * 0.45)
                } else {
                    miniAvatar(for: users.safeIndex(3), size: size * 0.45)
                }
            }
        }
    }
    
    // MARK: - Helper Views
    
    @ViewBuilder
    private func miniAvatar(for user: User?, size: CGFloat) -> some View {
        if let user = user {
            if let photoURL = user.profileImageURL, 
               !photoURL.isEmpty,
               let url = URL(string: photoURL) {
                let _ = print("🖼️ [GroupAvatar] Loading image for \(user.displayName): \(photoURL)")
                AsyncImage(url: url) { phase in
                    Group {
                        switch phase {
                        case .success(let image):
                            let _ = print("✅ [GroupAvatar] Image loaded for \(user.displayName)")
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: size, height: size)
                                .clipShape(Circle())
                        case .failure(let error):
                            let _ = print("❌ [GroupAvatar] Image failed for \(user.displayName): \(error)")
                            initialsCircle(for: user, size: size)
                        case .empty:
                            let _ = print("⏳ [GroupAvatar] Image loading for \(user.displayName)...")
                            initialsCircle(for: user, size: size)
                        @unknown default:
                            initialsCircle(for: user, size: size)
                        }
                    }
                }
            } else {
                let _ = print("ℹ️ [GroupAvatar] No image for \(user.displayName), showing initials")
                initialsCircle(for: user, size: size)
            }
        } else {
            // Placeholder for missing user
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: size, height: size)
        }
    }
    
    private func initialsCircle(for user: User, size: CGFloat) -> some View {
        Circle()
            .fill(Color.blue)
            .frame(width: size, height: size)
            .overlay(
                Text(user.displayName.prefix(1).uppercased())
                    .foregroundColor(.white)
                    .font(.system(size: size * 0.5))
            )
    }
    
    private func additionalUsersIndicator(count: Int, size: CGFloat) -> some View {
        Circle()
            .fill(Color.gray.opacity(0.8))
            .frame(width: size, height: size)
            .overlay(
                Text("+\(count)")
                    .foregroundColor(.white)
                    .font(.system(size: size * 0.4, weight: .semibold))
            )
    }
    
    // MARK: - Accessibility
    
    private var accessibilityText: String {
        if users.count <= 3 {
            let names = users.map { $0.truncatedDisplayName }.joined(separator: ", ")
            return "Group conversation with \(names)"
        } else if users.count == 4 {
            let names = users.map { $0.truncatedDisplayName }.joined(separator: ", ")
            return "Group conversation with \(names)"
        } else {
            let firstThree = users.prefix(3).map { $0.truncatedDisplayName }.joined(separator: ", ")
            let remaining = users.count - 3
            return "Group conversation with \(firstThree) and \(remaining) other\(remaining == 1 ? "" : "s")"
        }
    }
}

// MARK: - Array Extension

extension Array {
    /// Safely access an array element by index, returning nil if out of bounds
    func safeIndex(_ index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Preview

struct GroupAvatarView_Previews: PreviewProvider {
    static var previews: some View {
        let user1 = User(id: "1", email: "alice@test.com", displayName: "Alice", isOnline: true, createdAt: Date())
        let user2 = User(id: "2", email: "bob@test.com", displayName: "Bob", isOnline: true, createdAt: Date())
        let user3 = User(id: "3", email: "charlie@test.com", displayName: "Charlie", isOnline: true, createdAt: Date())
        let user4 = User(id: "4", email: "diana@test.com", displayName: "Diana", isOnline: true, createdAt: Date())
        let user5 = User(id: "5", email: "eve@test.com", displayName: "Eve", isOnline: true, createdAt: Date())
        let user6 = User(id: "6", email: "frank@test.com", displayName: "Frank", isOnline: true, createdAt: Date())
        
        VStack(spacing: 20) {
            GroupAvatarView(users: [user1, user2], size: 60)
            GroupAvatarView(users: [user1, user2, user3], size: 60)
            GroupAvatarView(users: [user1, user2, user3, user4], size: 60)
            GroupAvatarView(users: [user1, user2, user3, user4, user5, user6], size: 60)
        }
        .padding()
    }
}

