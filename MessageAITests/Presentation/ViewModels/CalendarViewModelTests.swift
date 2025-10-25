import XCTest
@testable import MessageAI

@MainActor
final class CalendarViewModelTests: XCTestCase {
    var mockCalendarRepository: MockCalendarRepository!
    var viewModel: CalendarViewModel!

    override func setUp() {
        super.setUp()
        mockCalendarRepository = MockCalendarRepository()
        viewModel = CalendarViewModel(calendarRepository: mockCalendarRepository)
    }

    override func tearDown() {
        viewModel = nil
        mockCalendarRepository = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialState() {
        // Assert initial state
        XCTAssertFalse(viewModel.isConnected, "Should not be connected initially")
        XCTAssertFalse(viewModel.isLoading, "Should not be loading initially")
        XCTAssertNil(viewModel.errorMessage, "Error message should be nil initially")
        XCTAssertNil(viewModel.successMessage, "Success message should be nil initially")
        XCTAssertTrue(viewModel.upcomingEvents.isEmpty, "Events should be empty initially")
        XCTAssertNil(viewModel.availability, "Availability should be nil initially")
        XCTAssertTrue(viewModel.commonFreeSlots.isEmpty, "Free slots should be empty initially")
    }

    // MARK: - Connection Tests

    func testConnectGoogleCalendarSuccess() async {
        // Arrange
        mockCalendarRepository.mockIsConnected = false

        // Act
        await viewModel.connectGoogleCalendar()

        // Assert
        XCTAssertTrue(mockCalendarRepository.authenticateWithGoogleCalled, "Should call authenticate")
        XCTAssertTrue(viewModel.isConnected, "Should be connected after success")
        XCTAssertFalse(viewModel.isLoading, "Should not be loading after completion")
        XCTAssertNil(viewModel.errorMessage, "Should have no error message")
        XCTAssertNotNil(viewModel.successMessage, "Should have success message")
    }

    func testConnectGoogleCalendarFailure() async {
        // Arrange
        mockCalendarRepository.shouldFail = true
        mockCalendarRepository.mockError = CalendarError.apiError("Auth failed")

        // Act
        await viewModel.connectGoogleCalendar()

        // Assert
        XCTAssertTrue(mockCalendarRepository.authenticateWithGoogleCalled, "Should call authenticate")
        XCTAssertFalse(viewModel.isConnected, "Should not be connected after failure")
        XCTAssertFalse(viewModel.isLoading, "Should not be loading after completion")
        XCTAssertNotNil(viewModel.errorMessage, "Should have error message")
        XCTAssertNil(viewModel.successMessage, "Should have no success message")
    }

    func testDisconnectGoogleCalendar() async {
        // Arrange
        mockCalendarRepository.simulateConnection()
        await viewModel.checkConnectionStatus()
        XCTAssertTrue(viewModel.isConnected, "Should be connected before disconnect")

        // Act
        await viewModel.disconnectGoogleCalendar()

        // Assert
        XCTAssertTrue(mockCalendarRepository.disconnectGoogleCalendarCalled, "Should call disconnect")
        XCTAssertFalse(viewModel.isConnected, "Should not be connected after disconnect")
        XCTAssertTrue(viewModel.upcomingEvents.isEmpty, "Events should be cleared")
        XCTAssertNil(viewModel.availability, "Availability should be cleared")
        XCTAssertNotNil(viewModel.successMessage, "Should have success message")
    }

    func testCheckConnectionStatus() async {
        // Arrange
        mockCalendarRepository.simulateConnection()

        // Act
        await viewModel.checkConnectionStatus()

        // Assert
        XCTAssertTrue(mockCalendarRepository.isConnectedCalled, "Should call isConnected")
        XCTAssertTrue(viewModel.isConnected, "Should reflect connection status")
    }

    // MARK: - Event Management Tests

    func testCreateEventSuccess() async {
        // Arrange
        mockCalendarRepository.simulateConnection()
        let event = CalendarEvent(
            title: "Test Meeting",
            startTime: Date(),
            endTime: Date().addingTimeInterval(3600)
        )

        // Act
        await viewModel.createEvent(event)

        // Assert
        XCTAssertTrue(mockCalendarRepository.createEventCalled, "Should call createEvent")
        XCTAssertEqual(viewModel.upcomingEvents.count, 1, "Should have one event")
        XCTAssertEqual(viewModel.upcomingEvents.first?.title, "Test Meeting")
        XCTAssertNotNil(viewModel.successMessage, "Should have success message")
        XCTAssertNil(viewModel.errorMessage, "Should have no error message")
    }

    func testCreateEventFromMessage() async {
        // Arrange
        mockCalendarRepository.simulateConnection()
        let startTime = Date()

        // Act
        await viewModel.createEventFromMessage(
            title: "Team Meeting",
            startTime: startTime,
            durationMinutes: 60,
            description: "Discuss Q4 goals",
            attendeeEmails: ["alice@example.com", "bob@example.com"]
        )

        // Assert
        XCTAssertTrue(mockCalendarRepository.createEventCalled, "Should call createEvent")
        XCTAssertEqual(mockCalendarRepository.capturedEvent?.title, "Team Meeting")
        XCTAssertEqual(mockCalendarRepository.capturedEvent?.attendees.count, 2)
        XCTAssertEqual(viewModel.upcomingEvents.count, 1, "Should have created event")
    }

    func testLoadUpcomingEventsSuccess() async {
        // Arrange
        mockCalendarRepository.simulateConnection()
        let event1 = CalendarEvent(
            title: "Event 1",
            startTime: Date(),
            endTime: Date().addingTimeInterval(3600)
        )
        let event2 = CalendarEvent(
            title: "Event 2",
            startTime: Date().addingTimeInterval(86400),
            endTime: Date().addingTimeInterval(90000)
        )
        mockCalendarRepository.mockEvents = [event1, event2]

        // Act
        await viewModel.loadUpcomingEvents(days: 7)

        // Assert
        XCTAssertTrue(mockCalendarRepository.getEventsCalled, "Should call getEvents")
        XCTAssertEqual(viewModel.upcomingEvents.count, 2, "Should load 2 events")
        XCTAssertFalse(viewModel.isLoading, "Should not be loading after completion")
        XCTAssertNil(viewModel.errorMessage, "Should have no error message")
    }

    func testLoadUpcomingEventsWhenNotConnected() async {
        // Arrange
        mockCalendarRepository.mockIsConnected = false

        // Act
        await viewModel.loadUpcomingEvents()

        // Assert
        XCTAssertFalse(mockCalendarRepository.getEventsCalled, "Should not call getEvents")
        XCTAssertNotNil(viewModel.errorMessage, "Should have error message")
        XCTAssertTrue(viewModel.errorMessage!.contains("not connected"), "Error should mention not connected")
    }

    func testUpdateEvent() async {
        // Arrange
        mockCalendarRepository.simulateConnection()
        var event = CalendarEvent(
            id: "event-1",
            title: "Original Title",
            startTime: Date(),
            endTime: Date().addingTimeInterval(3600)
        )
        viewModel.upcomingEvents = [event]

        // Modify event
        event.title = "Updated Title"

        // Act
        await viewModel.updateEvent(event)

        // Assert
        XCTAssertTrue(mockCalendarRepository.updateEventCalled, "Should call updateEvent")
        XCTAssertEqual(viewModel.upcomingEvents.first?.title, "Updated Title")
        XCTAssertNotNil(viewModel.successMessage, "Should have success message")
    }

    func testDeleteEvent() async {
        // Arrange
        mockCalendarRepository.simulateConnection()
        let event = CalendarEvent(
            id: "event-1",
            title: "Test Event",
            startTime: Date(),
            endTime: Date().addingTimeInterval(3600)
        )
        viewModel.upcomingEvents = [event]

        // Act
        await viewModel.deleteEvent(eventId: "event-1")

        // Assert
        XCTAssertTrue(mockCalendarRepository.deleteEventCalled, "Should call deleteEvent")
        XCTAssertEqual(mockCalendarRepository.capturedEventId, "event-1")
        XCTAssertTrue(viewModel.upcomingEvents.isEmpty, "Event should be removed")
        XCTAssertNotNil(viewModel.successMessage, "Should have success message")
    }

    // MARK: - Availability Tests

    func testLoadAvailability() async {
        // Arrange
        mockCalendarRepository.simulateConnection()
        let availability = CalendarAvailability(
            userId: "user@example.com",
            timeSlots: [
                TimeSlot(startTime: Date(), endTime: Date().addingTimeInterval(3600), status: .free)
            ],
            queriedFrom: Date(),
            queriedTo: Date().addingTimeInterval(86400)
        )
        mockCalendarRepository.mockAvailability = availability

        // Act
        await viewModel.loadAvailability(for: "user@example.com", days: 7)

        // Assert
        XCTAssertTrue(mockCalendarRepository.getAvailabilityCalled, "Should call getAvailability")
        XCTAssertEqual(mockCalendarRepository.capturedUserEmail, "user@example.com")
        XCTAssertNotNil(viewModel.availability, "Availability should be loaded")
        XCTAssertEqual(viewModel.availability?.timeSlots.count, 1)
    }

    func testFindCommonFreeSlots() async {
        // Arrange
        mockCalendarRepository.simulateConnection()
        let userEmails = ["alice@example.com", "bob@example.com"]

        let availability1 = CalendarAvailability(
            userId: userEmails[0],
            timeSlots: [
                TimeSlot(startTime: Date(), endTime: Date().addingTimeInterval(3600), status: .free)
            ],
            queriedFrom: Date(),
            queriedTo: Date().addingTimeInterval(86400)
        )

        let availability2 = CalendarAvailability(
            userId: userEmails[1],
            timeSlots: [
                TimeSlot(startTime: Date(), endTime: Date().addingTimeInterval(3600), status: .free)
            ],
            queriedFrom: Date(),
            queriedTo: Date().addingTimeInterval(86400)
        )

        mockCalendarRepository.mockMultipleAvailabilities = [availability1, availability2]

        // Act
        await viewModel.findCommonFreeSlots(
            for: userEmails,
            days: 7,
            meetingDurationMinutes: 30
        )

        // Assert
        XCTAssertTrue(mockCalendarRepository.getAvailabilityForMultipleUsersCalled, "Should call getAvailabilityForMultipleUsers")
        XCTAssertEqual(mockCalendarRepository.capturedUserEmails, userEmails)
        XCTAssertFalse(viewModel.isLoading, "Should not be loading after completion")
    }

    func testFindCommonFreeSlotsWithEmptyUsers() async {
        // Arrange
        mockCalendarRepository.simulateConnection()

        // Act
        await viewModel.findCommonFreeSlots(for: [], days: 7, meetingDurationMinutes: 30)

        // Assert
        XCTAssertFalse(mockCalendarRepository.getAvailabilityForMultipleUsersCalled, "Should not call API with empty users")
        XCTAssertNotNil(viewModel.errorMessage, "Should have error message")
    }

    // MARK: - Helper Tests

    func testClearMessages() {
        // Arrange
        viewModel.errorMessage = "Test error"
        viewModel.successMessage = "Test success"

        // Act
        viewModel.clearMessages()

        // Assert
        XCTAssertNil(viewModel.errorMessage, "Error message should be cleared")
        XCTAssertNil(viewModel.successMessage, "Success message should be cleared")
    }
}
