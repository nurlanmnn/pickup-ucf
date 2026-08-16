import XCTest
@testable import PickUpUCF

final class SessionMapAnnotationTests: XCTestCase {
    func testVenueCoordinatesTakePrecedenceOverCustomCoordinates() {
        let session = makeSession(
            venue: Venue(
                id: UUID(),
                name: "UCF RWC",
                lat: 28.5999,
                lng: -81.2018,
                campusZone: "Main Campus",
                isOfficial: true
            ),
            customLat: 1,
            customLng: 2
        )

        let annotation = SessionMapAnnotation(session: session)

        XCTAssertEqual(annotation?.id, session.id)
        XCTAssertEqual(annotation?.coordinate.latitude, 28.5999)
        XCTAssertEqual(annotation?.coordinate.longitude, -81.2018)
    }

    func testCustomCoordinatesAreUsedWithoutEmbeddedVenue() {
        let session = makeSession(customLat: 28.6024, customLng: -81.2001)

        let annotation = SessionMapAnnotation(session: session)

        XCTAssertEqual(annotation?.coordinate.latitude, 28.6024)
        XCTAssertEqual(annotation?.coordinate.longitude, -81.2001)
    }

    func testMissingCustomLatitudeReturnsNil() {
        let session = makeSession(customLat: nil, customLng: -81.2001)

        XCTAssertNil(SessionMapAnnotation(session: session))
    }

    func testMissingCustomLongitudeReturnsNil() {
        let session = makeSession(customLat: 28.6024, customLng: nil)

        XCTAssertNil(SessionMapAnnotation(session: session))
    }

    private func makeSession(
        venue: Venue? = nil,
        customLat: Double?,
        customLng: Double?
    ) -> PickupSession {
        PickupSession(
            id: UUID(),
            hostId: UUID(),
            sport: .basketball,
            customSportName: nil,
            venueId: venue?.id,
            customLocation: venue == nil ? "Custom court" : nil,
            customLat: customLat,
            customLng: customLng,
            startsAt: Date(timeIntervalSince1970: 1_800_000_000),
            endsAt: Date(timeIntervalSince1970: 1_800_003_600),
            capacity: 10,
            playerCount: 2,
            skillLevel: .any,
            notes: nil,
            status: .open,
            venue: venue,
            host: nil,
            weatherSnapshot: nil
        )
    }
}
