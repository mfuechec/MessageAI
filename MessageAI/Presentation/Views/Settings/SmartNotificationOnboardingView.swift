//
//  SmartNotificationOnboardingView.swift
//  MessageAI
//
//  Created by Claude Code on 10/23/25.
//  Epic 6 - Story 6.4: User Preferences & Opt-In Controls
//

import SwiftUI

/// Onboarding modal for smart notifications opt-in
struct SmartNotificationOnboardingView: View {
    @SwiftUI.Environment(\.presentationMode) var presentationMode
    let onEnable: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            // Header Image
            Image(systemName: "brain.head.profile")
                .font(.system(size: 60))
                .foregroundColor(.blue)
                .padding(.top, 20)

            // Title
            Text("Smart Notifications")
                .font(.title)
                .fontWeight(.bold)

            // Subtitle
            Text("Let AI analyze your conversations to reduce notification fatigue")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            // Feature List
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(
                    icon: "checkmark.circle.fill",
                    text: "Only get notified about messages that matter",
                    color: .green
                )
                FeatureRow(
                    icon: "checkmark.circle.fill",
                    text: "AI considers mentions, urgent requests, and context",
                    color: .green
                )
                FeatureRow(
                    icon: "checkmark.circle.fill",
                    text: "You can disable this anytime in Settings",
                    color: .green
                )
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 8)

            // Privacy Statement
            Text("Your messages are analyzed securely. We don't store message content, only notification decisions.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .padding(.top, 8)

            // Buttons
            VStack(spacing: 12) {
                Button(action: {
                    onEnable()
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Enable Smart Notifications")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }

                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Maybe Later")
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal)

            // Privacy Policy Link
            Link("Privacy Policy", destination: URL(string: "https://messageai.app/privacy")!)
                .font(.caption)
                .padding(.bottom, 20)
        }
        .padding()
    }
}

/// Feature row component for onboarding
struct FeatureRow: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)

            Text(text)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#if DEBUG
struct SmartNotificationOnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        SmartNotificationOnboardingView(onEnable: {
            print("Enabled!")
        })
    }
}
#endif
