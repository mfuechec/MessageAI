import SwiftUI

/// Main view for displaying user's conversations list
struct ConversationsListView: View {
    @StateObject var viewModel: ConversationsListViewModel
    @State private var selectedConversation: Conversation?
    @State private var showComingSoonAlert = false
    @EnvironmentObject private var authViewModel: AuthViewModel
    
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
                
                // Offline banner
                if viewModel.isOffline {
                    offlineBanner
                }
            }
            .navigationTitle("Messages")
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
                        showComingSoonAlert = true
                    }) {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("New Conversation")
                }
            }
            .alert("Coming Soon", isPresented: $showComingSoonAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Creating new conversations will be available in the next update.")
            }
        }
    }
    
    private var conversationsList: some View {
        List(viewModel.conversations) { conversation in
            Button(action: {
                selectedConversation = conversation
            }) {
                ConversationRowView(
                    conversation: conversation,
                    displayName: viewModel.displayName(for: conversation),
                    unreadCount: viewModel.unreadCount(for: conversation),
                    formattedTimestamp: viewModel.formattedTimestamp(for: conversation)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .listStyle(PlainListStyle())
        .sheet(item: $selectedConversation) { conversation in
            NavigationView {
                ChatView(
                    viewModel: DIContainer.shared.makeChatViewModel(
                        conversationId: conversation.id,
                        currentUserId: authViewModel.currentUser?.id ?? ""
                    )
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
                showComingSoonAlert = true
            }
            .buttonStyle(.borderedProminent)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No conversations. Tap New Conversation to start chatting.")
    }
    
    private var offlineBanner: some View {
        VStack {
            HStack {
                Image(systemName: "wifi.slash")
                Text("You're offline")
                    .font(.subheadline)
            }
            .foregroundColor(.white)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(Color.orange)
            
            Spacer()
        }
        .accessibilityLabel("Offline mode. Some features may be unavailable.")
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

