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
                    // User list
                    List(viewModel.filteredUsers) { user in
                        UserRowView(user: user)
                            .onTapGesture {
                                Task {
                                    await viewModel.selectUser(user)
                                }
                            }
                            .accessibilityHint("Tap to start conversation")
                    }
                    .listStyle(.plain)
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

