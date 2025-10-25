import SwiftUI

/// Settings screen for Google Calendar integration
struct CalendarSettingsView: View {
    @StateObject var viewModel: CalendarViewModel
    @State private var showDisconnectConfirmation = false

    var body: some View {
        Form {
            // Connection Status Section
            Section {
                HStack {
                    Text("Status")
                    Spacer()
                    connectionStatusIndicator
                }

                if viewModel.isConnected {
                    HStack {
                        Text("Connected Email")
                        Spacer()
                        // TODO: Get email from user repository
                        Text("user@gmail.com")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("Google Calendar")
            } footer: {
                if !viewModel.isConnected {
                    Text("Connect your Google Calendar to schedule meetings from conversations and share your availability.")
                }
            }

            // Connection Actions
            Section {
                if viewModel.isConnected {
                    Button(role: .destructive) {
                        showDisconnectConfirmation = true
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Disconnect Google Calendar")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(viewModel.isLoading)
                } else {
                    Button {
                        Task {
                            await viewModel.connectGoogleCalendar()
                        }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            HStack {
                                Image(systemName: "calendar.badge.plus")
                                Text("Connect Google Calendar")
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(viewModel.isLoading)
                }
            }

            // Upcoming Events Section (only show if connected)
            if viewModel.isConnected && !viewModel.upcomingEvents.isEmpty {
                Section {
                    ForEach(viewModel.upcomingEvents.prefix(5)) { event in
                        EventRow(event: event)
                    }

                    if viewModel.upcomingEvents.count > 5 {
                        Button("View All Events") {
                            // TODO: Navigate to full calendar view
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                } header: {
                    HStack {
                        Text("Upcoming Events")
                        Spacer()
                        Button {
                            Task {
                                await viewModel.loadUpcomingEvents()
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption)
                        }
                        .disabled(viewModel.isLoading)
                    }
                }
            }

            // Features Section
            Section {
                CalendarFeatureRow(
                    icon: "message.badge.clock",
                    title: "Meeting Scheduling",
                    description: "Create calendar events from conversation messages"
                )

                CalendarFeatureRow(
                    icon: "calendar.badge.clock",
                    title: "Availability Sharing",
                    description: "Share your free/busy status with conversation participants"
                )
            } header: {
                Text("Features")
            }
        }
        .navigationTitle("Calendar Integration")
        .alert("Disconnect Calendar?", isPresented: $showDisconnectConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Disconnect", role: .destructive) {
                Task {
                    await viewModel.disconnectGoogleCalendar()
                }
            }
        } message: {
            Text("This will remove access to your Google Calendar. You can reconnect at any time.")
        }
        .alert(isPresented: .constant(viewModel.errorMessage != nil)) {
            Alert(
                title: Text("Error"),
                message: Text(viewModel.errorMessage ?? ""),
                dismissButton: .default(Text("OK")) {
                    viewModel.clearMessages()
                }
            )
        }
        .task {
            await viewModel.checkConnectionStatus()
        }
    }

    // MARK: - View Components

    private var connectionStatusIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(viewModel.isConnected ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
            Text(viewModel.isConnected ? "Connected" : "Not Connected")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Supporting Views

/// Row displaying a calendar event
struct EventRow: View {
    let event: CalendarEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(event.title)
                .font(.headline)

            HStack {
                Image(systemName: "clock")
                    .font(.caption)
                Text(formattedTime)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let location = event.location {
                HStack {
                    Image(systemName: "location")
                        .font(.caption)
                    Text(location)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter.string(from: event.startTime)
    }
}

/// Row displaying a calendar feature description
struct CalendarFeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    // Preview not available - requires calendar repository
    Text("CalendarSettingsView Preview")
}
