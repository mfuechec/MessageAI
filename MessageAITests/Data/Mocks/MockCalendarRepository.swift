import Foundation
import Combine
@testable import MessageAI

/// Mock implementation of CalendarRepositoryProtocol for testing
class MockCalendarRepository: CalendarRepositoryProtocol {
    // MARK: - Tracking Properties

    var authenticateWithGoogleCalled = false
    var disconnectGoogleCalendarCalled = false
    var isConnectedCalled = false
    var createEventCalled = false
    var getEventsCalled = false
    var updateEventCalled = false
    var deleteEventCalled = false
    var getAvailabilityCalled = false
    var getAvailabilityForMultipleUsersCalled = false
    var shouldFail = false

    // MARK: - Configurable Properties

    var mockIsConnected = false
    var mockEvents: [CalendarEvent] = []
    var mockAvailability: CalendarAvailability?
    var mockMultipleAvailabilities: [CalendarAvailability] = []
    var mockError: Error?

    // MARK: - Captured Parameters

    var capturedEvent: CalendarEvent?
    var capturedStartDate: Date?
    var capturedEndDate: Date?
    var capturedMaxResults: Int?
    var capturedEventId: String?
    var capturedUserEmail: String?
    var capturedUserEmails: [String]?

    // MARK: - Combine Publishers

    private let connectionStatusSubject = CurrentValueSubject<Bool, Never>(false)

    // MARK: - CalendarRepositoryProtocol Implementation

    func authenticateWithGoogle() async throws -> Bool {
        authenticateWithGoogleCalled = true

        if shouldFail {
            throw mockError ?? CalendarError.apiError("Mock authentication failure")
        }

        mockIsConnected = true
        connectionStatusSubject.send(true)
        return true
    }

    func disconnectGoogleCalendar() async throws {
        disconnectGoogleCalendarCalled = true

        if shouldFail {
            throw mockError ?? CalendarError.apiError("Mock disconnection failure")
        }

        mockIsConnected = false
        connectionStatusSubject.send(false)
    }

    func isConnected() async -> Bool {
        isConnectedCalled = true
        return mockIsConnected
    }

    func createEvent(_ event: CalendarEvent) async throws -> CalendarEvent {
        createEventCalled = true
        capturedEvent = event

        if shouldFail {
            throw mockError ?? CalendarError.apiError("Mock create event failure")
        }

        // Add event to mock events
        var createdEvent = event
        if createdEvent.id.isEmpty {
            createdEvent = CalendarEvent(
                id: UUID().uuidString,
                title: event.title,
                description: event.description,
                startTime: event.startTime,
                endTime: event.endTime,
                location: event.location,
                attendees: event.attendees,
                organizerId: event.organizerId,
                isAllDay: event.isAllDay,
                timeZone: event.timeZone,
                conferenceLink: event.conferenceLink,
                reminders: event.reminders,
                status: event.status
            )
        }

        mockEvents.append(createdEvent)
        return createdEvent
    }

    func getEvents(from startDate: Date, to endDate: Date, maxResults: Int = 50) async throws -> [CalendarEvent] {
        getEventsCalled = true
        capturedStartDate = startDate
        capturedEndDate = endDate
        capturedMaxResults = maxResults

        if shouldFail {
            throw mockError ?? CalendarError.apiError("Mock get events failure")
        }

        // Filter events within date range
        let filteredEvents = mockEvents.filter { event in
            event.startTime >= startDate && event.startTime <= endDate
        }

        return Array(filteredEvents.prefix(maxResults))
    }

    func updateEvent(_ event: CalendarEvent) async throws {
        updateEventCalled = true
        capturedEvent = event

        if shouldFail {
            throw mockError ?? CalendarError.apiError("Mock update event failure")
        }

        // Update event in mockEvents
        if let index = mockEvents.firstIndex(where: { $0.id == event.id }) {
            var updatedEvent = event
            updatedEvent = CalendarEvent(
                id: event.id,
                title: event.title,
                description: event.description,
                startTime: event.startTime,
                endTime: event.endTime,
                location: event.location,
                attendees: event.attendees,
                organizerId: event.organizerId,
                isAllDay: event.isAllDay,
                timeZone: event.timeZone,
                conferenceLink: event.conferenceLink,
                reminders: event.reminders,
                status: event.status,
                createdAt: mockEvents[index].createdAt,
                updatedAt: Date()
            )
            mockEvents[index] = updatedEvent
        }
    }

    func deleteEvent(eventId: String) async throws {
        deleteEventCalled = true
        capturedEventId = eventId

        if shouldFail {
            throw mockError ?? CalendarError.apiError("Mock delete event failure")
        }

        // Remove event from mockEvents
        mockEvents.removeAll { $0.id == eventId }
    }

    func getAvailability(
        for userEmail: String,
        from startDate: Date,
        to endDate: Date
    ) async throws -> CalendarAvailability {
        getAvailabilityCalled = true
        capturedUserEmail = userEmail
        capturedStartDate = startDate
        capturedEndDate = endDate

        if shouldFail {
            throw mockError ?? CalendarError.apiError("Mock get availability failure")
        }

        if let availability = mockAvailability {
            return availability
        }

        // Return default free availability
        return CalendarAvailability(
            userId: userEmail,
            timeSlots: [
                TimeSlot(startTime: startDate, endTime: endDate, status: .free)
            ],
            queriedFrom: startDate,
            queriedTo: endDate
        )
    }

    func getAvailabilityForMultipleUsers(
        userEmails: [String],
        from startDate: Date,
        to endDate: Date
    ) async throws -> [CalendarAvailability] {
        getAvailabilityForMultipleUsersCalled = true
        capturedUserEmails = userEmails
        capturedStartDate = startDate
        capturedEndDate = endDate

        if shouldFail {
            throw mockError ?? CalendarError.apiError("Mock get multiple availabilities failure")
        }

        if !mockMultipleAvailabilities.isEmpty {
            return mockMultipleAvailabilities
        }

        // Return default free availability for each user
        return userEmails.map { email in
            CalendarAvailability(
                userId: email,
                timeSlots: [
                    TimeSlot(startTime: startDate, endTime: endDate, status: .free)
                ],
                queriedFrom: startDate,
                queriedTo: endDate
            )
        }
    }

    func observeConnectionStatus() -> AnyPublisher<Bool, Never> {
        return connectionStatusSubject.eraseToAnyPublisher()
    }

    // MARK: - Helper Methods

    /// Resets all tracking and configurable properties
    func reset() {
        authenticateWithGoogleCalled = false
        disconnectGoogleCalendarCalled = false
        isConnectedCalled = false
        createEventCalled = false
        getEventsCalled = false
        updateEventCalled = false
        deleteEventCalled = false
        getAvailabilityCalled = false
        getAvailabilityForMultipleUsersCalled = false
        shouldFail = false
        mockIsConnected = false
        mockEvents = []
        mockAvailability = nil
        mockMultipleAvailabilities = []
        mockError = nil
        capturedEvent = nil
        capturedStartDate = nil
        capturedEndDate = nil
        capturedMaxResults = nil
        capturedEventId = nil
        capturedUserEmail = nil
        capturedUserEmails = nil
        connectionStatusSubject.send(false)
    }

    /// Convenience method to simulate successful connection
    func simulateConnection() {
        mockIsConnected = true
        connectionStatusSubject.send(true)
    }

    /// Convenience method to simulate disconnection
    func simulateDisconnection() {
        mockIsConnected = false
        connectionStatusSubject.send(false)
    }
}
