import XCTest
@testable import PickUpUCF

final class BlockedSessionFilterTests: XCTestCase {
    func testFiltersSessionsFromBlockedHosts() {
        let blockedHostId = UUID()
        let otherHostA = UUID()
        let otherHostB = UUID()

        let sessions = [
            makeSession(hostId: otherHostA),
            makeSession(hostId: blockedHostId),
            makeSession(hostId: otherHostB),
        ]

        let filtered = SessionRepository.filterBlockedHosts(
            sessions,
            blockedHostIds: [blockedHostId]
        )

        XCTAssertEqual(filtered.count, 2)
        XCTAssertTrue(filtered.allSatisfy { $0.hostId != blockedHostId })
        XCTAssertEqual(Set(filtered.map(\.hostId)), Set([otherHostA, otherHostB]))
    }

    func testEmptyBlockListReturnsAllSessions() {
        let sessions = [makeSession(hostId: UUID()), makeSession(hostId: UUID())]
        let filtered = SessionRepository.filterBlockedHosts(sessions, blockedHostIds: [])
        XCTAssertEqual(filtered, sessions)
    }

    private func makeSession(hostId: UUID) -> PickupSession {
        PickupSession(
            id: UUID(),
            hostId: hostId,
            sport: .basketball,
            customSportName: nil,
            venueId: nil,
            customLocation: "Campus",
            customLat: 28.6,
            customLng: -81.2,
            startsAt: Date(timeIntervalSince1970: 0),
            endsAt: Date(timeIntervalSince1970: 3600),
            capacity: 10,
            playerCount: 1,
            skillLevel: .intermediate,
            notes: nil,
            status: .open,
            venue: nil,
            host: nil,
            weatherSnapshot: nil
        )
    }
}
