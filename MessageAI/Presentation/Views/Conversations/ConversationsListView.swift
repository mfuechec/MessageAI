import SwiftUI

/// Wrapper to keep ChatViewModel and Conversation in sync
struct ChatContext: Identifiable {
    let id: String
    let conversation: Conversation
    let chatViewModel: ChatViewModel
    let participants: [User]
    
    init(conversation: Conversation, chatViewModel: ChatViewModel, participants: [User]) {
        self.id = conversation.id
        self.conversation = conversation
        self.chatViewModel = chatViewModel
        self.participants = participants
    }
}

/// Main view for displaying user's conversations list
struct ConversationsListView: View {
    @StateObject var viewModel: ConversationsListViewModel
    @State private var showNewConversation = false
    @StateObject private var newConversationViewModel: NewConversationViewModel
    @EnvironmentObject private var authViewModel: AuthViewModel
    
    // Toast notification state
    @State private var showReconnectedToast = false
    
    // CRITICAL: Use single state object to prevent desynchronization
    @State private var chatContext: ChatContext? {
        didSet {
            if let context = chatContext {
                print("🟢 [State] chatContext set for conversation: \(context.id)")
                print("  📊 ChatViewModel has \(context.chatViewModel.messages.count) messages")
            } else {
                print("🔴 [State] chatContext cleared")
            }
        }
    }
    
    init(viewModel: ConversationsListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _newConversationViewModel = StateObject(wrappedValue: DIContainer.shared.makeNewConversationViewModel())
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                if viewModel.isLoading && viewModel.conversations.isEmpty {
                    // Loading state
                    ProgressView("Loading conversations...")
                        .accessibilityLabel("Loading conversations")
                } else if viewModel.conversations.isEmpty {
                    // Empty state
                    emptyStateView
                } else {
                    // Conversations list
                    conversationsList
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
            }
            .navigationTitle("Messages")
            .onChange(of: viewModel.isOffline) { newValue in
                if !newValue {
                    // Reconnected - show reconnected toast briefly
                    showReconnectedToast = true
                    
                    // Auto-dismiss reconnected toast after 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showReconnectedToast = false
                    }
                } else {
                    // Went offline - hide reconnected toast if showing
                    showReconnectedToast = false
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Logout") {
                        Task {
                            await authViewModel.signOut()
                        }
                    }
                    .accessibilityLabel("Logout")
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showNewConversation = true
                    }) {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("New Message")
                }
            }
            .sheet(isPresented: $showNewConversation) {
                NewConversationView(
                    viewModel: newConversationViewModel,
                    onConversationSelected: { _ in }  // Not used, parent observes ViewModel
                )
            }
            .onChange(of: newConversationViewModel.selectedConversation) { conversation in
                // Parent observes the ViewModel directly (more reliable than child onChange)
                if let conversation = conversation {
                    print("📱 Parent detected conversation selection: \(conversation.id)")
                    
                    // Get participants from users dictionary (single source of truth)
                    let participants = viewModel.getParticipants(for: conversation)
                    print("✅ Found \(participants.count)/\(conversation.participantIds.count) participants")
                    
                    // Create ChatViewModel with participant data
                    let chatVM = DIContainer.shared.makeChatViewModel(
                        conversationId: conversation.id,
                        currentUserId: authViewModel.currentUser?.id ?? "",
                        initialConversation: conversation,
                        initialParticipants: participants
                    )
                    print("✅ ChatViewModel created for new conversation")
                    
                    // Dismiss new conversation sheet
                    showNewConversation = false
                    
                    // Wait for dismissal animation, then open chat
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        print("🚀 Opening chat sheet for conversation: \(conversation.id)")
                        chatContext = ChatContext(
                            conversation: conversation,
                            chatViewModel: chatVM,
                            participants: participants
                        )
                        // Reset for next time
                        newConversationViewModel.selectedConversation = nil
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenConversation"))) { notification in
                // Deep linking from push notification tap
                if let conversationId = notification.userInfo?["conversationId"] as? String {
                    print("📲 Deep link notification received for conversation: \(conversationId)")
                    
                    // Find conversation in current list
                    if let conversation = viewModel.conversations.first(where: { $0.id == conversationId }) {
                        print("✅ Found conversation in list")
                        
                        // Get participants
                        let participants = viewModel.getParticipants(for: conversation)
                        print("✅ Found \(participants.count) participants")
                        
                        // Create ChatViewModel
                        let chatVM = DIContainer.shared.makeChatViewModel(
                            conversationId: conversation.id,
                            currentUserId: authViewModel.currentUser?.id ?? "",
                            initialConversation: conversation,
                            initialParticipants: participants
                        )
                        
                        // Open chat
                        chatContext = ChatContext(
                            conversation: conversation,
                            chatViewModel: chatVM,
                            participants: participants
                        )
                        print("✅ Chat opened via deep link")
                    } else {
                        print("⚠️ Conversation not found in list (may still be loading)")
                    }
                }
            }
        }
    }
    
    private var conversationsList: some View {
        List(viewModel.conversations) { conversation in
            Button(action: {
                print("🔴 [Button Tap] User tapped conversation: \(conversation.id)")
                
                // Get participants from users dictionary (single source of truth)
                let participants = viewModel.getParticipants(for: conversation)
                print("  📊 Found \(participants.count) participants")
                
                // Create ChatViewModel
                let chatVM = DIContainer.shared.makeChatViewModel(
                    conversationId: conversation.id,
                    currentUserId: authViewModel.currentUser?.id ?? "",
                    initialConversation: conversation,
                    initialParticipants: participants
                )
                
                // Set single state object - keeps everything in sync
                chatContext = ChatContext(
                    conversation: conversation,
                    chatViewModel: chatVM,
                    participants: participants
                )
                print("✅ [Button] chatContext created and assigned")
            }) {
                ConversationRowView(
                    conversation: conversation,
                    displayName: viewModel.displayName(for: conversation),
                    unreadCount: viewModel.unreadCount(for: conversation),
                    formattedTimestamp: viewModel.formattedTimestamp(for: conversation),
                    participants: viewModel.getParticipants(for: conversation)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .listStyle(PlainListStyle())
        .sheet(item: $chatContext) { context in
            let _ = print("🔷 [Sheet Evaluation] Sheet closure called for: \(context.id)")
            let _ = print("  📊 ChatViewModel has \(context.chatViewModel.messages.count) messages")
            let _ = print("  👥 \(context.participants.count) participants")
            
            NavigationView {
                ChatView(
                    viewModel: context.chatViewModel,
                    initialConversation: context.conversation,
                    initialParticipants: context.participants
                )
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 72))
                .foregroundColor(.secondary)
            
            Text("No Conversations")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Start a new conversation")
                .font(.body)
                .foregroundColor(.secondary)
            
            Button("New Conversation") {
                showNewConversation = true
            }
            .buttonStyle(.borderedProminent)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No conversations. Tap New Conversation to start chatting.")
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

// MARK: - Preview

struct ConversationsListView_Previews: PreviewProvider {
    static var previews: some View {
        // Preview uses real DIContainer with Firebase
        // For better previews, use Firebase Emulator in dev environment
        ConversationsListView(
            viewModel: DIContainer.shared.makeConversationsListViewModel(currentUserId: "preview-user")
        )
        .environmentObject(DIContainer.shared.makeAuthViewModel())
    }
}

