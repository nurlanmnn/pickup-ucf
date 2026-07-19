import XCTest
@testable import PickUpUCF

final class MySportsFilterTests: XCTestCase {
    func testMySportsFilterKeepsMatchingSessions() {
        let sessions = [
            makeSession(sport: .basketball),
            makeSession(sport: .soccer),
            makeSession(sport: .tennis),
        ]

        let filtered = DiscoverViewModel.applySportFilter(
            sessions,
            mode: .mySports,
            preferredSports: [.basketball, .soccer]
        )

        XCTAssertEqual(filtered.count, 2)
        XCTAssertTrue(filtered.allSatisfy { [.basketball, .soccer].contains($0.sport) })
    }

    func testSingleSportModeDoesNotApplyMySportsFilter() {
        let sessions = [
            makeSession(sport: .basketball),
            makeSession(sport: .tennis),
        ]

        let filtered = DiscoverViewModel.applySportFilter(
            sessions,
            mode: .single(.tennis),
            preferredSports: [.basketball]
        )

        XCTAssertEqual(filtered, sessions)
    }

    func testDiscoverSportFilterStorageRoundTrip() {
        DiscoverSportFilterStorage.save(.mySports)
        XCTAssertEqual(DiscoverSportFilterStorage.load(), .mySports)

        DiscoverSportFilterStorage.save(.single(nil))
        XCTAssertEqual(DiscoverSportFilterStorage.load(), .single(nil))

        DiscoverSportFilterStorage.save(.single(.pickleball))
        XCTAssertEqual(DiscoverSportFilterStorage.load(), .single(.pickleball))
    }

    private func makeSession(sport: SportType) -> PickupSession {
        PickupSession(
            id: UUID(),
            hostId: UUID(),
            sport: sport,
            customSportName: nil,
            venueId: nil,
            customLocation: "Campus",
            customLat: 28.6,
            customLng: -81.2,
            startsAt: Date(timeIntervalSince1970: 0),
            endsAt: Date(timeIntervalSince1970: 3600),
            capacity: 10,
            playerCount: 1,
            skillLevel: .any,
            notes: nil,
            status: .open,
            venue: nil,
            host: nil,
            weatherSnapshot: nil
        )
    }
}
