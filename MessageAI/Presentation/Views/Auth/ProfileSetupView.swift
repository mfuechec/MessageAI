//
//  ProfileSetupView.swift
//  MessageAI
//
//  Created by Dev Agent on 2025-10-20.
//

import SwiftUI
import Kingfisher

struct ProfileSetupView: View {
    @ObservedObject var viewModel: ProfileSetupViewModel
    var authViewModel: AuthViewModel?
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Set Up Your Profile")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Help others recognize you")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                    
                    // Profile Image Selector
                    Button(action: {
                        showImagePicker = true
                    }) {
                        if let selectedImage = selectedImage {
                            Image(uiImage: selectedImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                        } else if let profileImageURL = viewModel.profileImageURL,
                                  let url = URL(string: profileImageURL) {
                            KFImage(url)
                                .placeholder {
                                    ProgressView()
                                        .frame(width: 100, height: 100)
                                }
                                .onFailure { _ in
                                    // Fallback to placeholder on failure
                                }
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                        } else {
                            profileImagePlaceholder
                        }
                    }
                    .accessibilityLabel("Profile Picture")
                    .accessibilityHint("Tap to select a profile picture from your photo library")
                    
                    Text("Tap to add photo")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Display Name Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Display Name")
                            .font(.headline)
                        
                        TextField("Display Name", text: $viewModel.displayName)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.words)
                            .textContentType(.name)
                            .accessibilityLabel("Display Name")
                            .accessibilityHint("Enter your display name")
                            .onChange(of: viewModel.displayName) { newValue in
                                // Enforce 50 character limit
                                if newValue.count > 50 {
                                    viewModel.displayName = String(newValue.prefix(50))
                                }
                            }
                        
                        // Character counter
                        HStack {
                            Spacer()
                            Text("\(viewModel.displayName.count)/50")
                                .font(.caption)
                                .foregroundColor(viewModel.displayName.count > 45 ? .orange : .secondary)
                                .accessibilityLabel("\(viewModel.displayName.count) of 50 characters")
                        }
                    }
                    .padding(.horizontal)
                    
                    // Error Message
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .accessibilityLabel("Error: \(errorMessage)")
                    }
                    
                    // Continue Button
                    Button(action: {
                        Task {
                            await viewModel.saveProfile()
                        }
                    }) {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView()
                                    .tint(.white)
                                    .accessibilityLabel("Saving profile")
                            } else {
                                Text("Continue")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isLoading)
                    .padding(.horizontal)
                    .accessibilityLabel("Continue")
                    .accessibilityHint("Save your profile and continue")
                    
                    // Skip Button
                    Button("Skip for now") {
                        viewModel.skipSetup()
                    }
                    .disabled(viewModel.isLoading)
                    .padding(.horizontal)
                    .accessibilityLabel("Skip profile setup")
                    .accessibilityHint("Continue with default display name")
                    
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if let authViewModel = authViewModel {
                        Button("Logout") {
                            Task {
                                await authViewModel.signOut()
                            }
                        }
                        .font(.subheadline)
                    }
                }
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(selectedImage: $selectedImage)
        }
        .onChange(of: selectedImage) { image in
            guard let image = image else { return }
            
            Task {
                await viewModel.uploadProfileImage(image)
            }
        }
    }
    
    // MARK: - Subviews
    
    private var profileImagePlaceholder: some View {
        Image(systemName: "person.circle.fill")
            .resizable()
            .frame(width: 100, height: 100)
            .foregroundColor(.secondary)
    }
}

// MARK: - Preview

#if DEBUG
struct ProfileSetupView_Previews: PreviewProvider {
    static var previews: some View {
        // Note: Preview requires test mocks which aren't available in main target
        // Use simulator or device for testing
        Text("Use simulator to preview ProfileSetupView")
    }
}
#endif

