//
//  NewConversationView.swift
//  MessageAI
//
//  Created by Dev Agent (James) on 10/21/25.
//  Story 2.0: Start New Conversation with Duplicate Prevention
//

import SwiftUI

/// View for selecting a user to start a new conversation
struct NewConversationView: View {
    @ObservedObject var viewModel: NewConversationViewModel
    @SwiftUI.Environment(\.presentationMode) private var presentationMode
    let onConversationSelected: (Conversation) -> Void
    
    // Multi-select state (always enabled)
    @State private var selectedUsers: Set<User> = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                SearchBar(text: $viewModel.searchText)
                    .padding()
                
                // Content area
                if viewModel.isLoading {
                    ProgressView("Loading users...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityLabel("Loading users")
                } else if let error = viewModel.errorMessage {
                    // Error state with retry
                    VStack(spacing: 16) {
                        Text("Error")
                            .font(.headline)
                        
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("Retry") {
                            Task {
                                await viewModel.loadUsers()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityLabel("Retry loading users")
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.filteredUsers.isEmpty {
                    // Empty state
                    VStack(spacing: 8) {
                        Image(systemName: "person.3")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text(viewModel.searchText.isEmpty ? "No users found" : "No matching users")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // User list with multi-select
                    VStack(spacing: 0) {
                        List(viewModel.filteredUsers) { user in
                            HStack {
                                Image(systemName: selectedUsers.contains(user) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedUsers.contains(user) ? .accentColor : .gray)
                                
                                UserRowView(user: user)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                toggleUserSelection(user)
                            }
                            .accessibilityHint(selectedUsers.contains(user) ? "Selected. Tap to deselect" : "Not selected. Tap to select")
                        }
                        .listStyle(.plain)
                        
                        // Create Conversation button (visible when at least 1 user selected)
                        if selectedUsers.count >= 1 {
                            VStack(spacing: 8) {
                                Text("\(selectedUsers.count) user\(selectedUsers.count == 1 ? "" : "s") selected")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .accessibilityLabel("\(selectedUsers.count) users selected")
                                
                                Button(action: {
                                    Task {
                                        await createConversation()
                                    }
                                }) {
                                    Text("Create Conversation")
                                        .font(.headline)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.accentColor)
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                }
                                .disabled(viewModel.isLoading)
                                .accessibilityLabel("Create conversation")
                                .padding(.horizontal)
                                .padding(.bottom)
                            }
                            .background(Color(.systemBackground))
                        } else {
                            Text("Select 1 or more users to create a conversation")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding()
                        }
                    }
                }
            }
            .navigationTitle("New Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .accessibilityLabel("Cancel new message")
                }
            }
            .task {
                await viewModel.loadUsers()
            }
            .onChange(of: viewModel.selectedConversation) { conversation in
                print("🔔 NewConversationView onChange fired. Conversation: \(conversation?.id ?? "nil")")
                if let conversation = conversation {
                    print("📱 Calling onConversationSelected callback")
                    onConversationSelected(conversation)
                } else {
                    print("⚠️ Conversation is nil, not calling callback")
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Toggle selection of a user
    private func toggleUserSelection(_ user: User) {
        if selectedUsers.contains(user) {
            selectedUsers.remove(user)
            print("🔘 Deselected user: \(user.displayName) (Total: \(selectedUsers.count))")
        } else {
            selectedUsers.insert(user)
            print("✅ Selected user: \(user.displayName) (Total: \(selectedUsers.count))")
        }
    }
    
    /// Create a conversation with selected users
    private func createConversation() async {
        guard selectedUsers.count >= 1 else {
            viewModel.errorMessage = "Please select at least one user."
            return
        }
        
        let selectedUsersList = Array(selectedUsers)
        
        // Use single-user method for 1 user, multi-user method for 2+ users
        if selectedUsersList.count == 1 {
            await viewModel.selectUser(selectedUsersList[0])
        } else {
            await viewModel.selectMultipleUsers(selectedUsersList)
        }
    }
}

/// Custom search bar component
struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search users", text: $text)
                .textFieldStyle(.plain)
                .autocapitalization(.none)
                .accessibilityLabel("Search users")
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

