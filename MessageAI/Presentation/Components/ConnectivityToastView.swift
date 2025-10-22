//
//  ConnectivityToastView.swift
//  MessageAI
//
//  Toast notification when connectivity is restored with queued messages
//  Story 2.9: Offline Message Queue with Manual Send
//

import SwiftUI

/// Toast notification displayed when connectivity is restored
///
/// Appears when user goes from offline → online with queued messages.
/// Offers two options: auto-send all messages, or review queue first.
///
/// **Usage:**
/// ```swift
/// if viewModel.showConnectivityToast {
///     ConnectivityToastView(
///         queuedCount: viewModel.queuedMessages.count,
///         onAutoSend: {
///             Task { await viewModel.sendAllQueuedMessages() }
///         },
///         onReviewFirst: {
///             showOfflineQueue = true
///         }
///     )
/// }
/// ```
///
/// **Design:**
/// - Green success color (connectivity restored)
/// - Auto-dismisses after 10 seconds
/// - Two action buttons: "Yes, Send All" and "Review First"
struct ConnectivityToastView: View {
    // MARK: - Properties

    let queuedCount: Int
    let onAutoSend: () -> Void
    let onReviewFirst: () -> Void

    // MARK: - Body

    var body: some View {
        VStack(spacing: 16) {
            // Header with icon and text
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 24))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Connected")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Text(messageText)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.9))
                }

                Spacer()
            }

            // Action buttons
            HStack(spacing: 12) {
                // Review First button (secondary action)
                Button(action: onReviewFirst) {
                    Text("Review First")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.green)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .cornerRadius(8)
                }

                // Yes, Send All button (primary action)
                Button(action: onAutoSend) {
                    Text("Yes, Send All")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.3))
                        .cornerRadius(8)
                }
            }
        }
        .padding(20)
        .background(Color.green)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
        .padding(.horizontal, 20)
    }

    // MARK: - Computed Properties

    /// Message text (singular vs plural)
    private var messageText: String {
        if queuedCount == 1 {
            return "Auto-send 1 queued message?"
        } else {
            return "Auto-send \(queuedCount) queued messages?"
        }
    }
}

// MARK: - Preview

#Preview("Single Message") {
    ZStack {
        Color.gray.opacity(0.3)
            .ignoresSafeArea()

        ConnectivityToastView(queuedCount: 1) {
            print("Auto-send tapped")
        } onReviewFirst: {
            print("Review first tapped")
        }
    }
}

#Preview("Multiple Messages") {
    ZStack {
        Color.gray.opacity(0.3)
            .ignoresSafeArea()

        ConnectivityToastView(queuedCount: 5) {
            print("Auto-send tapped")
        } onReviewFirst: {
            print("Review first tapped")
        }
    }
}

#Preview("Many Messages") {
    ZStack {
        Color.gray.opacity(0.3)
            .ignoresSafeArea()

        ConnectivityToastView(queuedCount: 23) {
            print("Auto-send tapped")
        } onReviewFirst: {
            print("Review first tapped")
        }
    }
}
