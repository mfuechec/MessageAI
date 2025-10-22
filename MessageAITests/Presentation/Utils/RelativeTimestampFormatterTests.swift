import XCTest
@testable import MessageAI

final class RelativeTimestampFormatterTests: XCTestCase {

    // MARK: - Test "Now" Cases

    func testFormat_Now_ForRecentTimestamp() {
        // Given: Timestamp from 30 seconds ago
        let date = Date().addingTimeInterval(-30)

        // When: Format timestamp
        let result = RelativeTimestampFormatter.format(date)

        // Then: Should show "Now"
        XCTAssertEqual(result, "Now")
    }

    func testFormat_Now_ForFutureTimestamp() {
        // Given: Future timestamp (clock skew)
        let date = Date().addingTimeInterval(10)

        // When: Format timestamp
        let result = RelativeTimestampFormatter.format(date)

        // Then: Should show "Now"
        XCTAssertEqual(result, "Now")
    }

    // MARK: - Test Minutes Ago

    func testFormat_MinutesAgo_For2Minutes() {
        // Given: Timestamp from 2 minutes ago
        let date = Date().addingTimeInterval(-120)  // 2 minutes

        // When: Format timestamp
        let result = RelativeTimestampFormatter.format(date)

        // Then: Should show "2m ago"
        XCTAssertEqual(result, "2m ago")
    }

    func testFormat_MinutesAgo_For30Minutes() {
        // Given: Timestamp from 30 minutes ago
        let date = Date().addingTimeInterval(-1800)  // 30 minutes

        // When: Format timestamp
        let result = RelativeTimestampFormatter.format(date)

        // Then: Should show "30m ago"
        XCTAssertEqual(result, "30m ago")
    }

    // MARK: - Test Hours Ago

    func testFormat_HoursAgo_For2Hours() {
        // Given: Timestamp from 2 hours ago
        let date = Date().addingTimeInterval(-7200)  // 2 hours

        // When: Format timestamp
        let result = RelativeTimestampFormatter.format(date)

        // Then: Should show "2h ago"
        XCTAssertEqual(result, "2h ago")
    }

    func testFormat_HoursAgo_For12Hours() {
        // Given: Timestamp from 12 hours ago
        let date = Date().addingTimeInterval(-43200)  // 12 hours

        // When: Format timestamp
        let result = RelativeTimestampFormatter.format(date)

        // Then: Should show "12h ago"
        XCTAssertEqual(result, "12h ago")
    }

    // MARK: - Test Yesterday

    func testFormat_Yesterday_For25HoursAgo() {
        // Given: Timestamp from 25 hours ago
        let date = Date().addingTimeInterval(-90000)  // 25 hours

        // When: Format timestamp
        let result = RelativeTimestampFormatter.format(date)

        // Then: Should show "Yesterday"
        XCTAssertEqual(result, "Yesterday")
    }

    func testFormat_Yesterday_For40HoursAgo() {
        // Given: Timestamp from 40 hours ago
        let date = Date().addingTimeInterval(-144000)  // 40 hours

        // When: Format timestamp
        let result = RelativeTimestampFormatter.format(date)

        // Then: Should show "Yesterday"
        XCTAssertEqual(result, "Yesterday")
    }

    // MARK: - Test Absolute Dates

    func testFormat_AbsoluteDate_For3DaysAgo() {
        // Given: Timestamp from 3 days ago
        let date = Date().addingTimeInterval(-259200)  // 3 days

        // When: Format timestamp
        let result = RelativeTimestampFormatter.format(date)

        // Then: Should show "MMM d" format (e.g., "Oct 19")
        // Can't assert exact string because it depends on current date
        // But can verify it's not "Now", "Xm ago", "Xh ago", or "Yesterday"
        XCTAssertFalse(result == "Now")
        XCTAssertFalse(result.hasSuffix("m ago"))
        XCTAssertFalse(result.hasSuffix("h ago"))
        XCTAssertFalse(result == "Yesterday")
    }

    func testFormat_AbsoluteDate_For30DaysAgo() {
        // Given: Timestamp from 30 days ago
        let date = Date().addingTimeInterval(-2592000)  // 30 days

        // When: Format timestamp
        let result = RelativeTimestampFormatter.format(date)

        // Then: Should show "MMM d" format
        XCTAssertFalse(result == "Now")
        XCTAssertFalse(result.hasSuffix("m ago"))
        XCTAssertFalse(result.hasSuffix("h ago"))
        XCTAssertFalse(result == "Yesterday")

        // Verify format is roughly "MMM d" (3 letters + space + 1-2 digits)
        let components = result.split(separator: " ")
        XCTAssertEqual(components.count, 2, "Should be 'MMM d' format")
        XCTAssertEqual(components[0].count, 3, "Month should be 3 letters")
    }

    // MARK: - Edge Cases

    func testFormat_ExactlyOneMinute() {
        // Given: Exactly 60 seconds ago
        let date = Date().addingTimeInterval(-60)

        // When: Format timestamp
        let result = RelativeTimestampFormatter.format(date)

        // Then: Should show "1m ago"
        XCTAssertEqual(result, "1m ago")
    }

    func testFormat_ExactlyOneHour() {
        // Given: Exactly 3600 seconds ago
        let date = Date().addingTimeInterval(-3600)

        // When: Format timestamp
        let result = RelativeTimestampFormatter.format(date)

        // Then: Should show "1h ago"
        XCTAssertEqual(result, "1h ago")
    }

    func testFormat_Exactly24Hours() {
        // Given: Exactly 24 hours ago
        let date = Date().addingTimeInterval(-86400)

        // When: Format timestamp
        let result = RelativeTimestampFormatter.format(date)

        // Then: Should show "Yesterday"
        XCTAssertEqual(result, "Yesterday")
    }
}
