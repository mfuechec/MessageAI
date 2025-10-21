import SwiftUI
import MessageKit
import InputBarAccessoryView

/// Main chat view displaying messages for a conversation
struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    @State private var conversationTitle: String = "Chat"
    @State private var showGroupMemberList = false
    
    // Optional initial data to avoid loading delay
    let initialConversation: Conversation?
    let initialParticipants: [User]?
    
    init(viewModel: ChatViewModel, initialConversation: Conversation? = nil, initialParticipants: [User]? = nil) {
        self.viewModel = viewModel
        self.initialConversation = initialConversation
        self.initialParticipants = initialParticipants
    }
    
    var body: some View {
        ZStack {
            // Always show content (MessageKit handles empty state)
            MessageKitWrapper(viewModel: viewModel, conversationTitle: $conversationTitle)
                .edgesIgnoringSafeArea(.bottom)
            
            // Only show loading overlay if we DON'T have initial data
            // (i.e., when opening conversation without cached data)
            if viewModel.isLoading && !viewModel.isSending && initialConversation == nil {
                // Loading state - only shown when no cached data available
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
            }
            
            // Offline banner
            if viewModel.isOffline {
                VStack {
                    offlineBanner
                    Spacer()
                }
            }
            
            // Edit mode overlay
            if viewModel.isEditingMessage {
                editModeOverlay
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                if viewModel.isGroupConversation {
                    // Group: Tappable title to show member list
                    Button(action: {
                        showGroupMemberList = true
                    }) {
                        Text(conversationTitle)
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    .accessibilityLabel("Group members: \(conversationTitle)")
                    .accessibilityHint("Tap to view group member list")
                } else {
                    // One-on-one: Just show title
                    Text(conversationTitle)
                        .font(.headline)
                }
            }
        }
        .sheet(isPresented: $showGroupMemberList) {
            GroupMemberListView(participants: viewModel.participants)
        }
        .sheet(isPresented: $viewModel.showEditHistoryModal) {
            if let message = viewModel.editHistoryMessage {
                EditHistoryView(message: message)
            }
        }
        // Error Alert
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
        .onAppear {
            // Set title immediately from initial data if available
            if let conversation = initialConversation, let participants = initialParticipants {
                setTitle(conversation: conversation, participants: participants)
            } else {
                updateConversationTitle()
            }
        }
        .onChange(of: viewModel.conversation) { _ in
            updateConversationTitle()
        }
        .onChange(of: viewModel.participants) { _ in
            updateConversationTitle()
        }
    }
    
    private var offlineBanner: some View {
        HStack {
            Image(systemName: "wifi.slash")
            Text("You're offline. Messages will send when connected.")
                .font(.subheadline)
        }
        .foregroundColor(.white)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color.orange)
        .accessibilityLabel("You are offline. Messages will send when connected.")
    }
    
    private var editModeOverlay: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 12) {
                HStack {
                    Text("Edit Message")
                        .font(.headline)
                    Spacer()
                    Button("Cancel") {
                        viewModel.cancelEdit()
                    }
                    .accessibilityLabel("Cancel editing")
                }
                
                TextEditor(text: $viewModel.editingMessageText)
                    .frame(minHeight: 100, maxHeight: 200)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .accessibilityLabel("Edit message text")
                
                HStack {
                    Spacer()
                    Button("Save") {
                        Task {
                            await viewModel.saveEdit()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.editingMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel("Save edited message")
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(radius: 10)
            .padding()
        }
        .background(Color.black.opacity(0.3))
        .transition(.move(edge: .bottom))
        .animation(.spring(), value: viewModel.isEditingMessage)
    }
    
    private func updateConversationTitle() {
        guard let conversation = viewModel.conversation else {
            conversationTitle = "Chat"
            return
        }
        setTitle(conversation: conversation, participants: viewModel.participants)
    }
    
    private func setTitle(conversation: Conversation, participants: [User]) {
        if conversation.isGroup {
            // Group chat: Show participant names or count (excluding current user)
            // Filter by checking if user ID matches the current user ID
            let currentUserId = viewModel.currentUserId
            let otherParticipants = participants.filter { $0.id != currentUserId }
            
            if otherParticipants.isEmpty {
                conversationTitle = "Group Chat"
            } else if otherParticipants.count <= 3 {
                conversationTitle = otherParticipants.map { $0.truncatedDisplayName }.joined(separator: ", ")
            } else {
                // Show first 2 names + count of others
                let firstTwo = otherParticipants.prefix(2).map { $0.truncatedDisplayName }
                let remaining = otherParticipants.count - 2
                conversationTitle = "\(firstTwo.joined(separator: ", ")) & \(remaining) other\(remaining == 1 ? "" : "s")"
            }
        } else {
            // One-on-one: Show other person's name
            let currentUserId = viewModel.currentUserId
            let otherUser = participants.first { $0.id != currentUserId }
            conversationTitle = otherUser?.truncatedDisplayName ?? "Chat"
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
        
        // Initialize messageCount to current count to prevent 0 -> N flash
        vc.messageCount = viewModel.messages.count
        print("🏗️ [ChatView] Created with \(vc.messageCount) messages")
        
        return vc
    }
    
    func updateUIViewController(_ uiViewController: CustomMessagesViewController, context: Context) {
        // SwiftUI calls this MANY times (on any @Published change in viewModel)
        // Only act if message count actually changed OR messages were edited
        let currentCount = uiViewController.messageCount
        let newCount = viewModel.messages.count
        
        // Check if we need to force refresh (e.g., message edited, count unchanged)
        if viewModel.messagesNeedRefresh {
            print("📱 [ChatView] Forcing reload due to message edit")
            uiViewController.messagesCollectionView.reloadData()
            
            // Reset flag OUTSIDE view update context to avoid SwiftUI warning
            DispatchQueue.main.async {
                viewModel.messagesNeedRefresh = false
            }
            return
        }
        
        // Skip if count hasn't changed (prevents flickering from redundant updates)
        guard currentCount != newCount else {
            // Silent skip - don't log spam
            return
        }
        
        print("📱 [ChatView] Message count changed: \(currentCount) -> \(newCount)")
        
        let oldCount = currentCount
        uiViewController.messageCount = newCount
        
        // Handle empty state transition ONCE
        let wasEmpty = oldCount == 0
        let isEmpty = newCount == 0
        
        if wasEmpty && !isEmpty {
            // Transitioning from empty to first message
            print("  ➡️ Empty -> Has messages: hiding empty state")
            uiViewController.hideEmptyState()
            uiViewController.messagesCollectionView.reloadData()
            
            // Scroll to bottom to show latest messages on initial load
            DispatchQueue.main.async {
                print("  ⬇️ Scrolling to latest message (initial load)")
                uiViewController.messagesCollectionView.scrollToLastItem(animated: false)
            }
        } else if !wasEmpty && isEmpty {
            // Transitioning from messages to empty
            print("  ➡️ Has messages -> Empty: showing empty state")
            uiViewController.messagesCollectionView.reloadData()
            uiViewController.showEmptyState()
        } else if newCount > oldCount {
            // New messages added - use performBatchUpdates for smooth animation
            print("  ➕ Adding \(newCount - oldCount) new message(s)")
            uiViewController.messagesCollectionView.performBatchUpdates({
                uiViewController.messagesCollectionView.insertSections(IndexSet(oldCount..<newCount))
            }, completion: nil)
            
            // Auto-scroll to bottom if appropriate
            let shouldScroll = context.coordinator.isNearBottom || 
                              (viewModel.messages.last?.senderId == viewModel.currentUserId)
            if shouldScroll {
                DispatchQueue.main.async {
                    uiViewController.messagesCollectionView.scrollToLastItem(animated: true)
                }
            }
        } else {
            // Messages modified or removed - full reload
            print("  🔄 Messages modified/removed: full reload")
            uiViewController.messagesCollectionView.reloadData()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, MessagesDataSource, MessagesLayoutDelegate, MessagesDisplayDelegate, InputBarAccessoryViewDelegate {
        let viewModel: ChatViewModel
        var isNearBottom: Bool = true
        
        // Image cache: [userId: downloadedImage]
        private var avatarImageCache: [String: UIImage] = [:]
        
        init(viewModel: ChatViewModel) {
            self.viewModel = viewModel
            super.init()
        }
        
        // MARK: - MessagesDataSource
        
        var currentSender: SenderType {
            // CRITICAL: MessageKit uses senderId to determine message alignment
            // Messages from currentSender appear on RIGHT (blue background)
            // Messages from others appear on LEFT (gray background)
            return Sender(senderId: viewModel.currentUserId, displayName: "You")
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
            let actualMessage = viewModel.messages[indexPath.section]
            let senderId = actualMessage.senderId  // Use actual message sender ID
            
            // Don't show avatar for current user's messages
            if senderId == viewModel.currentUserId {
                avatarView.isHidden = true
                return
            }
            
            avatarView.isHidden = false
            
            // Get sender user from viewModel.users dictionary
            guard let senderUser = viewModel.users[senderId] else {
                print("⚠️ Unknown user for senderId: \(senderId)")
                avatarView.set(avatar: Avatar(image: nil, initials: "?"))
                return
            }
            
            let initials = senderUser.displayInitials
            print("👤 Configuring avatar for \(senderUser.displayName) (senderId: \(senderId))")
            
            // Check if we have a cached image for this user
            if let cachedImage = avatarImageCache[senderId] {
                print("✅ Using cached image for \(senderUser.displayName)")
                let avatarWithIndicator = createAvatarWithPresenceIndicator(cachedImage, user: senderUser)
                avatarView.set(avatar: Avatar(image: avatarWithIndicator, initials: initials))
                return
            }
            
            // Try to load profile image
            if let photoURLString = senderUser.profileImageURL,
               !photoURLString.isEmpty,
               let photoURL = URL(string: photoURLString) {
                print("🖼️ Loading profile image for \(senderUser.displayName): \(photoURLString)")
                
                // Set initials immediately as placeholder
                avatarView.set(avatar: Avatar(image: createAvatarWithPresenceIndicator(nil, user: senderUser), initials: initials))
                
                // Download image asynchronously
                Task {
                    do {
                        let (data, _) = try await URLSession.shared.data(from: photoURL)
                        if let downloadedImage = UIImage(data: data) {
                            print("✅ Profile image downloaded for \(senderUser.displayName)")
                            
                            // Cache the image
                            await MainActor.run {
                                self.avatarImageCache[senderId] = downloadedImage
                            }
                            
                            let avatarWithIndicator = createAvatarWithPresenceIndicator(downloadedImage, user: senderUser)
                            await MainActor.run {
                                avatarView.set(avatar: Avatar(image: avatarWithIndicator, initials: initials))
                            }
                        } else {
                            print("❌ Failed to create UIImage from data for \(senderUser.displayName)")
                            await MainActor.run {
                                avatarView.set(avatar: Avatar(image: createAvatarWithPresenceIndicator(nil, user: senderUser), initials: initials))
                            }
                        }
                    } catch {
                        print("❌ Profile image download failed for \(senderUser.displayName): \(error)")
                        await MainActor.run {
                            avatarView.set(avatar: Avatar(image: createAvatarWithPresenceIndicator(nil, user: senderUser), initials: initials))
                        }
                    }
                }
            } else {
                print("ℹ️ No profile image for \(senderUser.displayName), showing initials with presence indicator")
                // No photo URL, show initials with presence indicator
                avatarView.set(avatar: Avatar(image: createAvatarWithPresenceIndicator(nil, user: senderUser), initials: initials))
            }
        }
        
        /// Create avatar image with presence indicator overlay
        /// - Parameters:
        ///   - baseImage: The profile image (or nil to generate initials)
        ///   - user: The user whose presence status to show
        /// - Returns: An image with a presence indicator dot
        func createAvatarWithPresenceIndicator(_ baseImage: UIImage?, user: User) -> UIImage? {
            let size = CGSize(width: 30, height: 30)
            let indicatorSize: CGFloat = 10
            
            let renderer = UIGraphicsImageRenderer(size: size)
            return renderer.image { context in
                // Draw base image or initials
                if let baseImage = baseImage {
                    // Draw profile image
                    baseImage.draw(in: CGRect(origin: .zero, size: size))
                } else {
                    // Draw initials background circle
                    let bgColor = UIColor.systemBlue
                    bgColor.setFill()
                    let bgPath = UIBezierPath(ovalIn: CGRect(origin: .zero, size: size))
                    bgPath.fill()
                    
                    // Draw initials text
                    let initials = user.displayInitials
                    let attributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
                        .foregroundColor: UIColor.white
                    ]
                    let textSize = (initials as NSString).size(withAttributes: attributes)
                    let textRect = CGRect(
                        x: (size.width - textSize.width) / 2,
                        y: (size.height - textSize.height) / 2,
                        width: textSize.width,
                        height: textSize.height
                    )
                    (initials as NSString).draw(in: textRect, withAttributes: attributes)
                }
                
                // Draw presence indicator
                let status = user.presenceStatus
                let rgb = status.color
                let presenceColor = UIColor(red: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 1.0)
                
                let indicatorRect = CGRect(
                    x: size.width - indicatorSize - 2,
                    y: size.height - indicatorSize - 2,
                    width: indicatorSize,
                    height: indicatorSize
                )
                
                // Draw white border
                UIColor.white.setFill()
                let borderPath = UIBezierPath(ovalIn: indicatorRect.insetBy(dx: -1, dy: -1))
                borderPath.fill()
                
                // Draw presence indicator
                presenceColor.setFill()
                let indicatorPath = UIBezierPath(ovalIn: indicatorRect)
                indicatorPath.fill()
            }
        }
        
        func messageTopLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
            // Show sender name for incoming messages in group chats
            if isFromCurrentSender(message: message) {
                return nil
            }
            
            // Only show sender name in group chats
            guard viewModel.isGroupConversation else {
                return nil
            }
            
            let actualMessage = viewModel.messages[indexPath.section]
            let senderName = viewModel.getSenderName(for: actualMessage.senderId)
            
            return NSAttributedString(
                string: senderName,
                attributes: [
                    .font: UIFont.preferredFont(forTextStyle: .caption1),
                    .foregroundColor: UIColor.secondaryLabel
                ]
            )
        }
        
        func messageBottomLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
            let actualMessage = viewModel.messages[indexPath.section]
            let timestamp = viewModel.formattedTimestamp(for: actualMessage)
            let isCurrentUser = actualMessage.senderId == viewModel.currentUserId
            
            // Create the attributed string starting with edited indicator if applicable
            let result = NSMutableAttributedString()
            
            // Add "(edited)" indicator if message was edited
            if actualMessage.isEdited {
                let editedString = NSAttributedString(
                    string: "(edited) ",
                    attributes: [
                        .font: UIFont.preferredFont(forTextStyle: .caption2),
                        .foregroundColor: UIColor.secondaryLabel
                    ]
                )
                result.append(editedString)
            }
            
            // Add timestamp
            let timestampString = NSAttributedString(
                string: timestamp,
                attributes: [
                    .font: UIFont.preferredFont(forTextStyle: .caption2),
                    .foregroundColor: UIColor.secondaryLabel
                ]
            )
            result.append(timestampString)
            
            // Only show read receipts for current user's messages
            if isCurrentUser {
                // Get status icon and color
                let (statusText, statusColor) = statusIconAndColor(for: actualMessage.status)
                
                // Add status icon with appropriate color
                let statusString = NSAttributedString(
                    string: " " + statusText,
                    attributes: [
                        .font: UIFont.preferredFont(forTextStyle: .caption2),
                        .foregroundColor: statusColor
                    ]
                )
                
                result.append(statusString)
            }
            
            return result
        }
        
        // MARK: - MessagesLayoutDelegate
        
        func messageTopLabelHeight(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
            // Show sender name in group chats for incoming messages
            if isFromCurrentSender(message: message) {
                return 0
            }
            return viewModel.isGroupConversation ? 16 : 0
        }
        
        func messageBottomLabelHeight(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
            return 16
        }
        
        func messageBottomLabelAlignment(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> LabelAlignment {
            // Right-align bottom label (timestamp + status) for current user's messages
            // Left-align for incoming messages
            return isFromCurrentSender(message: message) ? LabelAlignment(textAlignment: .right, textInsets: UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 8)) : LabelAlignment(textAlignment: .left, textInsets: UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 0))
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
        
        /// Returns the status icon and its color
        /// - sent: single gray checkmark ✓
        /// - delivered: double gray checkmark ✓✓
        /// - read: double blue checkmark ✓✓
        private func statusIconAndColor(for status: MessageStatus) -> (String, UIColor) {
            switch status {
            case .sending:
                return ("●", .secondaryLabel)
            case .sent:
                return ("✓", .secondaryLabel)
            case .delivered:
                return ("✓✓", .secondaryLabel)
            case .read:
                return ("✓✓", .systemBlue)
            case .failed:
                return ("⚠", .systemRed)
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
        
        // Show empty state ONLY if truly empty at load time
        if viewModel?.messages.isEmpty == true {
            print("📭 [CustomMessagesViewController] No messages, showing empty state")
            showEmptyState()
        } else {
            print("💬 [CustomMessagesViewController] \(viewModel?.messages.count ?? 0) messages, hiding empty state")
            hideEmptyState()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Scroll to bottom on initial load to show latest messages
        if let viewModel = viewModel, !viewModel.messages.isEmpty {
            print("⬇️ [CustomMessagesViewController] Scrolling to latest message")
            messagesCollectionView.scrollToLastItem(animated: false)
        }
    }
    
    private func configureMessageCollectionView() {
        messagesCollectionView.backgroundColor = .systemBackground
        
        // Configure avatar sizes
        if let layout = messagesCollectionView.collectionViewLayout as? MessagesCollectionViewFlowLayout {
            let avatarSize = CGSize(width: 30, height: 30)
            layout.textMessageSizeCalculator.outgoingAvatarSize = .zero  // No avatar for outgoing
            layout.textMessageSizeCalculator.incomingAvatarSize = avatarSize
            layout.setMessageIncomingAvatarSize(avatarSize)
            layout.setMessageOutgoingAvatarSize(.zero)
            
            // Enable top label for sender names in group chats
            layout.setMessageIncomingMessageTopLabelAlignment(LabelAlignment(textAlignment: .left, textInsets: UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 0)))
        }
        
        // Enable tap gesture for message selection (needed for didTapMessage to work)
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleMessageTap(_:)))
        messagesCollectionView.addGestureRecognizer(tapGesture)
        
        // Accessibility
        messagesCollectionView.isAccessibilityElement = false
        messagesCollectionView.shouldGroupAccessibilityChildren = true
    }
    
    @objc private func handleMessageTap(_ gesture: UITapGestureRecognizer) {
        let touchPoint = gesture.location(in: messagesCollectionView)
        
        // Find which cell was tapped
        guard let indexPath = messagesCollectionView.indexPathForItem(at: touchPoint),
              let viewModel = viewModel else {
            return
        }
        
        let message = viewModel.messages[indexPath.section]
        
        // Only allow editing own messages
        guard message.senderId == viewModel.currentUserId else {
            return
        }
        
        print("👆 Tapped own message to edit: \(message.id)")
        
        // Open edit mode
        Task { @MainActor in
            viewModel.startEdit(message: message)
        }
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
    
    func showEmptyState() {
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
    
    func hideEmptyState() {
        messagesCollectionView.backgroundView = nil
    }
    
    // Note: MessageKit handles taps via didTapMessage delegate method in Coordinator
    // Custom tap handling is done there
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

