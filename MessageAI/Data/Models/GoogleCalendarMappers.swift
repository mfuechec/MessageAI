import Foundation

// MARK: - Google Calendar API Models

/// Google Calendar Event API representation
struct GoogleCalendarEventAPI: Codable {
    let id: String?
    var summary: String  // Event title
    var description: String?
    var start: GoogleEventDateTime
    var end: GoogleEventDateTime
    var location: String?
    var attendees: [GoogleAttendee]?
    var organizer: GoogleOrganizer?
    var status: String?  // "confirmed", "tentative", "cancelled"
    var created: String?  // ISO 8601 timestamp
    var updated: String?  // ISO 8601 timestamp
    var reminders: GoogleReminders?
    var conferenceData: GoogleConferenceData?
}

struct GoogleEventDateTime: Codable {
    var dateTime: String?  // ISO 8601 with timezone
    var date: String?  // YYYY-MM-DD for all-day events
    var timeZone: String?
}

struct GoogleAttendee: Codable {
    var email: String
    var displayName: String?
    var responseStatus: String?  // "needsAction", "accepted", "declined", "tentative"
    var optional: Bool?
    var organizer: Bool?
}

struct GoogleOrganizer: Codable {
    var email: String
    var displayName: String?
}

struct GoogleReminders: Codable {
    var useDefault: Bool?
    var overrides: [GoogleReminderOverride]?
}

struct GoogleReminderOverride: Codable {
    var method: String  // "email", "popup"
    var minutes: Int
}

struct GoogleConferenceData: Codable {
    var entryPoints: [GoogleConferenceEntryPoint]?
}

struct GoogleConferenceEntryPoint: Codable {
    var entryPointType: String  // "video", "phone"
    var uri: String
}

struct GoogleCalendarEventsListResponse: Codable {
    let items: [GoogleCalendarEventAPI]
    let nextPageToken: String?
}

// MARK: - FreeBusy API Models

struct GoogleFreeBusyResponse: Codable {
    let calendars: [String: GoogleCalendarBusy]
}

struct GoogleCalendarBusy: Codable {
    let busy: [GoogleTimePeriod]
}

struct GoogleTimePeriod: Codable {
    let start: String  // ISO 8601
    let end: String    // ISO 8601
}

// MARK: - Event Mapper

/// Maps between Google Calendar API format and domain CalendarEvent entity
enum GoogleCalendarEventMapper {

    /// Convert domain CalendarEvent to Google Calendar API format
    static func toAPIFormat(_ event: CalendarEvent) -> GoogleCalendarEventAPI {
        let iso8601 = ISO8601DateFormatter()
        iso8601.timeZone = event.timeZone

        let start: GoogleEventDateTime
        let end: GoogleEventDateTime

        if event.isAllDay {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            dateFormatter.timeZone = event.timeZone

            start = GoogleEventDateTime(
                dateTime: nil,
                date: dateFormatter.string(from: event.startTime),
                timeZone: nil
            )
            end = GoogleEventDateTime(
                dateTime: nil,
                date: dateFormatter.string(from: event.endTime),
                timeZone: nil
            )
        } else {
            start = GoogleEventDateTime(
                dateTime: iso8601.string(from: event.startTime),
                date: nil,
                timeZone: event.timeZone.identifier
            )
            end = GoogleEventDateTime(
                dateTime: iso8601.string(from: event.endTime),
                date: nil,
                timeZone: event.timeZone.identifier
            )
        }

        let attendees = event.attendees.map { attendee -> GoogleAttendee in
            GoogleAttendee(
                email: attendee.email,
                displayName: attendee.displayName,
                responseStatus: mapResponseStatus(attendee.responseStatus),
                optional: attendee.isOptional,
                organizer: attendee.isOrganizer
            )
        }

        let reminders: GoogleReminders? = event.reminders.isEmpty ? nil : GoogleReminders(
            useDefault: false,
            overrides: event.reminders.map { reminder in
                GoogleReminderOverride(
                    method: reminder.method == .email ? "email" : "popup",
                    minutes: reminder.minutesBefore
                )
            }
        )

        return GoogleCalendarEventAPI(
            id: event.id,
            summary: event.title,
            description: event.description,
            start: start,
            end: end,
            location: event.location,
            attendees: attendees.isEmpty ? nil : attendees,
            organizer: event.organizerId.map { GoogleOrganizer(email: $0, displayName: nil) },
            status: mapEventStatus(event.status),
            created: iso8601.string(from: event.createdAt),
            updated: iso8601.string(from: event.updatedAt),
            reminders: reminders,
            conferenceData: event.conferenceLink.map { link in
                GoogleConferenceData(entryPoints: [
                    GoogleConferenceEntryPoint(entryPointType: "video", uri: link)
                ])
            }
        )
    }

    /// Convert Google Calendar API format to domain CalendarEvent
    static func toDomain(_ apiEvent: GoogleCalendarEventAPI) -> CalendarEvent {
        let iso8601 = ISO8601DateFormatter()

        let startTime: Date
        let endTime: Date
        let isAllDay: Bool
        let timeZone: TimeZone

        if let startDateTime = apiEvent.start.dateTime {
            startTime = iso8601.date(from: startDateTime) ?? Date()
            endTime = iso8601.date(from: apiEvent.end.dateTime ?? "") ?? Date()
            isAllDay = false
            timeZone = TimeZone(identifier: apiEvent.start.timeZone ?? "") ?? .current
        } else if let startDate = apiEvent.start.date {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            startTime = dateFormatter.date(from: startDate) ?? Date()
            endTime = dateFormatter.date(from: apiEvent.end.date ?? "") ?? Date()
            isAllDay = true
            timeZone = .current
        } else {
            startTime = Date()
            endTime = Date()
            isAllDay = false
            timeZone = .current
        }

        let attendees = (apiEvent.attendees ?? []).map { googleAttendee -> CalendarAttendee in
            CalendarAttendee(
                email: googleAttendee.email,
                displayName: googleAttendee.displayName,
                responseStatus: mapResponseStatusToDomain(googleAttendee.responseStatus ?? "needsAction"),
                isOptional: googleAttendee.optional ?? false,
                isOrganizer: googleAttendee.organizer ?? false
            )
        }

        let reminders = (apiEvent.reminders?.overrides ?? []).map { override -> CalendarReminder in
            CalendarReminder(
                minutesBefore: override.minutes,
                method: override.method == "email" ? .email : .notification
            )
        }

        let conferenceLink = apiEvent.conferenceData?.entryPoints?
            .first(where: { $0.entryPointType == "video" })?
            .uri

        return CalendarEvent(
            id: apiEvent.id ?? UUID().uuidString,
            title: apiEvent.summary,
            description: apiEvent.description,
            startTime: startTime,
            endTime: endTime,
            location: apiEvent.location,
            attendees: attendees,
            organizerId: apiEvent.organizer?.email,
            isAllDay: isAllDay,
            timeZone: timeZone,
            conferenceLink: conferenceLink,
            reminders: reminders,
            status: mapEventStatusToDomain(apiEvent.status ?? "confirmed"),
            createdAt: iso8601.date(from: apiEvent.created ?? "") ?? Date(),
            updatedAt: iso8601.date(from: apiEvent.updated ?? "") ?? Date()
        )
    }

    // MARK: - Helper Mappers

    private static func mapEventStatus(_ status: EventStatus) -> String {
        switch status {
        case .confirmed: return "confirmed"
        case .tentative: return "tentative"
        case .cancelled: return "cancelled"
        }
    }

    private static func mapEventStatusToDomain(_ status: String) -> EventStatus {
        switch status {
        case "confirmed": return .confirmed
        case "tentative": return .tentative
        case "cancelled": return .cancelled
        default: return .confirmed
        }
    }

    private static func mapResponseStatus(_ status: AttendeeResponseStatus) -> String {
        switch status {
        case .needsAction: return "needsAction"
        case .accepted: return "accepted"
        case .declined: return "declined"
        case .tentative: return "tentative"
        }
    }

    private static func mapResponseStatusToDomain(_ status: String) -> AttendeeResponseStatus {
        switch status {
        case "accepted": return .accepted
        case "declined": return .declined
        case "tentative": return .tentative
        default: return .needsAction
        }
    }
}

// MARK: - Availability Mapper

/// Maps between Google FreeBusy API format and domain CalendarAvailability entity
enum GoogleCalendarAvailabilityMapper {

    static func toDomain(
        _ response: GoogleFreeBusyResponse,
        userId: String,
        queriedFrom: Date,
        queriedTo: Date
    ) -> CalendarAvailability {
        let iso8601 = ISO8601DateFormatter()

        // Extract busy slots from the first calendar in response
        let busyPeriods = response.calendars.values.first?.busy ?? []

        let busySlots = busyPeriods.compactMap { period -> TimeSlot? in
            guard let start = iso8601.date(from: period.start),
                  let end = iso8601.date(from: period.end) else {
                return nil
            }
            return TimeSlot(startTime: start, endTime: end, status: .busy)
        }

        // Generate free slots by finding gaps between busy slots
        let freeSlots = generateFreeSlots(
            from: queriedFrom,
            to: queriedTo,
            busySlots: busySlots
        )

        let allSlots = busySlots + freeSlots

        return CalendarAvailability(
            userId: userId,
            timeSlots: allSlots.sorted { $0.startTime < $1.startTime },
            queriedFrom: queriedFrom,
            queriedTo: queriedTo,
            timeZone: .current
        )
    }

    /// Generate free time slots from gaps between busy periods
    private static func generateFreeSlots(
        from startDate: Date,
        to endDate: Date,
        busySlots: [TimeSlot]
    ) -> [TimeSlot] {
        guard !busySlots.isEmpty else {
            // Entire range is free
            return [TimeSlot(startTime: startDate, endTime: endDate, status: .free)]
        }

        var freeSlots: [TimeSlot] = []
        let sortedBusy = busySlots.sorted { $0.startTime < $1.startTime }

        // Free slot before first busy period
        if sortedBusy[0].startTime > startDate {
            freeSlots.append(TimeSlot(
                startTime: startDate,
                endTime: sortedBusy[0].startTime,
                status: .free
            ))
        }

        // Free slots between busy periods
        for i in 0..<(sortedBusy.count - 1) {
            let currentEnd = sortedBusy[i].endTime
            let nextStart = sortedBusy[i + 1].startTime

            if currentEnd < nextStart {
                freeSlots.append(TimeSlot(
                    startTime: currentEnd,
                    endTime: nextStart,
                    status: .free
                ))
            }
        }

        // Free slot after last busy period
        if let lastBusy = sortedBusy.last, lastBusy.endTime < endDate {
            freeSlots.append(TimeSlot(
                startTime: lastBusy.endTime,
                endTime: endDate,
                status: .free
            ))
        }

        return freeSlots
    }
}
