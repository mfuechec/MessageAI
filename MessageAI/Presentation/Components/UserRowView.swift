//
//  UserRowView.swift
//  MessageAI
//
//  Created by Dev Agent (James) on 10/21/25.
//  Story 2.0: Start New Conversation with Duplicate Prevention
//  Updated: Phase 2 - Issue #2 Fix - Replaced AsyncImage with UserAvatarView for consistent caching
//

import SwiftUI

/// Reusable row component for displaying a user in a list
struct UserRowView: View {
    let user: User

    var body: some View {
        let _ = print("🖼️ [UserRow] Rendering for \(user.displayName)")

        return HStack(spacing: 12) {
            // Avatar - Using unified UserAvatarView with Kingfisher caching (Phase 2 Fix)
            UserAvatarView(
                user: user,
                size: 50,
                showPresenceIndicator: false  // Presence shown separately
            )
            
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
}

