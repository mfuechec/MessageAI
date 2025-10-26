import SwiftUI

/// Displays AI-powered smart reply suggestions above the message input
struct SmartReplyBar: View {
    let suggestions: [String]
    let isLoading: Bool
    let onTap: (String) -> Void

    var body: some View {
        if isLoading || !suggestions.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if isLoading {
                        ProgressView()
                            .padding(.horizontal, 12)
                            .accessibilityLabel("Loading smart replies")
                    } else {
                        ForEach(suggestions, id: \.self) { suggestion in
                            SmartReplyChip(text: suggestion) {
                                onTap(suggestion)
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .background(Color(.systemGray6))
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Smart reply suggestions")
        }
    }
}

/// Individual smart reply chip button
struct SmartReplyChip: View {
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.subheadline)
                .lineLimit(1)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
                .foregroundColor(.primary)
                .cornerRadius(20)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Smart reply")
        .accessibilityValue(text)
        .accessibilityHint("Double tap to send this message")
    }
}

// MARK: - Previews

struct SmartReplyBar_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // With suggestions
            SmartReplyBar(
                suggestions: ["Sure, what time?", "Can't today, sorry", "Sounds great!"],
                isLoading: false,
                onTap: { suggestion in
                    print("Tapped: \(suggestion)")
                }
            )

            // Loading state
            SmartReplyBar(
                suggestions: [],
                isLoading: true,
                onTap: { _ in }
            )

            // Empty (should show nothing)
            SmartReplyBar(
                suggestions: [],
                isLoading: false,
                onTap: { _ in }
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
