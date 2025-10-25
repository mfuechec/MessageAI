import Foundation

/// Core domain entity representing a calendar event
struct CalendarEvent: Codable, Equatable, Identifiable {
    let id: String
    var title: String
    var description: String?
    var startTime: Date
    var endTime: Date
    var location: String?
    var attendees: [CalendarAttendee]
    var organizerId: String?
    var isAllDay: Bool
    var timeZone: TimeZone
    var conferenceLink: String?
    var reminders: [CalendarReminder]
    var status: EventStatus
    let createdAt: Date
    var updatedAt: Date
    let schemaVersion: Int

    /// Computed property for event duration in minutes
    var durationMinutes: Int {
        Int(endTime.timeIntervalSince(startTime) / 60)
    }

    /// Computed property to check if event is happening now
    var isHappeningNow: Bool {
        let now = Date()
        return now >= startTime && now <= endTime
    }

    /// Computed property to check if event is in the past
    var isPast: Bool {
        Date() > endTime
    }

    init(
        id: String = UUID().uuidString,
        title: String,
        description: String? = nil,
        startTime: Date,
        endTime: Date,
        location: String? = nil,
        attendees: [CalendarAttendee] = [],
        organizerId: String? = nil,
        isAllDay: Bool = false,
        timeZone: TimeZone = .current,
        conferenceLink: String? = nil,
        reminders: [CalendarReminder] = [],
        status: EventStatus = .confirmed,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        schemaVersion: Int = 1
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.startTime = startTime
        self.endTime = endTime
        self.location = location
        self.attendees = attendees
        self.organizerId = organizerId
        self.isAllDay = isAllDay
        self.timeZone = timeZone
        self.conferenceLink = conferenceLink
        self.reminders = reminders
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.schemaVersion = schemaVersion
    }
}

/// Event status according to calendar standards
enum EventStatus: String, Codable {
    case confirmed
    case tentative
    case cancelled
}

/// Calendar event attendee
struct CalendarAttendee: Codable, Equatable {
    let email: String
    var displayName: String?
    var responseStatus: AttendeeResponseStatus
    var isOptional: Bool
    var isOrganizer: Bool

    init(
        email: String,
        displayName: String? = nil,
        responseStatus: AttendeeResponseStatus = .needsAction,
        isOptional: Bool = false,
        isOrganizer: Bool = false
    ) {
        self.email = email
        self.displayName = displayName
        self.responseStatus = responseStatus
        self.isOptional = isOptional
        self.isOrganizer = isOrganizer
    }
}

/// Attendee response status according to calendar standards
enum AttendeeResponseStatus: String, Codable {
    case needsAction
    case accepted
    case declined
    case tentative
}

/// Calendar event reminder
struct CalendarReminder: Codable, Equatable {
    var minutesBefore: Int
    var method: ReminderMethod

    init(minutesBefore: Int, method: ReminderMethod = .notification) {
        self.minutesBefore = minutesBefore
        self.method = method
    }
}

/// Reminder delivery method
enum ReminderMethod: String, Codable {
    case notification
    case email
}
