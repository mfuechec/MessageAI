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
        HStack(spacing: 12) {
            // Avatar (photo or initials)
            if let photoURL = user.profileImageURL, !photoURL.isEmpty, let url = URL(string: photoURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    ProgressView()
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            } else {
                // Initials avatar
                Circle()
                    .fill(Color.blue)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(user.displayInitials)
                            .foregroundColor(.white)
                            .font(.headline)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName)
                    .font(.headline)
                
                Text(user.email)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Online indicator
            if user.isOnline {
                Circle()
                    .fill(Color.green)
                    .frame(width: 12, height: 12)
                    .accessibilityLabel("Online")
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(user.displayName), \(user.email), \(user.isOnline ? "Online" : "Offline")")
    }
}

