//
//  SmartNotificationBanner.swift
//  MessageAI
//
//  Created by Claude Code on 10/23/25.
//  Epic 6: Smart In-App Notifications
//

import SwiftUI

/// In-app notification banner showing AI-analyzed notifications
struct SmartNotificationBanner: View {
    let notification: InAppSmartNotification
    let onTap: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Priority indicator badge
                priorityBadge

                VStack(alignment: .leading, spacing: 6) {
                    // Conversation name with timestamp
                    HStack {
                        Text(notification.conversationName)
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)

                        Spacer()

                        Text("now")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    // AI-generated notification text
                    Text(notification.notificationText)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Dismiss button
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // AI reasoning footer
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.caption2)
                    .foregroundColor(priorityColor)

                Text(notification.aiReasoning)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.05))
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: shadowColor, radius: 12, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(priorityColor.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .onTapGesture {
            onTap()
        }
    }

    @ViewBuilder
    private var priorityBadge: some View {
        Circle()
            .fill(priorityColor)
            .frame(width: 10, height: 10)
            .overlay(
                Circle()
                    .strokeBorder(priorityColor.opacity(0.3), lineWidth: 2)
                    .frame(width: 16, height: 16)
            )
    }

    private var priorityColor: Color {
        switch notification.priority {
        case .high:
            return Color.red
        case .medium:
            return Color.orange
        case .low:
            return Color.blue
        }
    }

    private var shadowColor: Color {
        return Color.black.opacity(0.15)
    }
}

#if DEBUG
struct SmartNotificationBanner_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // High priority
            SmartNotificationBanner(
                notification: InAppSmartNotification(
                    conversationId: "conv-1",
                    conversationName: "Alice Johnson",
                    notificationText: "Can you review the urgent PR? We need to deploy ASAP.",
                    priority: .high,
                    aiReasoning: "Contains urgent keyword",
                    timestamp: Date()
                ),
                onTap: {},
                onDismiss: {}
            )

            // Medium priority
            SmartNotificationBanner(
                notification: InAppSmartNotification(
                    conversationId: "conv-2",
                    conversationName: "Team Chat",
                    notificationText: "What time is the meeting tomorrow?",
                    priority: .medium,
                    aiReasoning: "Direct question addressed to you",
                    timestamp: Date()
                ),
                onTap: {},
                onDismiss: {}
            )

            // Low priority
            SmartNotificationBanner(
                notification: InAppSmartNotification(
                    conversationId: "conv-3",
                    conversationName: "Bob Smith",
                    notificationText: "Thanks for the help earlier!",
                    priority: .low,
                    aiReasoning: "Social acknowledgment",
                    timestamp: Date()
                ),
                onTap: {},
                onDismiss: {}
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
