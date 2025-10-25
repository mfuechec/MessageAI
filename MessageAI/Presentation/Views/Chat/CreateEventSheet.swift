import SwiftUI

/// Sheet for creating a calendar event from a conversation message
struct CreateEventSheet: View {
    @SwiftUI.Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    @ObservedObject var viewModel: CalendarViewModel

    // Event properties
    @State private var title: String
    @State private var startDate: Date
    @State private var durationMinutes: Int = 30
    @State private var description: String = ""
    @State private var location: String = ""
    @State private var attendeeEmails: [String]

    // UI state
    @State private var showAddAttendeeAlert = false
    @State private var newAttendeeEmail = ""

    init(
        viewModel: CalendarViewModel,
        suggestedTitle: String = "",
        suggestedStartDate: Date? = nil,
        participantEmails: [String] = []
    ) {
        self.viewModel = viewModel
        _title = State(initialValue: suggestedTitle)
        _startDate = State(initialValue: suggestedStartDate ?? Date())
        _attendeeEmails = State(initialValue: participantEmails)
    }

    var body: some View {
        NavigationView {
            Form {
                // Basic Info Section
                Section {
                    TextField("Event Title", text: $title)

                    DatePicker(
                        "Start Time",
                        selection: $startDate,
                        in: Date()...,
                        displayedComponents: [.date, .hourAndMinute]
                    )

                    Picker("Duration", selection: $durationMinutes) {
                        Text("15 min").tag(15)
                        Text("30 min").tag(30)
                        Text("45 min").tag(45)
                        Text("1 hour").tag(60)
                        Text("1.5 hours").tag(90)
                        Text("2 hours").tag(120)
                    }
                } header: {
                    Text("Event Details")
                }

                // Optional Details Section
                Section {
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)

                    TextField("Location (optional)", text: $location)
                } header: {
                    Text("Optional Details")
                }

                // Attendees Section
                Section {
                    ForEach(attendeeEmails, id: \.self) { email in
                        HStack {
                            Image(systemName: "person.circle")
                            Text(email)
                                .font(.caption)
                            Spacer()
                            Button {
                                attendeeEmails.removeAll { $0 == email }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }

                    Button {
                        showAddAttendeeAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "person.badge.plus")
                            Text("Add Attendee")
                        }
                    }
                } header: {
                    Text("Attendees")
                }

                // Event Summary Section
                Section {
                    eventSummary
                } header: {
                    Text("Summary")
                }
            }
            .navigationTitle("Create Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            await createEvent()
                        }
                    }
                    .disabled(!isValid || viewModel.isLoading)
                }
            }
            .alert("Add Attendee", isPresented: $showAddAttendeeAlert) {
                TextField("Email", text: $newAttendeeEmail)
                Button("Cancel", role: .cancel) {}
                Button("Add") {
                    if !newAttendeeEmail.isEmpty && isValidEmail(newAttendeeEmail) {
                        attendeeEmails.append(newAttendeeEmail)
                        newAttendeeEmail = ""
                    }
                }
            } message: {
                Text("Enter attendee email address")
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                }
            }
        }
    }

    // MARK: - View Components

    private var eventSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "calendar")
                Text(formatDate(startDate))
            }

            HStack {
                Image(systemName: "clock")
                Text(formatTime(startDate) + " - " + formatTime(endDate))
            }

            if !location.isEmpty {
                HStack {
                    Image(systemName: "location")
                    Text(location)
                }
            }

            if !attendeeEmails.isEmpty {
                HStack {
                    Image(systemName: "person.2")
                    Text("\(attendeeEmails.count) attendee(s)")
                }
            }
        }
        .font(.caption)
        .foregroundColor(.secondary)
    }

    // MARK: - Computed Properties

    private var endDate: Date {
        startDate.addingTimeInterval(TimeInterval(durationMinutes * 60))
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Actions

    private func createEvent() async {
        await viewModel.createEventFromMessage(
            title: title,
            startTime: startDate,
            durationMinutes: durationMinutes,
            description: description.isEmpty ? nil : description,
            attendeeEmails: attendeeEmails
        )

        if viewModel.errorMessage == nil {
            presentationMode.wrappedValue.dismiss()
        }
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: emailRegex, options: .regularExpression) != nil
    }
}

// MARK: - Preview

#Preview {
    // Preview not available - requires calendar repository
    Text("CreateEventSheet Preview")
}
