import Foundation
import Combine

/// Protocol defining calendar data operations (implemented in Data layer)
protocol CalendarRepositoryProtocol {
    /// Authenticate with Google Calendar OAuth
    /// - Returns: True if authentication successful
    func authenticateWithGoogle() async throws -> Bool

    /// Disconnect Google Calendar integration
    func disconnectGoogleCalendar() async throws

    /// Check if user has active Google Calendar connection
    /// - Returns: True if connected
    func isConnected() async -> Bool

    /// Create a new calendar event
    /// - Parameter event: The calendar event to create
    /// - Returns: The created event with Google Calendar ID
    func createEvent(_ event: CalendarEvent) async throws -> CalendarEvent

    /// Get upcoming events within a date range
    /// - Parameters:
    ///   - startDate: Start of date range
    ///   - endDate: End of date range
    ///   - maxResults: Maximum number of events to fetch (default 50)
    /// - Returns: Array of calendar events
    func getEvents(from startDate: Date, to endDate: Date, maxResults: Int) async throws -> [CalendarEvent]

    /// Update an existing calendar event
    /// - Parameter event: The event with updated information
    func updateEvent(_ event: CalendarEvent) async throws

    /// Delete a calendar event
    /// - Parameter eventId: The Google Calendar event ID
    func deleteEvent(eventId: String) async throws

    /// Get free/busy availability for specified time range
    /// - Parameters:
    ///   - userEmail: Google Calendar email to query
    ///   - startDate: Start of date range
    ///   - endDate: End of date range
    /// - Returns: Availability information with free/busy slots
    func getAvailability(
        for userEmail: String,
        from startDate: Date,
        to endDate: Date
    ) async throws -> CalendarAvailability

    /// Get free/busy availability for multiple users
    /// - Parameters:
    ///   - userEmails: Array of Google Calendar emails to query
    ///   - startDate: Start of date range
    ///   - endDate: End of date range
    /// - Returns: Array of availability information for each user
    func getAvailabilityForMultipleUsers(
        userEmails: [String],
        from startDate: Date,
        to endDate: Date
    ) async throws -> [CalendarAvailability]

    /// Observe calendar connection status changes
    /// - Returns: Publisher emitting connection status updates
    func observeConnectionStatus() -> AnyPublisher<Bool, Never>
}
