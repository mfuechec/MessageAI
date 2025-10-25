import Foundation
import Combine

/// ViewModel for managing Google Calendar integration
///
/// This ViewModel handles:
/// - Google Calendar OAuth authentication
/// - Calendar connection status
/// - Creating calendar events from conversations
/// - Fetching upcoming events
/// - Fetching free/busy availability
/// - Error handling and user feedback
///
/// Architecture:
/// - Depends on CalendarRepositoryProtocol (not concrete Google implementation)
/// - Marked @MainActor for thread-safe UI updates
/// - Uses Swift async/await for asynchronous operations
/// - Publishes state changes to SwiftUI via @Published properties
@MainActor
class CalendarViewModel: ObservableObject {

    // MARK: - Published Properties

    /// Indicates if calendar is connected to Google
    @Published var isConnected: Bool = false

    /// Indicates if an operation is in progress
    @Published var isLoading: Bool = false

    /// Error message to display to user (nil if no error)
    @Published var errorMessage: String?

    /// Success message to display to user (nil if no success)
    @Published var successMessage: String?

    /// List of upcoming calendar events
    @Published var upcomingEvents: [CalendarEvent] = []

    /// User's calendar availability
    @Published var availability: CalendarAvailability?

    /// Common free slots for multiple users
    @Published var commonFreeSlots: [TimeSlot] = []

    // MARK: - Dependencies

    /// Calendar repository for Google Calendar operations
    private let calendarRepository: CalendarRepositoryProtocol

    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    /// Creates CalendarViewModel with injected calendar repository
    /// - Parameter calendarRepository: Repository for calendar operations
    init(calendarRepository: CalendarRepositoryProtocol) {
        self.calendarRepository = calendarRepository

        // Observe calendar connection status
        observeConnectionStatus()

        // Check initial connection status
        Task {
            await checkConnectionStatus()
        }
    }

    // MARK: - Connection Management

    /// Connect to Google Calendar (initiate OAuth flow)
    func connectGoogleCalendar() async {
        isLoading = true
        errorMessage = nil
        successMessage = nil

        do {
            let connected = try await calendarRepository.authenticateWithGoogle()

            if connected {
                isConnected = true
                successMessage = "Google Calendar connected successfully!"

                // Load initial events
                await loadUpcomingEvents()
            }
        } catch {
            errorMessage = localizeError(error)
        }

        isLoading = false
    }

    /// Disconnect from Google Calendar
    func disconnectGoogleCalendar() async {
        isLoading = true
        errorMessage = nil
        successMessage = nil

        do {
            try await calendarRepository.disconnectGoogleCalendar()
            isConnected = false
            upcomingEvents = []
            availability = nil
            successMessage = "Google Calendar disconnected"
        } catch {
            errorMessage = localizeError(error)
        }

        isLoading = false
    }

    /// Check current connection status
    func checkConnectionStatus() async {
        isConnected = await calendarRepository.isConnected()

        if isConnected {
            // Load upcoming events if connected
            await loadUpcomingEvents()
        }
    }

    // MARK: - Event Management

    /// Create a new calendar event
    /// - Parameter event: The calendar event to create
    func createEvent(_ event: CalendarEvent) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil

        do {
            let createdEvent = try await calendarRepository.createEvent(event)
            upcomingEvents.insert(createdEvent, at: 0)
            upcomingEvents.sort { $0.startTime < $1.startTime }
            successMessage = "Event '\(createdEvent.title)' created successfully!"
        } catch {
            errorMessage = localizeError(error)
        }

        isLoading = false
    }

    /// Create event from conversation message
    /// - Parameters:
    ///   - title: Event title
    ///   - startTime: Event start time
    ///   - durationMinutes: Event duration in minutes (default 30)
    ///   - description: Optional event description
    ///   - attendeeEmails: Optional list of attendee emails
    func createEventFromMessage(
        title: String,
        startTime: Date,
        durationMinutes: Int = 30,
        description: String? = nil,
        attendeeEmails: [String] = []
    ) async {
        let endTime = startTime.addingTimeInterval(TimeInterval(durationMinutes * 60))

        let attendees = attendeeEmails.map { email in
            CalendarAttendee(email: email, responseStatus: .needsAction)
        }

        let event = CalendarEvent(
            title: title,
            description: description,
            startTime: startTime,
            endTime: endTime,
            attendees: attendees,
            reminders: [CalendarReminder(minutesBefore: 15)]
        )

        await createEvent(event)
    }

    /// Load upcoming calendar events
    /// - Parameter days: Number of days ahead to load (default 7)
    func loadUpcomingEvents(days: Int = 7) async {
        guard isConnected else {
            errorMessage = "Google Calendar not connected"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let startDate = Date()
            let endDate = Calendar.current.date(byAdding: .day, value: days, to: startDate) ?? startDate

            upcomingEvents = try await calendarRepository.getEvents(
                from: startDate,
                to: endDate,
                maxResults: 50
            )
        } catch {
            errorMessage = localizeError(error)
        }

        isLoading = false
    }

    /// Update an existing calendar event
    /// - Parameter event: The event with updated information
    func updateEvent(_ event: CalendarEvent) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil

        do {
            try await calendarRepository.updateEvent(event)

            // Update local list
            if let index = upcomingEvents.firstIndex(where: { $0.id == event.id }) {
                upcomingEvents[index] = event
            }

            successMessage = "Event updated successfully!"
        } catch {
            errorMessage = localizeError(error)
        }

        isLoading = false
    }

    /// Delete a calendar event
    /// - Parameter eventId: The Google Calendar event ID
    func deleteEvent(eventId: String) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil

        do {
            try await calendarRepository.deleteEvent(eventId: eventId)

            // Remove from local list
            upcomingEvents.removeAll { $0.id == eventId }

            successMessage = "Event deleted successfully!"
        } catch {
            errorMessage = localizeError(error)
        }

        isLoading = false
    }

    // MARK: - Availability Management

    /// Load user's calendar availability
    /// - Parameters:
    ///   - userEmail: Google Calendar email
    ///   - days: Number of days ahead to check (default 7)
    func loadAvailability(for userEmail: String, days: Int = 7) async {
        guard isConnected else {
            errorMessage = "Google Calendar not connected"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let startDate = Date()
            let endDate = Calendar.current.date(byAdding: .day, value: days, to: startDate) ?? startDate

            availability = try await calendarRepository.getAvailability(
                for: userEmail,
                from: startDate,
                to: endDate
            )
        } catch {
            errorMessage = localizeError(error)
        }

        isLoading = false
    }

    /// Find common free slots for multiple users
    /// - Parameters:
    ///   - userEmails: Array of Google Calendar emails
    ///   - days: Number of days ahead to check (default 7)
    ///   - meetingDurationMinutes: Desired meeting duration (default 30)
    func findCommonFreeSlots(
        for userEmails: [String],
        days: Int = 7,
        meetingDurationMinutes: Int = 30
    ) async {
        guard isConnected else {
            errorMessage = "Google Calendar not connected"
            return
        }

        guard !userEmails.isEmpty else {
            errorMessage = "No users specified"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let startDate = Date()
            let endDate = Calendar.current.date(byAdding: .day, value: days, to: startDate) ?? startDate

            let availabilities = try await calendarRepository.getAvailabilityForMultipleUsers(
                userEmails: userEmails,
                from: startDate,
                to: endDate
            )

            // Find common free slots
            commonFreeSlots = CalendarAvailability.findCommonFreeSlots(
                availabilities: availabilities,
                duration: TimeInterval(meetingDurationMinutes * 60)
            )
        } catch {
            errorMessage = localizeError(error)
        }

        isLoading = false
    }

    // MARK: - Private Helpers

    /// Observe calendar connection status changes
    private func observeConnectionStatus() {
        calendarRepository.observeConnectionStatus()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connected in
                self?.isConnected = connected
            }
            .store(in: &cancellables)
    }

    /// Convert Error to user-friendly localized message
    /// - Parameter error: The error to localize
    /// - Returns: User-friendly error message
    private func localizeError(_ error: Error) -> String {
        if let calendarError = error as? CalendarError {
            return calendarError.localizedDescription
        }

        // Generic error
        return "An error occurred: \(error.localizedDescription)"
    }

    /// Clear error and success messages
    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }
}
