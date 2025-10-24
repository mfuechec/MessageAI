//
//  SmartNotificationSettingsView.swift
//  MessageAI
//
//  Created by Claude Code on 10/23/25.
//  Epic 6 - Story 6.4: User Preferences & Opt-In Controls
//

import SwiftUI
import Combine

/// Settings screen for smart notification preferences
struct SmartNotificationSettingsView: View {
    @StateObject var viewModel: NotificationPreferencesViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showTestResult = false
    @State private var showAddKeywordAlert = false
    @State private var newKeyword = ""
    @State private var showOptOutConfirmation = false
    @State private var showLogoutConfirmation = false

    var body: some View {
        Form {
            // Status Section
            Section {
                Toggle("Smart Notifications", isOn: $viewModel.preferences.enabled)
                    .onChange(of: viewModel.preferences.enabled) { newValue in
                        Task {
                            if newValue {
                                await viewModel.enableSmartNotifications()
                            } else {
                                showOptOutConfirmation = true
                            }
                        }
                    }

                HStack {
                    Text("AI Status")
                    Spacer()
                    statusIndicator(viewModel.aiStatus)
                }
            } header: {
                Text("Status")
            }

            // Trigger Settings
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Pause Threshold")
                    Text("\(viewModel.preferences.pauseThresholdSeconds) seconds")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Slider(
                        value: Binding(
                            get: { Double(viewModel.preferences.pauseThresholdSeconds) },
                            set: { newValue in
                                Task {
                                    await viewModel.updatePauseThreshold(Int(newValue))
                                }
                            }
                        ),
                        in: 60...300,
                        step: 30
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Active Conversation Threshold")
                    Text("\(viewModel.preferences.activeConversationThreshold) messages")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Slider(
                        value: Binding(
                            get: { Double(viewModel.preferences.activeConversationThreshold) },
                            set: { newValue in
                                Task {
                                    await viewModel.updateActiveConversationThreshold(Int(newValue))
                                }
                            }
                        ),
                        in: 10...50,
                        step: 5
                    )
                }
            } header: {
                Text("Trigger Settings")
            } footer: {
                Text("Notifications trigger after conversation pauses for the threshold time, or after exceeding message threshold.")
            }

            // Priority Keywords
            Section {
                ForEach(Array(viewModel.preferences.priorityKeywords.enumerated()), id: \.offset) { index, keyword in
                    HStack {
                        Text(keyword)
                        Spacer()
                        Button(role: .destructive) {
                            Task {
                                await viewModel.removePriorityKeyword(at: index)
                            }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                }

                Button {
                    showAddKeywordAlert = true
                } label: {
                    Label("Add Keyword", systemImage: "plus.circle.fill")
                }
            } header: {
                Text("Priority Keywords")
            } footer: {
                Text("Messages containing these keywords will trigger high-priority notifications.")
            }

            // Cost Control
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Max Analyses Per Hour")
                    Text("\(viewModel.preferences.maxAnalysesPerHour) per hour")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Stepper(
                        value: Binding(
                            get: { viewModel.preferences.maxAnalysesPerHour },
                            set: { newValue in
                                viewModel.preferences.maxAnalysesPerHour = newValue
                                Task {
                                    await viewModel.savePreferences()
                                }
                            }
                        ),
                        in: 5...20,
                        step: 1
                    ) {
                        EmptyView()
                    }
                }
            } header: {
                Text("Cost Control")
            } footer: {
                Text("Limits AI analysis calls to control costs.")
            }

            // Fallback Strategy
            Section {
                Picker("If AI Unavailable", selection: Binding(
                    get: { viewModel.preferences.fallbackStrategy },
                    set: { newValue in
                        Task {
                            await viewModel.updateFallbackStrategy(newValue)
                        }
                    }
                )) {
                    Text("Use Simple Rules").tag(FallbackStrategy.simpleRules)
                    Text("Notify All Messages").tag(FallbackStrategy.notifyAll)
                    Text("Suppress All").tag(FallbackStrategy.suppressAll)
                }
            } header: {
                Text("Fallback Strategy")
            } footer: {
                Text("Behavior when AI analysis is unavailable.")
            }

            // Testing
            Section {
                Button {
                    Task {
                        await viewModel.testNotification()
                        showTestResult = true
                    }
                } label: {
                    HStack {
                        if viewModel.isTestingNotification {
                            ProgressView()
                                .padding(.trailing, 8)
                        }
                        Text("Test Smart Notification")
                    }
                }
                .disabled(viewModel.isTestingNotification || !viewModel.preferences.enabled)
            } header: {
                Text("Testing")
            } footer: {
                Text("Test notification analysis with your most recent conversation.")
            }

            // Notification History
            Section {
                NavigationLink {
                    NotificationHistoryView(
                        viewModel: DIContainer.shared.makeNotificationHistoryViewModel(
                            userId: authViewModel.currentUser?.id ?? ""
                        )
                    )
                } label: {
                    Label("Notification History", systemImage: "clock.arrow.circlepath")
                }
            } header: {
                Text("History")
            } footer: {
                Text("View your recent smart notification decisions and provide feedback.")
            }

            // Account Actions
            Section {
                Button(role: .destructive) {
                    showLogoutConfirmation = true
                } label: {
                    HStack {
                        Spacer()
                        Text("Logout")
                        Spacer()
                    }
                }
            } header: {
                Text("Account")
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            // Clean up Firestore listeners when view disappears
            viewModel.cleanup()
        }
        .sheet(isPresented: $showTestResult) {
            TestResultView(decision: viewModel.testDecision)
        }
        .alert("Add Priority Keyword", isPresented: $showAddKeywordAlert) {
            TextField("Keyword", text: $newKeyword)
            Button("Cancel", role: .cancel) {
                newKeyword = ""
            }
            Button("Add") {
                Task {
                    await viewModel.addPriorityKeyword(newKeyword)
                    newKeyword = ""
                }
            }
        }
        .alert("Disable Smart Notifications?", isPresented: $showOptOutConfirmation) {
            Button("Cancel", role: .cancel) {
                viewModel.preferences.enabled = true
            }
            Button("Disable", role: .destructive) {
                Task {
                    await viewModel.disableSmartNotifications()
                }
            }
        } message: {
            Text("You'll receive notifications for every message. You can re-enable this anytime.")
        }
        .alert("Logout?", isPresented: $showLogoutConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Logout", role: .destructive) {
                // Clean up listeners BEFORE logout to prevent permission errors
                viewModel.cleanup()
                Task {
                    await authViewModel.signOut()
                }
            }
        } message: {
            Text("Are you sure you want to logout?")
        }
    }

    @ViewBuilder
    private func statusIndicator(_ status: AIStatus) -> some View {
        switch status {
        case .active:
            Label("Active", systemImage: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption)
        case .usingFallback:
            Label("Using Fallback", systemImage: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.caption)
        case .unavailable:
            Label("Unavailable", systemImage: "xmark.circle.fill")
                .foregroundColor(.red)
                .font(.caption)
        }
    }
}

/// Test result modal view
struct TestResultView: View {
    @SwiftUI.Environment(\.presentationMode) var presentationMode
    let decision: NotificationDecision?

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                if let decision = decision {
                    // Decision Icon
                    Image(systemName: decision.shouldNotify ? "bell.badge.fill" : "bell.slash.fill")
                        .font(.system(size: 60))
                        .foregroundColor(decision.shouldNotify ? .green : .gray)
                        .padding(.top, 40)

                    // Decision Text
                    Text(decision.shouldNotify ? "Will Notify" : "Won't Notify")
                        .font(.title)
                        .fontWeight(.bold)

                    // Priority Badge
                    if decision.shouldNotify {
                        priorityBadge(decision.priority)
                    }

                    // Reason
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Reason")
                            .font(.headline)
                        Text(decision.reason)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    // Notification Text
                    if let notificationText = decision.notificationText {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notification Preview")
                                .font(.headline)
                            Text(notificationText)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    // Note
                    Text("This is a test - no actual notification sent")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)

                    Spacer()
                } else {
                    Text("No test result available")
                        .foregroundColor(.secondary)
                        .padding()
                    Spacer()
                }
            }
            .navigationTitle("Test Result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func priorityBadge(_ priority: NotificationPriority) -> some View {
        let (text, color): (String, Color) = {
            switch priority {
            case .high: return ("High Priority", .red)
            case .medium: return ("Medium Priority", .orange)
            case .low: return ("Low Priority", .blue)
            }
        }()

        Text(text)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(8)
    }
}

#if DEBUG
struct SmartNotificationSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SmartNotificationSettingsView(
                viewModel: NotificationPreferencesViewModel(
                    repository: MockNotificationPreferencesRepository(),
                    userId: "preview-user"
                )
            )
            .environmentObject(DIContainer.shared.makeAuthViewModel())
        }
    }
}

// Mock repository for previews
class MockNotificationPreferencesRepository: NotificationPreferencesRepositoryProtocol {
    func getPreferences(userId: String) async throws -> NotificationPreferences {
        return .default
    }

    func savePreferences(_ preferences: NotificationPreferences) async throws {}

    func observePreferences(userId: String) -> AnyPublisher<NotificationPreferences, Never> {
        Just(.default).eraseToAnyPublisher()
    }

    func isEnabled(userId: String) async throws -> Bool {
        return true
    }

    func enableSmartNotifications(userId: String, defaultPreferences: NotificationPreferences?) async throws {}

    func disableSmartNotifications(userId: String) async throws {}

    func deletePreferences(userId: String) async throws {}
}
#endif
