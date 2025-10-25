import SwiftUI

/// View for displaying calendar availability and finding common meeting times
struct AvailabilityView: View {
    @ObservedObject var viewModel: CalendarViewModel
    let participantEmails: [String]

    @State private var selectedDays: Int = 7
    @State private var meetingDuration: Int = 30
    @State private var showCreateEventSheet = false
    @State private var selectedTimeSlot: TimeSlot?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                headerSection

                // Configuration
                configurationSection

                // Common Free Slots
                if !viewModel.commonFreeSlots.isEmpty {
                    freeSlotsSection
                } else if viewModel.isLoading {
                    ProgressView("Finding available times...")
                        .padding()
                } else if !participantEmails.isEmpty {
                    emptyStateView
                }
            }
            .padding()
        }
        .navigationTitle("Find Meeting Time")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadAvailability()
        }
        .sheet(isPresented: $showCreateEventSheet) {
            if let timeSlot = selectedTimeSlot {
                CreateEventSheet(
                    viewModel: viewModel,
                    suggestedTitle: "Meeting",
                    suggestedStartDate: timeSlot.startTime,
                    participantEmails: participantEmails
                )
            }
        }
    }

    // MARK: - View Components

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Participants")
                .font(.headline)

            ForEach(participantEmails, id: \.self) { email in
                HStack {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(.blue)
                    Text(email)
                        .font(.caption)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }

    private var configurationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Meeting Preferences")
                .font(.headline)

            // Days to check
            VStack(alignment: .leading, spacing: 8) {
                Text("Days to Check")
                    .font(.subheadline)
                Picker("Days", selection: $selectedDays) {
                    Text("3 days").tag(3)
                    Text("7 days").tag(7)
                    Text("14 days").tag(14)
                    Text("30 days").tag(30)
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedDays) { _ in
                    Task {
                        await loadAvailability()
                    }
                }
            }

            // Meeting duration
            VStack(alignment: .leading, spacing: 8) {
                Text("Meeting Duration")
                    .font(.subheadline)
                Picker("Duration", selection: $meetingDuration) {
                    Text("15 min").tag(15)
                    Text("30 min").tag(30)
                    Text("45 min").tag(45)
                    Text("60 min").tag(60)
                }
                .pickerStyle(.segmented)
                .onChange(of: meetingDuration) { _ in
                    Task {
                        await loadAvailability()
                    }
                }
            }

            Button {
                Task {
                    await loadAvailability()
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh Availability")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isLoading)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }

    private var freeSlotsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Available Times")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.commonFreeSlots.count) slots")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ForEach(groupedSlots.keys.sorted(), id: \.self) { date in
                if let slots = groupedSlots[date] {
                    daySection(date: date, slots: slots)
                }
            }
        }
    }

    private func daySection(date: String, slots: [TimeSlot]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(date)
                .font(.subheadline)
                .bold()
                .foregroundColor(.blue)

            ForEach(slots, id: \.startTime) { slot in
                timeSlotRow(slot)
            }
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(8)
    }

    private func timeSlotRow(_ slot: TimeSlot) -> some View {
        Button {
            selectedTimeSlot = slot
            showCreateEventSheet = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "clock")
                        Text(formatTimeRange(slot))
                            .font(.subheadline)
                    }
                    Text("\(slot.durationMinutes) minutes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "calendar.badge.plus")
                    .foregroundColor(.blue)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundColor(.gray)

            Text("No common available times found")
                .font(.headline)

            Text("Try expanding the date range or reducing the meeting duration.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - Computed Properties

    private var groupedSlots: [String: [TimeSlot]] {
        Dictionary(grouping: viewModel.commonFreeSlots) { slot in
            formatDate(slot.startTime)
        }
    }

    // MARK: - Actions

    private func loadAvailability() async {
        guard !participantEmails.isEmpty else { return }

        await viewModel.findCommonFreeSlots(
            for: participantEmails,
            days: selectedDays,
            meetingDurationMinutes: meetingDuration
        )
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }

    private func formatTimeRange(_ slot: TimeSlot) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short

        let start = formatter.string(from: slot.startTime)
        let end = formatter.string(from: slot.endTime)

        return "\(start) - \(end)"
    }
}

// MARK: - Preview

#Preview {
    // Preview not available - requires calendar repository
    Text("AvailabilityView Preview")
}
