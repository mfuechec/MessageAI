import SwiftUI
import MessageKit
import InputBarAccessoryView
import Kingfisher

/// Main chat view displaying messages for a conversation
struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    @State private var conversationTitle: String = "Chat"
    @State private var showGroupMemberList = false
    @State private var showFailedMessageAlert = false
    @State private var selectedFailedMessage: Message?
    
    // Toast notification state
    @State private var showReconnectedToast = false
    
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
            VStack(spacing: 0) {
                MessageKitWrapper(viewModel: viewModel, conversationTitle: $conversationTitle)
                    .edgesIgnoringSafeArea(.bottom)

                // Typing indicator (shows above input bar)
                TypingIndicatorView(typingUserNames: viewModel.typingUserNames)
            }

            // Only show loading overlay if we DON'T have initial data
            // (i.e., when opening conversation without cached data)
            if viewModel.isLoading && !viewModel.isSending && initialConversation == nil {
                // Loading state - only shown when no cached data available
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
            }
            
            // Toast notifications
            VStack {
                if viewModel.isOffline {
                    offlineToast
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                if showReconnectedToast {
                    reconnectedToast
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                Spacer()
            }
            .animation(.spring(response: 0.3), value: viewModel.isOffline)
            .animation(.spring(response: 0.3), value: showReconnectedToast)
            
            // Edit mode overlay
            if viewModel.isEditingMessage {
                editModeOverlay
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: viewModel.isOffline) { newValue in
            print("🔴 [ChatView] onChange fired: isOffline=\(newValue)")
            
            if !newValue {
                // Reconnected - show reconnected toast briefly
                print("   → Showing reconnected toast")
                showReconnectedToast = true
                
                // Auto-dismiss reconnected toast after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    print("   → Auto-dismissing reconnected toast")
                    showReconnectedToast = false
                }
            } else {
                // Went offline - hide reconnected toast if showing
                showReconnectedToast = false
            }
        }
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
        .sheet(item: $viewModel.readReceiptTapped) { message in
            ReadReceiptDetailView(
                message: message,
                participants: viewModel.participants,
                currentUserId: viewModel.currentUserId
            )
        }
        // Delete Confirmation Alert
        .alert("Delete this message for everyone?", isPresented: $viewModel.showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                viewModel.cancelDelete()
            }
            .accessibilityLabel("Cancel deletion")
            
            Button("Delete for Everyone", role: .destructive) {
                Task {
                    await viewModel.confirmDelete()
                }
            }
            .accessibilityLabel("Delete message for everyone")
        } message: {
            Text("This message will be deleted for all participants. This action cannot be undone.")
        }
        // Failed Message Alert
        .alert("Message Failed", isPresented: $showFailedMessageAlert, presenting: selectedFailedMessage) { message in
            Button("Retry", role: .none) {
                Task {
                    await viewModel.retryMessage(message)
                }
            }
            Button("Delete", role: .destructive) {
                viewModel.deleteFailedMessage(message)
            }
            Button("Cancel", role: .cancel) {}
        } message: { message in
            Text("This message failed to send. Would you like to retry or delete it?")
        }
        .onChange(of: viewModel.failedMessageTapped) { message in
            if let message = message {
                selectedFailedMessage = message
                showFailedMessageAlert = true
                viewModel.failedMessageTapped = nil  // Clear
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
        // Image Picker Sheet
        .sheet(isPresented: $viewModel.isImagePickerPresented) {
            ImagePicker(selectedImage: $viewModel.selectedImage)
        }
        .onChange(of: viewModel.selectedImage) { oldValue, newValue in
            if let image = newValue {
                viewModel.sendImageMessage(image: image)
                viewModel.selectedImage = nil  // Clear after sending
            }
        }
        // Document Picker Sheet
        .sheet(isPresented: $viewModel.isDocumentPickerPresented) {
            DocumentPickerView(
                selectedDocumentURL: $viewModel.selectedDocumentURL,
                onDismiss: { viewModel.isDocumentPickerPresented = false }
            )
        }
        .onChange(of: viewModel.selectedDocumentURL) { oldValue, newValue in
            if let fileURL = newValue {
                viewModel.sendDocumentMessage(fileURL: fileURL)
                viewModel.selectedDocumentURL = nil  // Clear after sending
            }
        }
        // QuickLook Document Preview
        .sheet(isPresented: $viewModel.showDocumentPreview) {
            if let url = viewModel.documentPreviewURL {
                QuickLookPreview(fileURL: url, onDismiss: {
                    viewModel.showDocumentPreview = false
                })
            }
        }
        .onAppear {
            // Track that user is viewing this conversation (for notification suppression)
            viewModel.onAppear()
            
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
        .onDisappear {
            // Clear conversation tracking when user leaves (allows notifications again)
            viewModel.onDisappear()
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
    
    private var offlineToast: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.caption)
            Text("You're offline")
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.orange)
        )
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .padding(.top, 8)
        .accessibilityLabel("Offline mode")
    }
    
    private var reconnectedToast: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi")
                .font(.caption)
            Text("Back online")
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.green)
        )
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .padding(.top, 8)
        .accessibilityLabel("Back online")
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
        context.coordinator.messagesCollectionView = vc.messagesCollectionView
        
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
        weak var messagesCollectionView: MessagesCollectionView?

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
            // Check if message is deleted
            if let messageKitMessage = message as? MessageKitMessage, messageKitMessage.isDeleted {
                return .secondaryLabel // Gray color for deleted messages
            }
            
            return isFromCurrentSender(message: message) ? .white : .label
        }
        
        func configureMessageLabel(_ label: UILabel, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
            // Apply italic font for deleted messages
            if let messageKitMessage = message as? MessageKitMessage, messageKitMessage.isDeleted {
                label.font = UIFont.italicSystemFont(ofSize: 15)
            } else {
                label.font = UIFont.systemFont(ofSize: 15)
            }
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
            
            // Only show read receipts for current user's messages (AC #2)
            if isCurrentUser {
                let statusText: String
                let statusColor: UIColor

                // Special handling for .read status in group chats (AC #6)
                if actualMessage.status == .read && viewModel.isGroupConversation {
                    // Calculate read count (exclude sender from denominator)
                    let totalParticipants = viewModel.participants.count - 1 // Exclude sender
                    let readCount = actualMessage.readBy.count
                    statusText = "✓✓ Read by \(readCount) of \(totalParticipants)"
                    statusColor = .systemBlue
                } else {
                    // Use standard status icons for non-group or non-read messages
                    (statusText, statusColor) = statusIconAndColor(for: actualMessage.status)
                }

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

        func configureMediaMessageImageView(_ imageView: UIImageView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
            guard let messageKitMessage = message as? MessageKitMessage,
                  case .photo(let mediaItem) = messageKitMessage.kind,
                  let url = mediaItem.url else {
                return
            }

            // Use Kingfisher for async image loading
            imageView.kf.setImage(
                with: url,
                placeholder: UIImage(systemName: "photo"),
                options: [
                    .transition(.fade(0.2)),
                    .cacheOriginalImage
                ]
            )

            // Show upload progress overlay if uploading
            if let domainMessage = viewModel.messages[safe: indexPath.section],
               let progress = viewModel.uploadProgress[domainMessage.id] {
                addProgressOverlay(to: imageView, progress: progress)
            }
        }

        func didTapImage(in cell: MessageCollectionViewCell) {
            guard let collectionView = messagesCollectionView,
                  let indexPath = collectionView.indexPath(for: cell),
                  let message = viewModel.messages[safe: indexPath.section],
                  let attachment = message.attachments.first else {
                return
            }

            // TODO: Open full-screen image viewer
            print("📷 Tapped image: \(attachment.url)")
        }

        // Configure custom cells (for document messages)
        func configureCustomCell(_ cell: UICollectionViewCell, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
            guard let messageKitMessage = message as? MessageKitMessage,
                  case .custom(let mediaItem) = messageKitMessage.kind,
                  let documentItem = mediaItem as? DocumentMediaItem,
                  let domainMessage = viewModel.messages[safe: indexPath.section] else {
                return
            }

            // Remove existing subviews
            cell.contentView.subviews.forEach { $0.removeFromSuperview() }

            // Check for upload progress
            let progress = viewModel.uploadProgress[domainMessage.id]
            let error = viewModel.uploadErrors[domainMessage.id]

            // Create DocumentCardView wrapped in UIHostingController
            let documentCard = DocumentCardView(
                fileName: documentItem.fileName,
                fileSizeBytes: documentItem.sizeBytes,
                uploadProgress: progress,
                hasError: error != nil,
                onTap: {
                    Task { @MainActor in
                        if error != nil {
                            // Retry upload
                            self.viewModel.retryDocumentUpload(messageId: domainMessage.id)
                        } else if let url = documentItem.url {
                            // Open QuickLook preview
                            self.viewModel.documentPreviewURL = url
                            self.viewModel.showDocumentPreview = true
                        }
                    }
                },
                onRetry: error != nil ? {
                    Task { @MainActor in
                        self.viewModel.retryDocumentUpload(messageId: domainMessage.id)
                    }
                } : nil
            )

            let hostingController = UIHostingController(rootView: documentCard)
            hostingController.view.backgroundColor = .clear
            hostingController.view.translatesAutoresizingMaskIntoConstraints = false

            cell.contentView.addSubview(hostingController.view)

            NSLayoutConstraint.activate([
                hostingController.view.topAnchor.constraint(equalTo: cell.contentView.topAnchor),
                hostingController.view.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor),
                hostingController.view.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor),
                hostingController.view.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor)
            ])
        }

        private func addProgressOverlay(to imageView: UIImageView, progress: Double) {
            // Remove existing overlay
            imageView.subviews.forEach { $0.removeFromSuperview() }

            // Create progress view
            let overlayView = UIView(frame: imageView.bounds)
            overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.5)

            let progressView = UIProgressView(progressViewStyle: .default)
            progressView.progress = Float(progress)
            progressView.translatesAutoresizingMaskIntoConstraints = false

            overlayView.addSubview(progressView)
            imageView.addSubview(overlayView)

            NSLayoutConstraint.activate([
                progressView.centerXAnchor.constraint(equalTo: overlayView.centerXAnchor),
                progressView.centerYAnchor.constraint(equalTo: overlayView.centerYAnchor),
                progressView.widthAnchor.constraint(equalTo: overlayView.widthAnchor, multiplier: 0.6)
            ])
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
        
        func inputBar(_ inputBar: InputBarAccessoryView, textViewTextDidChangeTo text: String) {
            // Auto-enable send button when there's text
            inputBar.sendButton.isEnabled = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

            // Trigger typing indicator when text changes
            if !text.isEmpty {
                viewModel.startTyping()
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
                return ("⚠️ Failed - Tap to retry", .systemRed)
            case .queued:
                return ("⏳ Queued", .secondaryLabel)
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
        
        // Auto-focus text input for immediate typing
        messageInputBar.inputTextView.becomeFirstResponder()
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
        
        // Enable tap gesture for quick edit (tap to edit)
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleMessageTap(_:)))
        messagesCollectionView.addGestureRecognizer(tapGesture)
        
        // Enable swipe actions for delete
        let swipeGesture = UISwipeGestureRecognizer(target: self, action: #selector(handleMessageSwipe(_:)))
        swipeGesture.direction = .left
        messagesCollectionView.addGestureRecognizer(swipeGesture)
        
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
        
        // Check if this is a tap on read receipt in group chat (AC #7)
        if viewModel.isGroupConversation && 
           message.status == .read &&
           message.senderId == viewModel.currentUserId {
            
            // Get the cell to check if tap is in bottom label area (read receipt)
            if let cell = messagesCollectionView.cellForItem(at: indexPath) as? MessageContentCell {
                let cellTouchPoint = gesture.location(in: cell)
                let cellHeight = cell.bounds.height
                
                // Check if tap is in bottom 30 points (where read receipt is)
                if cellTouchPoint.y > cellHeight - 30 {
                    print("👆 Tapped read receipt for group message: \(message.id)")
                    Task { @MainActor in
                        viewModel.onReadReceiptTapped(message)
                    }
                    return
                }
            }
        }
        
        // Only allow actions on own messages
        guard message.senderId == viewModel.currentUserId else {
            return
        }
        
        // Check if this is a failed message - handle retry/delete
        if message.status == .failed {
            print("⚠️ Tapped failed message: \(message.id)")
            Task { @MainActor in
                viewModel.onFailedMessageTapped(message)
            }
            return
        }
        
        print("👆 Tapped own message to edit: \(message.id)")
        
        // Open edit mode
        Task { @MainActor in
            viewModel.startEdit(message: message)
        }
    }
    
    @objc private func handleMessageSwipe(_ gesture: UISwipeGestureRecognizer) {
        let touchPoint = gesture.location(in: messagesCollectionView)
        
        // Find which cell was swiped
        guard let indexPath = messagesCollectionView.indexPathForItem(at: touchPoint),
              let viewModel = viewModel else {
            return
        }
        
        print("👈 Swiped message at section: \(indexPath.section)")
        
        // Get the domain message
        guard indexPath.section < viewModel.messages.count else { return }
        let domainMessage = viewModel.messages[indexPath.section]
        
        // Check if message can be deleted
        guard viewModel.canDelete(message: domainMessage) else {
            print("⚠️ Cannot delete this message")
            return
        }
        
        // Show delete confirmation immediately
        Task { @MainActor in
            viewModel.showDeleteConfirmation(for: domainMessage)
        }
    }
    
    private func configureMessageInputBar() {
        messageInputBar.backgroundView.backgroundColor = .systemGroupedBackground
        messageInputBar.inputTextView.placeholder = "Message"
        messageInputBar.sendButton.setTitle("Send", for: .normal)
        messageInputBar.sendButton.setTitleColor(.systemBlue, for: .normal)

        // Send message on Enter key (instead of newline)
        messageInputBar.inputTextView.keyboardType = .default
        messageInputBar.inputTextView.returnKeyType = .send
        messageInputBar.inputTextView.delegate = self

        // Override default behavior to send on Enter
        messageInputBar.shouldManageSendButtonEnabledState = true
        messageInputBar.inputTextView.textContainerInset = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)

        // Add attachment button (paperclip icon) with menu
        let attachmentButton = InputBarButtonItem()
        attachmentButton.setSize(CGSize(width: 36, height: 36), animated: false)
        attachmentButton.setImage(UIImage(systemName: "paperclip"), for: .normal)
        attachmentButton.tintColor = .systemBlue

        // Create menu with Photo and Document options
        if #available(iOS 14.0, *) {
            let photoAction = UIAction(title: "Photo", image: UIImage(systemName: "photo")) { [weak self] _ in
                self?.viewModel?.selectImage()
            }
            let documentAction = UIAction(title: "Document", image: UIImage(systemName: "doc")) { [weak self] _ in
                self?.viewModel?.selectDocument()
            }
            let menu = UIMenu(title: "", children: [photoAction, documentAction])
            attachmentButton.menu = menu
            attachmentButton.showsMenuAsPrimaryAction = true
        } else {
            // Fallback for iOS 13 - just open image picker
            attachmentButton.onTouchUpInside { [weak self] _ in
                self?.viewModel?.selectImage()
            }
        }

        messageInputBar.setLeftStackViewWidthConstant(to: 36, animated: false)
        messageInputBar.setStackViewItems([attachmentButton], forStack: .left, animated: false)

        // Accessibility
        messageInputBar.inputTextView.accessibilityLabel = "Message input"
        messageInputBar.inputTextView.accessibilityHint = "Enter your message"
        messageInputBar.sendButton.accessibilityLabel = "Send message"
        attachmentButton.accessibilityLabel = "Attach photo or document"
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

// MARK: - UITextViewDelegate (for Enter key handling)

extension CustomMessagesViewController: UITextViewDelegate {
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        // Check if Enter/Return key was pressed
        if text == "\n" {
            // Trigger send button if there's text
            let currentText = textView.text ?? ""
            if !currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                messageInputBar.sendButton.sendActions(for: .touchUpInside)
            }
            return false // Prevent newline insertion
        }
        return true
    }
}

// MARK: - Sender Helper

struct Sender: SenderType {
    var senderId: String
    var displayName: String
}

// MARK: - Array Extension

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
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

