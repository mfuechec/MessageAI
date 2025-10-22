//
//  OfflineQueueView.swift
//  MessageAI
//
//  View for reviewing and managing queued offline messages
//  Story 2.9: Offline Message Queue with Manual Send
//

import SwiftUI

/// Full-screen view displaying all queued offline messages
///
/// Allows user to:
/// - Review all queued messages
/// - Send individual messages
/// - Send all messages at once
/// - Edit message text before sending
/// - Delete messages from queue
///
/// **Navigation:**
/// - Opened from ConnectivityToastView "Review First" button
/// - Opened from OfflineBannerView tap (future enhancement)
///
/// **Usage:**
/// ```swift
/// .sheet(isPresented: $showOfflineQueue) {
///     OfflineQueueView(viewModel: offlineQueueViewModel)
/// }
/// ```
struct OfflineQueueView: View {
    // MARK: - Properties

    @ObservedObject var viewModel: OfflineQueueViewModel
    @SwiftUI.Environment(\.dismiss) private var dismiss: DismissAction

    // MARK: - Body

    var body: some View {
        NavigationView {
            Group {
                if viewModel.queuedMessages.isEmpty {
                    emptyState
                } else {
                    messageList
                }
            }
            .navigationTitle("Offline Queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }

                if !viewModel.queuedMessages.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Send All") {
                            Task {
                                await viewModel.sendAllMessages()
                                // Auto-close if all messages sent successfully
                                if viewModel.queuedMessages.isEmpty {
                                    dismiss()
                                }
                            }
                        }
                        .font(.system(size: 16, weight: .semibold))
                    }
                }
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
        }
    }

    // MARK: - Subviews

    /// Empty state when no messages queued
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 60))
                .foregroundColor(.green)

            Text("No Queued Messages")
                .font(.title2.bold())

            Text("Messages you compose offline will appear here")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    /// List of queued messages
    private var messageList: some View {
        List {
            ForEach(viewModel.queuedMessages) { message in
                MessageQueueRow(
                    message: message,
                    onSend: {
                        Task {
                            await viewModel.sendMessage(message)
                        }
                    },
                    onEdit: {
                        viewModel.selectedMessageForEdit = message
                    },
                    onDelete: {
                        viewModel.deleteMessage(message)
                    }
                )
            }
        }
        .listStyle(.plain)
        .sheet(item: $viewModel.selectedMessageForEdit) { message in
            EditMessageSheet(
                message: message,
                onSave: { newText in
                    viewModel.editMessage(message, newText: newText)
                }
            )
        }
    }
}

// MARK: - MessageQueueRow

/// Row view for a single queued message
struct MessageQueueRow: View {
    let message: Message
    let onSend: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Message content and status
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(message.text)
                        .font(.body)
                        .lineLimit(3)

                    Text(formattedTimestamp)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                StatusBadge(status: message.status)
            }

            // Action buttons
            HStack(spacing: 12) {
                Button(action: onSend) {
                    Label("Send Now", systemImage: "paperplane.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
                .disabled(message.status == .sending)

                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
                .disabled(message.status == .sending)

                Button(action: onDelete) {
                    Label("Delete", systemImage: "trash")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.red)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }
                .disabled(message.status == .sending)

                Spacer()
            }
        }
        .padding(.vertical, 8)
    }

    private var formattedTimestamp: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: message.timestamp, relativeTo: Date())
    }
}

// MARK: - StatusBadge

/// Badge showing message status (queued, sending, failed)
struct StatusBadge: View {
    let status: MessageStatus

    var body: some View {
        Text(statusText)
            .font(.caption.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(badgeColor)
            .cornerRadius(6)
    }

    private var statusText: String {
        status.rawValue.capitalized
    }

    private var badgeColor: Color {
        switch status {
        case .queued: return .orange
        case .sending: return .blue
        case .failed: return .red
        default: return .gray
        }
    }
}

// MARK: - EditMessageSheet

/// Modal sheet for editing a queued message
struct EditMessageSheet: View {
    let message: Message
    let onSave: (String) -> Void

    @SwiftUI.Environment(\.dismiss) private var dismiss: DismissAction
    @State private var editedText: String

    init(message: Message, onSave: @escaping (String) -> Void) {
        self.message = message
        self.onSave = onSave
        _editedText = State(initialValue: message.text)
    }

    var body: some View {
        NavigationView {
            VStack {
                TextEditor(text: $editedText)
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .font(.body)
            }
            .navigationTitle("Edit Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(editedText)
                        dismiss()
                    }
                    .disabled(editedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

// MARK: - Previews

// Note: Previews removed due to dependency on test mocks
// Run the app to see the OfflineQueueView in action
