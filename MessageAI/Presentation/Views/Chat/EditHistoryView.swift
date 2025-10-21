import SwiftUI

/// Modal view displaying the edit history of a message
struct EditHistoryView: View {
    let message: Message
    @SwiftUI.Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                // Current version
                Section(header: Text("Current Version")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(message.text)
                            .font(.body)
                        
                        if let history = message.editHistory, !history.isEmpty,
                           let lastEdit = history.last {
                            Text("Edited \(formatTimestamp(lastEdit.editedAt))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // Previous versions
                if let history = message.editHistory, !history.isEmpty {
                    Section(header: Text("Previous Versions (\(history.count))")) {
                        ForEach(Array(history.enumerated().reversed()), id: \.offset) { index, edit in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(edit.text)
                                    .font(.body)
                                
                                Text(formatTimestamp(edit.editedAt))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Previous version: \(edit.text), edited \(formatTimestamp(edit.editedAt))")
                        }
                    }
                } else {
                    Section {
                        Text("No edit history available")
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
            }
            .navigationTitle("Edit History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .accessibilityLabel("Close edit history")
                }
            }
        }
        .accessibilityLabel("Edit history for message")
    }
    
    /// Formats a date as a relative time string
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Preview

struct EditHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        // Sample message with edit history
        let sampleMessage = Message(
            id: "1",
            conversationId: "conv1",
            senderId: "user1",
            text: "This is the current version after two edits",
            timestamp: Date(),
            status: .sent,
            editHistory: [
                MessageEdit(
                    text: "This is the original message",
                    editedAt: Date().addingTimeInterval(-3600) // 1 hour ago
                ),
                MessageEdit(
                    text: "This is the first edited version",
                    editedAt: Date().addingTimeInterval(-1800) // 30 minutes ago
                )
            ],
            editCount: 2,
            isEdited: true,
            schemaVersion: 1
        )
        
        EditHistoryView(message: sampleMessage)
    }
}

