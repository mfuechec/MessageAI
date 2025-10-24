import SwiftUI

/// Story 6.6: Message Highlight Modifier
///
/// Applies a brief yellow highlight animation to a message when navigated via deep link
struct MessageHighlightModifier: ViewModifier {

    /// Message ID to highlight
    let messageId: String

    /// Currently highlighted message ID (from ChatViewModel)
    @Binding var highlightedMessageId: String?

    /// Animation state
    @State private var isHighlighted: Bool = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.yellow.opacity(isHighlighted ? 0.4 : 0))
                    .animation(.easeInOut(duration: 0.5), value: isHighlighted)
            )
            .onChange(of: highlightedMessageId) { newValue in
                if newValue == messageId {
                    triggerHighlight()
                }
            }
    }

    /// Trigger highlight animation
    ///
    /// Story 6.6: Duration: 2 seconds (flash 0.5s, hold 1s, fade 0.5s)
    private func triggerHighlight() {
        // Flash in (0.5s)
        withAnimation(.easeIn(duration: 0.5)) {
            isHighlighted = true
        }

        // Hold for 1 second, then fade out (0.5s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.5)) {
                isHighlighted = false
            }

            // Clear highlighted message ID after animation completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                highlightedMessageId = nil
            }
        }
    }
}

// MARK: - View Extension

extension View {
    /// Apply message highlight modifier
    func messageHighlight(messageId: String, highlightedMessageId: Binding<String?>) -> some View {
        self.modifier(MessageHighlightModifier(messageId: messageId, highlightedMessageId: highlightedMessageId))
    }
}
