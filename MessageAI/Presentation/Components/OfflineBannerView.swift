//
//  OfflineBannerView.swift
//  MessageAI
//
//  Offline banner displayed when messages are queued
//  Story 2.9: Offline Message Queue with Manual Send
//

import SwiftUI

/// Banner displayed when user has queued messages waiting to be sent
///
/// **Usage:**
/// ```swift
/// if viewModel.queuedMessages.count > 0 {
///     OfflineBannerView(
///         queuedCount: viewModel.queuedMessages.count,
///         onSendAll: {
///             Task { await viewModel.sendAllQueuedMessages() }
///         }
///     )
/// }
/// ```
///
/// **Design:**
/// - Yellow/orange warning color
/// - Shows count of queued messages
/// - "Send All" button for quick action
/// - Positioned at top of chat view (sticky)
struct OfflineBannerView: View {
    // MARK: - Properties

    let queuedCount: Int
    let onSendAll: () -> Void

    // MARK: - Body

    var body: some View {
        HStack(spacing: 12) {
            // Warning icon
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.system(size: 20))

            // Text content
            VStack(alignment: .leading, spacing: 2) {
                Text("You're offline")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)

                Text(countText)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Send All button
            Button(action: onSendAll) {
                Text("Send All")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.orange)
                    .cornerRadius(8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.yellow.opacity(0.2))
        .overlay(
            // Bottom border
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.orange.opacity(0.3)),
            alignment: .bottom
        )
    }

    // MARK: - Computed Properties

    /// Message count text (singular vs plural)
    private var countText: String {
        if queuedCount == 1 {
            return "1 message queued"
        } else {
            return "\(queuedCount) messages queued"
        }
    }
}

// MARK: - Preview

#Preview("Single Message") {
    OfflineBannerView(queuedCount: 1) {
        print("Send All tapped")
    }
}

#Preview("Multiple Messages") {
    OfflineBannerView(queuedCount: 5) {
        print("Send All tapped")
    }
}

#Preview("Many Messages") {
    OfflineBannerView(queuedCount: 42) {
        print("Send All tapped")
    }
}
