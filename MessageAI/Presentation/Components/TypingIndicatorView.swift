import SwiftUI

/// Displays typing indicator: "[Name] is typing..." or "[Name], [Name] are typing..."
struct TypingIndicatorView: View {
    let typingUserNames: [String]

    @State private var dotCount: Int = 1

    var body: some View {
        if typingUserNames.isEmpty {
            EmptyView()
        } else {
            HStack(spacing: 4) {
                Text(formattedText)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .italic()

                // Animated dots
                Text(String(repeating: ".", count: dotCount))
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .onAppear {
                        startAnimation()
                    }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.leading, 12)
            .padding(.bottom, 4)
            .accessibilityLabel("Typing indicator")
            .accessibilityValue(formattedText)
        }
    }

    private var formattedText: String {
        if typingUserNames.count == 1 {
            return "\(typingUserNames[0]) is typing"
        } else if typingUserNames.count == 2 {
            return "\(typingUserNames[0]) and \(typingUserNames[1]) are typing"
        } else {
            let names = typingUserNames.prefix(2).joined(separator: ", ")
            return "\(names), and \(typingUserNames.count - 2) more are typing"
        }
    }

    private func startAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            withAnimation {
                dotCount = (dotCount % 3) + 1
            }
        }
    }
}

// MARK: - Previews

struct TypingIndicatorView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Single user typing
            TypingIndicatorView(typingUserNames: ["Alice"])

            // Two users typing
            TypingIndicatorView(typingUserNames: ["Alice", "Bob"])

            // Three users typing
            TypingIndicatorView(typingUserNames: ["Alice", "Bob", "Charlie"])

            // Empty (should show nothing)
            TypingIndicatorView(typingUserNames: [])
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
