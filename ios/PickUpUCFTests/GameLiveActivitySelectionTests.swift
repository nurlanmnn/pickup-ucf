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

    func testSessionRemainsEligibleWhileGameIsInProgress() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let startsAt = now.addingTimeInterval(-20 * 60)
        let session = makeSession(startsAt: startsAt)

        XCTAssertTrue(GameLiveActivitySelection.isEligible(session: session, now: now))
    }

    func testIneligibleSessionAtGameEnd() {
        let startsAt = Date(timeIntervalSince1970: 1_700_000_000)
        let session = makeSession(startsAt: startsAt)

        XCTAssertFalse(
            GameLiveActivitySelection.isEligible(session: session, now: session.endsAt)
        )
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

    func testActivityEndDateUsesSessionEndTime() {
        let startsAt = Date(timeIntervalSince1970: 1_700_000_000)
        let session = makeSession(startsAt: startsAt)

        let endDate = GameLiveActivitySelection.activityEndDate(for: session)

        XCTAssertEqual(endDate, session.endsAt)
    }

    func testActivityContentBecomesStaleWhenSessionEnds() {
        let startsAt = Date(timeIntervalSince1970: 1_700_000_000)
        let session = makeSession(startsAt: startsAt)

        XCTAssertEqual(
            GameLiveActivitySelection.contentStaleDate(for: session),
            session.endsAt
        )
    }

    func testContentStateCarriesSessionStartAndEndTimes() {
        let startsAt = Date(timeIntervalSince1970: 1_700_000_000)
        let endsAt = startsAt.addingTimeInterval(5400)

        let state = GameLiveActivityAttributes.ContentState(
            startsAt: startsAt,
            endsAt: endsAt
        )

        XCTAssertEqual(state.startsAt, startsAt)
        XCTAssertEqual(state.endsAt, endsAt)
    }

    func testPresentationIsPreSessionBeforeStartTime() {
        let startsAt = Date(timeIntervalSince1970: 1_700_000_000)
        let endsAt = startsAt.addingTimeInterval(5400)

        XCTAssertEqual(
            GameLiveActivityPresentation.phase(
                startsAt: startsAt,
                endsAt: endsAt,
                now: startsAt.addingTimeInterval(-1)
            ),
            .preSession
        )
    }

    func testPresentationIsLiveAtExactStartTime() {
        let startsAt = Date(timeIntervalSince1970: 1_700_000_000)
        let endsAt = startsAt.addingTimeInterval(5400)

        XCTAssertEqual(
            GameLiveActivityPresentation.phase(
                startsAt: startsAt,
                endsAt: endsAt,
                now: startsAt
            ),
            .live
        )
    }

    func testPresentationIsEndedAtExactEndTime() {
        let startsAt = Date(timeIntervalSince1970: 1_700_000_000)
        let endsAt = startsAt.addingTimeInterval(5400)

        XCTAssertEqual(
            GameLiveActivityPresentation.phase(
                startsAt: startsAt,
                endsAt: endsAt,
                now: endsAt
            ),
            .ended
        )
    }

    func testCountdownIntervalRunsFromNowToFutureStartTime() {
        let startsAt = Date(timeIntervalSince1970: 1_700_000_000)
        let beforeStart = startsAt.addingTimeInterval(-90)

        XCTAssertEqual(
            GameLiveActivityPresentation.countdownInterval(
                startsAt: startsAt,
                now: beforeStart
            ),
            beforeStart...startsAt
        )
    }

    func testCountdownIntervalStopsAtZeroAfterStartTime() {
        let startsAt = Date(timeIntervalSince1970: 1_700_000_000)
        let afterStart = startsAt.addingTimeInterval(90)

        XCTAssertEqual(
            GameLiveActivityPresentation.countdownInterval(
                startsAt: startsAt,
                now: afterStart
            ),
            startsAt...startsAt
        )
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
