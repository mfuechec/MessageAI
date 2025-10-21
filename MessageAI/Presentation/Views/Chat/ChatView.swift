import SwiftUI
import MessageKit
import InputBarAccessoryView

/// Main chat view displaying messages for a conversation
struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    @State private var conversationTitle: String = "Chat"
    
    var body: some View {
        ZStack {
            // MessageKit wrapper
            MessageKitWrapper(viewModel: viewModel, conversationTitle: $conversationTitle)
                .edgesIgnoringSafeArea(.bottom)
            
            // Offline banner
            if viewModel.isOffline {
                VStack {
                    offlineBanner
                    Spacer()
                }
            }
            
            // Loading overlay
            if viewModel.isLoading && viewModel.messages.isEmpty {
                ProgressView("Loading messages...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground).opacity(0.9))
            }
        }
        .navigationTitle(conversationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            updateConversationTitle()
        }
        .onChange(of: viewModel.users) { _ in
            updateConversationTitle()
        }
    }
    
    private var offlineBanner: some View {
        HStack {
            Image(systemName: "wifi.slash")
            Text("You're offline")
                .font(.subheadline)
        }
        .foregroundColor(.white)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color.orange)
        .accessibilityLabel("You are offline. Messages will send when connected.")
    }
    
    private func updateConversationTitle() {
        // Get other participant's name
        let otherUsers = viewModel.users.values.filter { $0.id != viewModel.displayName(for: $0.id) }
        if let firstUser = otherUsers.first {
            conversationTitle = firstUser.displayName
        } else if !viewModel.users.isEmpty {
            conversationTitle = viewModel.users.values.first?.displayName ?? "Chat"
        }
    }
}

// MARK: - MessageKit Wrapper

struct MessageKitWrapper: UIViewControllerRepresentable {
    @ObservedObject var viewModel: ChatViewModel
    @Binding var conversationTitle: String
    
    func makeUIViewController(context: Context) -> CustomMessagesViewController {
        let vc = CustomMessagesViewController(viewModel: viewModel)
        vc.messagesCollectionView.messagesDataSource = context.coordinator
        vc.messagesCollectionView.messagesLayoutDelegate = context.coordinator
        vc.messagesCollectionView.messagesDisplayDelegate = context.coordinator
        vc.messageInputBar.delegate = context.coordinator
        return vc
    }
    
    func updateUIViewController(_ uiViewController: CustomMessagesViewController, context: Context) {
        // Only reload if message count changed or last message changed
        let currentCount = uiViewController.messageCount
        let newCount = viewModel.messages.count
        
        if currentCount != newCount {
            uiViewController.messageCount = newCount
            uiViewController.messagesCollectionView.reloadData()
            
            // Auto-scroll to bottom if user was near bottom or new message is from current user
            if newCount > currentCount {
                let shouldScroll = context.coordinator.isNearBottom || 
                                  (viewModel.messages.last?.senderId == viewModel.displayName(for: viewModel.messages.last?.senderId ?? ""))
                if shouldScroll {
                    DispatchQueue.main.async {
                        uiViewController.messagesCollectionView.scrollToLastItem(animated: true)
                    }
                }
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, MessagesDataSource, MessagesLayoutDelegate, MessagesDisplayDelegate, InputBarAccessoryViewDelegate {
        let viewModel: ChatViewModel
        var isNearBottom: Bool = true
        
        init(viewModel: ChatViewModel) {
            self.viewModel = viewModel
            super.init()
        }
        
        // MARK: - MessagesDataSource
        
        var currentSender: SenderType {
            return Sender(senderId: viewModel.displayName(for: ""), displayName: "You")
        }
        
        func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageType {
            let message = viewModel.messages[indexPath.section]
            let displayName = viewModel.displayName(for: message.senderId)
            return MessageKitMessage(message: message, displayName: displayName)
        }
        
        func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int {
            return viewModel.messages.count
        }
        
        // MARK: - MessagesDisplayDelegate
        
        func backgroundColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
            return isFromCurrentSender(message: message) ? .systemBlue : .secondarySystemGroupedBackground
        }
        
        func textColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
            return isFromCurrentSender(message: message) ? .white : .label
        }
        
        func configureAvatarView(_ avatarView: AvatarView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
            // Hide avatars for MVP
            avatarView.isHidden = true
        }
        
        func messageBottomLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
            let actualMessage = viewModel.messages[indexPath.section]
            let timestamp = viewModel.formattedTimestamp(for: actualMessage)
            let statusText = statusString(for: actualMessage.status)
            let combined = "\(timestamp) \(statusText)"
            
            return NSAttributedString(
                string: combined,
                attributes: [
                    .font: UIFont.preferredFont(forTextStyle: .caption2),
                    .foregroundColor: UIColor.secondaryLabel
                ]
            )
        }
        
        // MARK: - MessagesLayoutDelegate
        
        func messageBottomLabelHeight(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
            return 16
        }
        
        func footerViewSize(for section: Int, in messagesCollectionView: MessagesCollectionView) -> CGSize {
            return CGSize(width: 0, height: 8)
        }
        
        // MARK: - InputBarAccessoryViewDelegate
        
        func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
            // Update viewModel's message text and send
            Task { @MainActor in
                viewModel.messageText = text
                await viewModel.sendMessage()
                inputBar.inputTextView.text = ""
                inputBar.invalidatePlugins()
            }
        }
        
        // MARK: - Scroll Detection
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let offsetY = scrollView.contentOffset.y
            let contentHeight = scrollView.contentSize.height
            let scrollViewHeight = scrollView.frame.size.height
            let distanceFromBottom = contentHeight - offsetY - scrollViewHeight
            
            // User is "near bottom" if within 100 points
            isNearBottom = distanceFromBottom < 100
        }
        
        // MARK: - Helper Methods
        
        private func statusString(for status: MessageStatus) -> String {
            switch status {
            case .sending:
                return "●"
            case .sent:
                return "✓"
            case .delivered:
                return "✓✓"
            case .read:
                return "✓✓"
            case .failed:
                return "⚠"
            }
        }
    }
}

// MARK: - Custom Messages View Controller

class CustomMessagesViewController: MessagesViewController {
    var messageCount: Int = 0
    private weak var viewModel: ChatViewModel?
    
    init(viewModel: ChatViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureMessageCollectionView()
        configureMessageInputBar()
        
        // Show empty state if no messages
        if viewModel?.messages.isEmpty == true {
            showEmptyState()
        }
    }
    
    private func configureMessageCollectionView() {
        messagesCollectionView.backgroundColor = .systemBackground
        
        // Hide avatars
        if let layout = messagesCollectionView.collectionViewLayout as? MessagesCollectionViewFlowLayout {
            layout.textMessageSizeCalculator.outgoingAvatarSize = .zero
            layout.textMessageSizeCalculator.incomingAvatarSize = .zero
            layout.setMessageIncomingAvatarSize(.zero)
            layout.setMessageOutgoingAvatarSize(.zero)
        }
        
        // Accessibility
        messagesCollectionView.isAccessibilityElement = false
        messagesCollectionView.shouldGroupAccessibilityChildren = true
    }
    
    private func configureMessageInputBar() {
        messageInputBar.backgroundView.backgroundColor = .systemGroupedBackground
        messageInputBar.inputTextView.placeholder = "Message"
        messageInputBar.sendButton.setTitle("Send", for: .normal)
        messageInputBar.sendButton.setTitleColor(.systemBlue, for: .normal)
        
        // Accessibility
        messageInputBar.inputTextView.accessibilityLabel = "Message input"
        messageInputBar.inputTextView.accessibilityHint = "Enter your message"
        messageInputBar.sendButton.accessibilityLabel = "Send message"
    }
    
    private func showEmptyState() {
        let emptyLabel = UILabel()
        emptyLabel.text = "No messages yet\nSay hello!"
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.font = .preferredFont(forTextStyle: .title3)
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        
        messagesCollectionView.backgroundView = emptyLabel
        emptyLabel.accessibilityLabel = "No messages yet. Say hello!"
    }
}

// MARK: - Sender Helper

struct Sender: SenderType {
    var senderId: String
    var displayName: String
}

// MARK: - Preview

struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ChatView(
                viewModel: DIContainer.shared.makeChatViewModel(
                    conversationId: "preview-conv",
                    currentUserId: "preview-user"
                )
            )
        }
    }
}

