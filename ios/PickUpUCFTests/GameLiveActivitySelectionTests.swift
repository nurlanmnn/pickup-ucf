import ActivityKit
import XCTest
@testable import PickUpUCF

final class GameLiveActivitySelectionTests: XCTestCase {
    @MainActor
    func testUISmokeCoordinatorSkipsEverySystemEffect() async {
        for mode in [AppTestMode.uiSmoke, .uiSmokeAuthenticated] {
            let forbidden = expectation(description: "No system effect in \(mode)")
            forbidden.isInverted = true
            forbidden.assertForOverFulfill = false
            let session = makeSession(startsAt: Date().addingTimeInterval(60))
            await GameLiveActivityCoordinator.refreshForCurrentUser(userId: session.hostId!, testMode: mode) { _ in forbidden.fulfill() }
            GameLiveActivityCoordinator.start(for: session, testMode: mode) { _, _ in forbidden.fulfill() }
            GameLiveActivityCoordinator.refresh(upcomingSessions: [session], testMode: mode) { _, _ in forbidden.fulfill() }
            GameLiveActivityCoordinator.end(forSessionId: session.id, testMode: mode) { _ in forbidden.fulfill() }
            let delay = await GameLiveActivityCoordinator.nextCleanupDelay(testMode: mode) { forbidden.fulfill(); return Date() }
            XCTAssertEqual(delay, 30)
            await GameLiveActivityCoordinator.endExpired(testMode: mode) { _ in forbidden.fulfill() }
            await GameLiveActivityCoordinator.endAllForAccountTransition(testMode: mode) { forbidden.fulfill() }
            await fulfillment(of: [forbidden], timeout: 0.2)
        }
    }

    @MainActor
    func testNormalAndUnitCoordinatorPreserveEffectArgumentsAndCleanupDelay() async {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let session = makeSession(startsAt: now.addingTimeInterval(60))
        for mode in [AppTestMode.normal, .unit] {
            let effects = (0..<7).map { expectation(description: "System effect \($0) in \(mode)") }
            await GameLiveActivityCoordinator.refreshForCurrentUser(userId: session.hostId!, testMode: mode) {
                XCTAssertEqual($0, session.hostId); effects[0].fulfill()
            }
            GameLiveActivityCoordinator.start(for: session, now: now, testMode: mode) {
                XCTAssertEqual($0, session); XCTAssertEqual($1, now); effects[1].fulfill()
            }
            GameLiveActivityCoordinator.refresh(upcomingSessions: [session], now: now, testMode: mode) {
                XCTAssertEqual($0, [session]); XCTAssertEqual($1, now); effects[2].fulfill()
            }
            GameLiveActivityCoordinator.end(forSessionId: session.id, testMode: mode) {
                XCTAssertEqual($0, session.id); effects[3].fulfill()
            }
            let delay = await GameLiveActivityCoordinator.nextCleanupDelay(now: now, testMode: mode) {
                effects[4].fulfill(); return now.addingTimeInterval(17)
            }
            XCTAssertEqual(delay, 17)
            await GameLiveActivityCoordinator.endExpired(now: now, testMode: mode) {
                XCTAssertEqual($0, now); effects[5].fulfill()
            }
            await GameLiveActivityCoordinator.endAllForAccountTransition(testMode: mode) { effects[6].fulfill() }
            await fulfillment(of: effects, timeout: 2)
        }
    }

    func testEligibleSessionExactlyOneHourBeforeStart() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let session = makeSession(startsAt: now.addingTimeInterval(3600))

        XCTAssertTrue(GameLiveActivitySelection.isEligible(session: session, now: now))
    }

    func testIneligibleSessionNineteenHoursBeforeStart() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let session = makeSession(startsAt: now.addingTimeInterval(19 * 3600))

        XCTAssertFalse(GameLiveActivitySelection.isEligible(session: session, now: now))
    }

    func testIneligibleSessionJustOutsideOneHourWindow() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let session = makeSession(startsAt: now.addingTimeInterval(3601))
        XCTAssertFalse(GameLiveActivitySelection.isEligible(session: session, now: now))
    }

    func testCancelledAndCompletedSessionsAreIneligible() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        var session = makeSession(startsAt: now.addingTimeInterval(1800))
        for status in [SessionStatus.cancelled, .completed] {
            session.status = status
            XCTAssertFalse(GameLiveActivitySelection.isEligible(session: session, now: now))
        }
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

    func testContentStateJSONUsesAppleReferenceSeconds() throws {
        let state = GameLiveActivityAttributes.ContentState(
            startsAt: Date(timeIntervalSince1970: 1_700_000_000.25),
            endsAt: Date(timeIntervalSince1970: 1_700_005_400.25)
        )
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Double])
        XCTAssertEqual(json["startsAt"], 1_700_000_000.25 - 978_307_200)
        XCTAssertEqual(json["endsAt"], 1_700_005_400.25 - 978_307_200)
    }

    @MainActor
    func testExpiredActivityIsImmediatelyDismissedAtRuntime() async throws {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            throw XCTSkip("Live Activities are unavailable on this test destination")
        }
        let now = Date()
        let session = makeSession(startsAt: now.addingTimeInterval(-60))
        let activity: Activity<GameLiveActivityAttributes>
        do {
            activity = try Activity.request(
                attributes: GameLiveActivityAttributes(
                    sportName: "Tennis", locationName: "RWC Courts",
                    sessionId: session.id.uuidString, sportSystemImage: "tennisball.fill"
                ),
                content: ActivityContent(
                    state: .init(startsAt: session.startsAt, endsAt: session.endsAt),
                    staleDate: session.endsAt
                ),
                pushType: nil
            )
        } catch {
            throw XCTSkip("ActivityKit request unavailable: \(error)")
        }
        XCTAssertEqual(activity.activityState, .active)
        let dismissal = expectation(description: "ActivityKit acknowledges immediate dismissal")
        let stateUpdates = Task {
            for await state in activity.activityStateUpdates {
                if state == .ended || state == .dismissed {
                    dismissal.fulfill()
                    return
                }
            }
        }
        defer { stateUpdates.cancel() }
        await GameLiveActivityManager.endExpired(now: session.endsAt)
        await fulfillment(of: [dismissal], timeout: 2)
        XCTAssertTrue(activity.activityState == .ended || activity.activityState == .dismissed)
        XCTAssertFalse(Activity<GameLiveActivityAttributes>.activities.contains { $0.id == activity.id })
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
