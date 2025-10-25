import Foundation

/// Core domain entity representing calendar availability (free/busy times)
struct CalendarAvailability: Codable, Equatable {
    let userId: String
    let timeSlots: [TimeSlot]
    let queriedFrom: Date
    let queriedTo: Date
    let timeZone: TimeZone

    /// Computed property to get only busy slots
    var busySlots: [TimeSlot] {
        timeSlots.filter { $0.status == .busy }
    }

    /// Computed property to get only free slots
    var freeSlots: [TimeSlot] {
        timeSlots.filter { $0.status == .free }
    }

    /// Find common free slots across multiple users' availability
    static func findCommonFreeSlots(
        availabilities: [CalendarAvailability],
        duration: TimeInterval,
        workingHoursStart: Int = 9,  // 9 AM
        workingHoursEnd: Int = 17    // 5 PM
    ) -> [TimeSlot] {
        guard let first = availabilities.first else { return [] }

        var commonFreeSlots: [TimeSlot] = []
        let startDate = first.queriedFrom
        let endDate = first.queriedTo

        // Iterate through each day in the range
        var currentDate = Calendar.current.startOfDay(for: startDate)

        while currentDate < endDate {
            // Skip weekends
            let weekday = Calendar.current.component(.weekday, from: currentDate)
            if weekday == 1 || weekday == 7 {  // Sunday = 1, Saturday = 7
                currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate)!
                continue
            }

            // Check working hours
            let dayStart = Calendar.current.date(
                bySettingHour: workingHoursStart,
                minute: 0,
                second: 0,
                of: currentDate
            )!
            let dayEnd = Calendar.current.date(
                bySettingHour: workingHoursEnd,
                minute: 0,
                second: 0,
                of: currentDate
            )!

            // Find slots where ALL users are free
            var currentSlotStart = dayStart

            while currentSlotStart < dayEnd {
                let slotEnd = currentSlotStart.addingTimeInterval(duration)

                if slotEnd > dayEnd {
                    break
                }

                // Check if ALL users are free during this slot
                let allFree = availabilities.allSatisfy { availability in
                    !availability.busySlots.contains { busySlot in
                        busySlot.overlaps(with: currentSlotStart, end: slotEnd)
                    }
                }

                if allFree {
                    commonFreeSlots.append(TimeSlot(
                        startTime: currentSlotStart,
                        endTime: slotEnd,
                        status: .free
                    ))
                }

                // Move to next 30-minute slot
                currentSlotStart = currentSlotStart.addingTimeInterval(30 * 60)
            }

            currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate)!
        }

        return commonFreeSlots
    }

    init(
        userId: String,
        timeSlots: [TimeSlot],
        queriedFrom: Date,
        queriedTo: Date,
        timeZone: TimeZone = .current
    ) {
        self.userId = userId
        self.timeSlots = timeSlots
        self.queriedFrom = queriedFrom
        self.queriedTo = queriedTo
        self.timeZone = timeZone
    }
}

/// Represents a time slot with busy/free status
struct TimeSlot: Codable, Equatable {
    let startTime: Date
    let endTime: Date
    let status: TimeSlotStatus

    /// Check if this time slot overlaps with a given time range
    func overlaps(with otherStart: Date, end otherEnd: Date) -> Bool {
        return startTime < otherEnd && endTime > otherStart
    }

    /// Duration of the time slot in minutes
    var durationMinutes: Int {
        Int(endTime.timeIntervalSince(startTime) / 60)
    }

    init(startTime: Date, endTime: Date, status: TimeSlotStatus) {
        self.startTime = startTime
        self.endTime = endTime
        self.status = status
    }
}

/// Status of a time slot
enum TimeSlotStatus: String, Codable {
    case free
    case busy
    case tentative  // Scheduled but not confirmed
}
