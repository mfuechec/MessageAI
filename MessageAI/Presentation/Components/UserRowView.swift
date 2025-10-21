//
//  UserRowView.swift
//  MessageAI
//
//  Created by Dev Agent (James) on 10/21/25.
//  Story 2.0: Start New Conversation with Duplicate Prevention
//

import SwiftUI

/// Reusable row component for displaying a user in a list
struct UserRowView: View {
    let user: User
    
    var body: some View {
        let _ = print("🖼️ [UserRow] Rendering for \(user.displayName)")
        
        return HStack(spacing: 12) {
            // Avatar (photo or initials)
            if let photoURL = user.profileImageURL, !photoURL.isEmpty, let url = URL(string: photoURL) {
                let _ = print("🖼️ [UserRow] Has image URL: \(photoURL)")
                AsyncImage(url: url) { phase in
                    Group {
                        switch phase {
                        case .success(let image):
                            let _ = print("✅ [UserRow] Image loaded for \(user.displayName)")
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 50, height: 50)
                                .clipShape(Circle())
                        case .failure(let error):
                            let _ = print("❌ [UserRow] Image failed for \(user.displayName): \(error)")
                            initialsCircle
                        case .empty:
                            let _ = print("⏳ [UserRow] Image loading for \(user.displayName)...")
                            ProgressView()
                                .frame(width: 50, height: 50)
                        @unknown default:
                            initialsCircle
                        }
                    }
                }
            } else {
                let _ = print("ℹ️ [UserRow] No image for \(user.displayName), showing initials")
                initialsCircle
            }
            
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
                .frame(width: 12, height: 12)
                .accessibilityLabel(accessibilityText)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(user.displayName), \(user.email), \(user.isOnline ? "Online" : "Offline")")
    }
    
    private var initialsCircle: some View {
        Circle()
            .fill(Color.blue)
            .frame(width: 50, height: 50)
            .overlay(
                Text(user.displayInitials)
                    .foregroundColor(.white)
                    .font(.headline)
            )
    }
}

