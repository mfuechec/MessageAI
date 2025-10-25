import XCTest
@testable import MessageAI

final class GoogleCalendarMappersTests: XCTestCase {

    // MARK: - Event Mapper Tests

    func testMapEventToAPIFormat() {
        // Arrange
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(3600) // 1 hour later

        let event = CalendarEvent(
            id: "test-event-123",
            title: "Team Meeting",
            description: "Discuss Q4 goals",
            startTime: startTime,
            endTime: endTime,
            location: "Conference Room A",
            attendees: [
                CalendarAttendee(
                    email: "alice@example.com",
                    displayName: "Alice",
                    responseStatus: .accepted,
                    isOptional: false,
                    isOrganizer: true
                ),
                CalendarAttendee(
                    email: "bob@example.com",
                    displayName: "Bob",
                    responseStatus: .needsAction,
                    isOptional: true,
                    isOrganizer: false
                )
            ],
            organizerId: "alice@example.com",
            isAllDay: false,
            timeZone: TimeZone(identifier: "America/Los_Angeles")!,
            conferenceLink: "https://meet.google.com/abc-def-ghi",
            reminders: [
                CalendarReminder(minutesBefore: 15, method: .notification),
                CalendarReminder(minutesBefore: 60, method: .email)
            ],
            status: .confirmed
        )

        // Act
        let apiEvent = GoogleCalendarEventMapper.toAPIFormat(event)

        // Assert
        XCTAssertEqual(apiEvent.id, "test-event-123")
        XCTAssertEqual(apiEvent.summary, "Team Meeting")
        XCTAssertEqual(apiEvent.description, "Discuss Q4 goals")
        XCTAssertEqual(apiEvent.location, "Conference Room A")
        XCTAssertEqual(apiEvent.status, "confirmed")
        XCTAssertNotNil(apiEvent.start.dateTime, "Should have dateTime for non-all-day events")
        XCTAssertNil(apiEvent.start.date, "Should not have date for non-all-day events")
        XCTAssertEqual(apiEvent.start.timeZone, "America/Los_Angeles")
        XCTAssertEqual(apiEvent.attendees?.count, 2)
        XCTAssertEqual(apiEvent.attendees?[0].email, "alice@example.com")
        XCTAssertEqual(apiEvent.attendees?[0].responseStatus, "accepted")
        XCTAssertEqual(apiEvent.attendees?[0].organizer, true)
        XCTAssertEqual(apiEvent.attendees?[1].email, "bob@example.com")
        XCTAssertEqual(apiEvent.attendees?[1].responseStatus, "needsAction")
        XCTAssertEqual(apiEvent.attendees?[1].optional, true)
        XCTAssertEqual(apiEvent.reminders?.overrides?.count, 2)
        XCTAssertEqual(apiEvent.reminders?.overrides?[0].minutes, 15)
        XCTAssertEqual(apiEvent.reminders?.overrides?[0].method, "popup")
        XCTAssertEqual(apiEvent.reminders?.overrides?[1].minutes, 60)
        XCTAssertEqual(apiEvent.reminders?.overrides?[1].method, "email")
        XCTAssertNotNil(apiEvent.conferenceData)
        XCTAssertEqual(apiEvent.conferenceData?.entryPoints?.first?.uri, "https://meet.google.com/abc-def-ghi")
    }

    func testMapAllDayEventToAPIFormat() {
        // Arrange
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let startDate = dateFormatter.date(from: "2025-10-25")!

        let event = CalendarEvent(
            id: "all-day-event",
            title: "Company Holiday",
            startTime: startDate,
            endTime: startDate.addingTimeInterval(86400), // 1 day
            isAllDay: true
        )

        // Act
        let apiEvent = GoogleCalendarEventMapper.toAPIFormat(event)

        // Assert
        XCTAssertNotNil(apiEvent.start.date, "Should have date for all-day events")
        XCTAssertNil(apiEvent.start.dateTime, "Should not have dateTime for all-day events")
        XCTAssertEqual(apiEvent.start.date, "2025-10-25")
    }

    func testMapAPIEventToDomain() {
        // Arrange
        let iso8601 = ISO8601DateFormatter()
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(3600)

        let apiEvent = GoogleCalendarEventAPI(
            id: "api-event-123",
            summary: "Product Demo",
            description: "Demo new features",
            start: GoogleEventDateTime(
                dateTime: iso8601.string(from: startTime),
                date: nil,
                timeZone: "America/New_York"
            ),
            end: GoogleEventDateTime(
                dateTime: iso8601.string(from: endTime),
                date: nil,
                timeZone: "America/New_York"
            ),
            location: "Zoom",
            attendees: [
                GoogleAttendee(
                    email: "charlie@example.com",
                    displayName: "Charlie",
                    responseStatus: "tentative",
                    optional: false,
                    organizer: false
                )
            ],
            organizer: GoogleOrganizer(email: "organizer@example.com", displayName: "Organizer"),
            status: "tentative",
            created: iso8601.string(from: Date()),
            updated: iso8601.string(from: Date()),
            reminders: GoogleReminders(
                useDefault: false,
                overrides: [
                    GoogleReminderOverride(method: "email", minutes: 30)
                ]
            ),
            conferenceData: nil
        )

        // Act
        let domainEvent = GoogleCalendarEventMapper.toDomain(apiEvent)

        // Assert
        XCTAssertEqual(domainEvent.id, "api-event-123")
        XCTAssertEqual(domainEvent.title, "Product Demo")
        XCTAssertEqual(domainEvent.description, "Demo new features")
        XCTAssertEqual(domainEvent.location, "Zoom")
        XCTAssertEqual(domainEvent.status, .tentative)
        XCTAssertFalse(domainEvent.isAllDay)
        XCTAssertEqual(domainEvent.attendees.count, 1)
        XCTAssertEqual(domainEvent.attendees[0].email, "charlie@example.com")
        XCTAssertEqual(domainEvent.attendees[0].responseStatus, .tentative)
        XCTAssertEqual(domainEvent.reminders.count, 1)
        XCTAssertEqual(domainEvent.reminders[0].minutesBefore, 30)
        XCTAssertEqual(domainEvent.reminders[0].method, .email)
        XCTAssertNil(domainEvent.conferenceLink)
    }

    func testMapAPIEventWithConferenceDataToDomain() {
        // Arrange
        let iso8601 = ISO8601DateFormatter()
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(3600)

        let apiEvent = GoogleCalendarEventAPI(
            id: "conf-event",
            summary: "Video Call",
            description: nil,
            start: GoogleEventDateTime(
                dateTime: iso8601.string(from: startTime),
                date: nil,
                timeZone: nil
            ),
            end: GoogleEventDateTime(
                dateTime: iso8601.string(from: endTime),
                date: nil,
                timeZone: nil
            ),
            location: nil,
            attendees: nil,
            organizer: nil,
            status: "confirmed",
            created: nil,
            updated: nil,
            reminders: nil,
            conferenceData: GoogleConferenceData(entryPoints: [
                GoogleConferenceEntryPoint(entryPointType: "video", uri: "https://zoom.us/j/123456789")
            ])
        )

        // Act
        let domainEvent = GoogleCalendarEventMapper.toDomain(apiEvent)

        // Assert
        XCTAssertEqual(domainEvent.conferenceLink, "https://zoom.us/j/123456789")
    }

    // MARK: - Availability Mapper Tests

    func testMapFreeBusyResponseToDomain() {
        // Arrange
        let iso8601 = ISO8601DateFormatter()
        let now = Date()
        let busyStart1 = now.addingTimeInterval(3600) // 1 hour from now
        let busyEnd1 = busyStart1.addingTimeInterval(1800) // 30 min busy
        let busyStart2 = busyEnd1.addingTimeInterval(7200) // 2 hours gap
        let busyEnd2 = busyStart2.addingTimeInterval(3600) // 1 hour busy

        let response = GoogleFreeBusyResponse(
            calendars: [
                "user@example.com": GoogleCalendarBusy(busy: [
                    GoogleTimePeriod(
                        start: iso8601.string(from: busyStart1),
                        end: iso8601.string(from: busyEnd1)
                    ),
                    GoogleTimePeriod(
                        start: iso8601.string(from: busyStart2),
                        end: iso8601.string(from: busyEnd2)
                    )
                ])
            ]
        )

        let queriedFrom = now
        let queriedTo = now.addingTimeInterval(86400) // 1 day

        // Act
        let availability = GoogleCalendarAvailabilityMapper.toDomain(
            response,
            userId: "user@example.com",
            queriedFrom: queriedFrom,
            queriedTo: queriedTo
        )

        // Assert
        XCTAssertEqual(availability.userId, "user@example.com")
        XCTAssertEqual(availability.queriedFrom, queriedFrom)
        XCTAssertEqual(availability.queriedTo, queriedTo)

        let busySlots = availability.busySlots
        XCTAssertEqual(busySlots.count, 2, "Should have 2 busy slots")

        let freeSlots = availability.freeSlots
        XCTAssertGreaterThan(freeSlots.count, 0, "Should have free slots in gaps")
    }

    func testMapEmptyFreeBusyResponse() {
        // Arrange
        let response = GoogleFreeBusyResponse(calendars: [:])
        let queriedFrom = Date()
        let queriedTo = queriedFrom.addingTimeInterval(86400)

        // Act
        let availability = GoogleCalendarAvailabilityMapper.toDomain(
            response,
            userId: "user@example.com",
            queriedFrom: queriedFrom,
            queriedTo: queriedTo
        )

        // Assert
        XCTAssertEqual(availability.timeSlots.count, 1, "Should have one free slot covering entire range")
        XCTAssertEqual(availability.timeSlots.first?.status, .free)
    }

    // MARK: - Round-Trip Tests

    func testEventRoundTrip() {
        // Arrange
        let originalEvent = CalendarEvent(
            id: "round-trip-test",
            title: "Test Event",
            description: "Test Description",
            startTime: Date(),
            endTime: Date().addingTimeInterval(3600),
            location: "Test Location",
            attendees: [
                CalendarAttendee(email: "test@example.com", responseStatus: .accepted)
            ],
            status: .confirmed
        )

        // Act
        let apiEvent = GoogleCalendarEventMapper.toAPIFormat(originalEvent)
        let roundTripEvent = GoogleCalendarEventMapper.toDomain(apiEvent)

        // Assert
        XCTAssertEqual(roundTripEvent.title, originalEvent.title)
        XCTAssertEqual(roundTripEvent.description, originalEvent.description)
        XCTAssertEqual(roundTripEvent.location, originalEvent.location)
        XCTAssertEqual(roundTripEvent.status, originalEvent.status)
        XCTAssertEqual(roundTripEvent.attendees.count, originalEvent.attendees.count)
        XCTAssertEqual(roundTripEvent.attendees.first?.email, originalEvent.attendees.first?.email)
    }
}
