import XCTest
@testable import PickUpUCF

final class GameLiveActivitySelectionTests: XCTestCase {
    func testEligibleSessionWithinTwentyFourHours() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let session = makeSession(startsAt: now.addingTimeInterval(3600))

        XCTAssertTrue(GameLiveActivitySelection.isEligible(session: session, now: now))
    }

    func testIneligibleSessionBeyondTwentyFourHours() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let session = makeSession(startsAt: now.addingTimeInterval(25 * 3600))

        XCTAssertFalse(GameLiveActivitySelection.isEligible(session: session, now: now))
    }

    func testIneligibleSessionAfterGracePeriodEnds() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let startsAt = now.addingTimeInterval(-20 * 60)
        let session = makeSession(startsAt: startsAt)

        XCTAssertFalse(GameLiveActivitySelection.isEligible(session: session, now: now))
    }

    func testNextSessionPicksEarliestEligibleGame() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let later = makeSession(startsAt: now.addingTimeInterval(7200))
        let sooner = makeSession(startsAt: now.addingTimeInterval(1800))
        let tooFar = makeSession(startsAt: now.addingTimeInterval(30 * 3600))

        let next = GameLiveActivitySelection.nextSession(
            from: [later, tooFar, sooner],
            now: now
        )

        XCTAssertEqual(next?.id, sooner.id)
    }

    func testActivityEndDateIsFifteenMinutesAfterStart() {
        let startsAt = Date(timeIntervalSince1970: 1_700_000_000)
        let session = makeSession(startsAt: startsAt)

        let endDate = GameLiveActivitySelection.activityEndDate(for: session)

        XCTAssertEqual(endDate, startsAt.addingTimeInterval(15 * 60))
    }

    private func makeSession(startsAt: Date) -> PickupSession {
        PickupSession(
            id: UUID(),
            hostId: UUID(),
            sport: .basketball,
            customSportName: nil,
            venueId: UUID(),
            customLocation: nil,
            customLat: nil,
            customLng: nil,
            startsAt: startsAt,
            endsAt: startsAt.addingTimeInterval(5400),
            capacity: 10,
            playerCount: 4,
            skillLevel: .intermediate,
            notes: nil,
            status: .open,
            venue: Venue(
                id: UUID(),
                name: "IM Fields",
                lat: 28.6,
                lng: -81.2,
                campusZone: nil,
                isOfficial: true
            ),
            host: nil,
            weatherSnapshot: nil
        )
    }
}
