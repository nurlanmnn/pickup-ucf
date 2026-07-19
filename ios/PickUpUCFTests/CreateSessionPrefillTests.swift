import XCTest
@testable import PickUpUCF

final class CreateSessionPrefillTests: XCTestCase {
    func testPrefillMapsFieldsFromCompletedSession() {
        let venueId = UUID()
        let hostId = UUID()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let startsAt = now.addingTimeInterval(-86400)
        let endsAt = startsAt.addingTimeInterval(5400)

        let session = PickupSession(
            id: UUID(),
            hostId: hostId,
            sport: .volleyball,
            customSportName: nil,
            venueId: venueId,
            customLocation: nil,
            customLat: nil,
            customLng: nil,
            startsAt: startsAt,
            endsAt: endsAt,
            capacity: 12,
            playerCount: 8,
            skillLevel: .beginner,
            notes: "Bring water",
            status: .completed,
            venue: Venue(id: venueId, name: "Memory Mall", lat: 28.6, lng: -81.2, campusZone: nil, isOfficial: true),
            host: nil,
            weatherSnapshot: nil
        )

        let prefill = CreateSessionPrefill(from: session, now: now)

        XCTAssertEqual(prefill.sport, .volleyball)
        XCTAssertNil(prefill.customSportName)
        XCTAssertEqual(prefill.venueId, venueId)
        XCTAssertNil(prefill.customLocationSelection)
        XCTAssertEqual(prefill.skillLevel, .beginner)
        XCTAssertEqual(prefill.capacity, 12)
        XCTAssertEqual(prefill.durationMinutes, 90)
        XCTAssertEqual(prefill.notes, "Bring water")
    }

    func testPrefillStartsAtIsSevenDaysLaterClampedToCreateWindow() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let sourceStartsAt = now.addingTimeInterval(-86400 * 6)

        let withinWindow = CreateSessionPrefill.clampedStartsAt(
            from: sourceStartsAt,
            now: now,
            calendar: calendar
        )
        let expected = calendar.date(byAdding: .day, value: 7, to: sourceStartsAt)!
        XCTAssertEqual(withinWindow, expected)

        let farFutureSource = now.addingTimeInterval(86400 * 30)
        let clamped = CreateSessionPrefill.clampedStartsAt(
            from: farFutureSource,
            now: now,
            calendar: calendar
        )
        let maxAllowed = calendar.date(byAdding: .hour, value: 48, to: now)!
        XCTAssertEqual(clamped, maxAllowed)
    }
}
