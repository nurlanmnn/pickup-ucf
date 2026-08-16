import XCTest
@testable import PickUpUCF

final class CalendarEventFormattingTests: XCTestCase {
    func testTitleIncludesSportAndLocation() {
        let session = makeSession(
            sport: .basketball,
            locationName: "Memory Mall",
            startsAt: Date(timeIntervalSince1970: 0),
            endsAt: Date(timeIntervalSince1970: 3600)
        )

        XCTAssertEqual(
            CalendarEventFormatting.title(for: session),
            "Basketball · Memory Mall"
        )
    }

    func testNotesIncludeShareLinkAndHost() {
        let sessionId = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let session = makeSession(
            sport: .soccer,
            locationName: "Field 7",
            startsAt: Date(timeIntervalSince1970: 0),
            endsAt: Date(timeIntervalSince1970: 3600),
            sessionId: sessionId,
            hostHandle: "@knight",
            notes: "Cleats optional"
        )

        let notes = CalendarEventFormatting.notes(for: session)

        XCTAssertTrue(notes.contains("Host: @knight"))
        XCTAssertTrue(notes.contains("pickupucf://session/\(sessionId.uuidString)"))
        XCTAssertTrue(notes.contains("Cleats optional"))
    }

    private func makeSession(
        sport: SportType,
        locationName: String,
        startsAt: Date,
        endsAt: Date,
        sessionId: UUID = UUID(),
        hostHandle: String? = nil,
        notes: String? = nil
    ) -> PickupSession {
        PickupSession(
            id: sessionId,
            hostId: UUID(),
            sport: sport,
            customSportName: nil,
            venueId: nil,
            customLocation: locationName,
            customLat: 28.6,
            customLng: -81.2,
            startsAt: startsAt,
            endsAt: endsAt,
            capacity: 10,
            playerCount: 4,
            skillLevel: .any,
            notes: notes,
            status: .open,
            venue: nil,
            host: hostHandle.map {
                ProfileSummary(id: UUID(), displayName: "Host", username: String($0.dropFirst()))
            },
            weatherSnapshot: nil
        )
    }
}
