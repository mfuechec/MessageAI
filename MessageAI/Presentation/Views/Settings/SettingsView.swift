import SwiftUI

/// Main settings menu with navigation to all settings screens
struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @SwiftUI.Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>

    var body: some View {
        NavigationView {
            List {
                // User Profile Section
                Section {
                    HStack(spacing: 12) {
                        // Profile image or initials
                        if let imageURL = authViewModel.currentUser?.profileImageURL,
                           let url = URL(string: imageURL) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Circle()
                                    .fill(Color.blue)
                                    .overlay(
                                        Text(authViewModel.currentUser?.displayInitials ?? "?")
                                            .foregroundColor(.white)
                                            .font(.headline)
                                    )
                            }
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Text(authViewModel.currentUser?.displayInitials ?? "?")
                                        .foregroundColor(.white)
                                        .font(.headline)
                                )
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(authViewModel.currentUser?.displayName ?? "User")
                                .font(.headline)
                            Text(authViewModel.currentUser?.email ?? "")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Account")
                }

                // App Settings Section
                Section {
                    NavigationLink(destination: smartNotificationSettings) {
                        HStack {
                            Image(systemName: "bell.badge")
                                .foregroundColor(.blue)
                                .frame(width: 28)
                            Text("Smart Notifications")
                        }
                    }

                    NavigationLink(destination: calendarSettings) {
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.green)
                                .frame(width: 28)
                            Text("Calendar Integration")
                        }
                    }
                } header: {
                    Text("Settings")
                }

                // Account Actions Section
                Section {
                    Button(role: .destructive) {
                        Task {
                            await authViewModel.signOut()
                            presentationMode.wrappedValue.dismiss()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .frame(width: 28)
                            Text("Sign Out")
                        }
                    }
                } header: {
                    Text("Account")
                }

                // App Info Section
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Build")
                        Spacer()
                        Text(buildNumber)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Settings Destinations

    private var smartNotificationSettings: some View {
        SmartNotificationSettingsView(
            viewModel: DIContainer.shared.makeNotificationPreferencesViewModel(
                userId: authViewModel.currentUser?.id ?? ""
            )
        )
        .environmentObject(authViewModel)
    }

    private var calendarSettings: some View {
        CalendarSettingsView(
            viewModel: DIContainer.shared.makeCalendarViewModel()
        )
    }

    // MARK: - Helpers

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
}

// MARK: - Preview

#Preview {
    // Preview not available - requires auth context
    Text("SettingsView Preview")
}
