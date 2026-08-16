import XCTest
@testable import PickUpUCF

final class SessionDateFormatterTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_720_000_000)

    func testRelativeStartLabelUsesMinutesWithinTwoHours() {
        let starts = now.addingTimeInterval(15 * 60)

        XCTAssertEqual(
            SessionDateFormatter.relativeStartLabel(for: starts, relativeTo: now),
            "Starts in 15m"
        )
    }

    func testRelativeStartLabelRoundsPartialMinutesUp() {
        let starts = now.addingTimeInterval(90)

        XCTAssertEqual(
            SessionDateFormatter.relativeStartLabel(for: starts, relativeTo: now),
            "Starts in 2m"
        )
    }

    func testRelativeStartLabelShowsStartsNowUnderOneMinute() {
        let starts = now.addingTimeInterval(20)

        XCTAssertEqual(
            SessionDateFormatter.relativeStartLabel(for: starts, relativeTo: now),
            "Starts now"
        )
    }

    func testRelativeStartLabelIsNilWhenFartherThanTwoHours() {
        let starts = now.addingTimeInterval(121 * 60)

        XCTAssertNil(SessionDateFormatter.relativeStartLabel(for: starts, relativeTo: now))
    }

    func testRelativeStartLabelIsNilWhenInThePast() {
        let starts = now.addingTimeInterval(-60)

        XCTAssertNil(SessionDateFormatter.relativeStartLabel(for: starts, relativeTo: now))
    }

    func testCardTimeLinePrefersRelativeCountdownWhenSoon() {
        let starts = now.addingTimeInterval(12 * 60)
        let line = SessionDateFormatter.cardTimeLine(for: starts, relativeTo: now)

        XCTAssertTrue(line.hasPrefix("Starts in 12m · "))
    }

    func testCardTimeLineFallsBackToCardLabelWhenNotSoon() {
        let starts = now.addingTimeInterval(5 * 3600)
        let line = SessionDateFormatter.cardTimeLine(for: starts, relativeTo: now)

        XCTAssertEqual(line, SessionDateFormatter.cardLabel(for: starts, relativeTo: now))
        XCTAssertFalse(line.contains("Starts in"))
    }
}
