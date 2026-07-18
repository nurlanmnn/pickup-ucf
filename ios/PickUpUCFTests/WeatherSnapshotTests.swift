import XCTest
@testable import PickUpUCF

final class WeatherSnapshotTests: XCTestCase {
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    func testDecodeSampleJsonb() throws {
        let json = """
        {
          "summary": "Partly cloudy",
          "temp_f": 82,
          "precip_pct": 30,
          "fetched_at": "2026-07-18T18:00:00Z"
        }
        """.data(using: .utf8)!

        let snapshot = try decoder.decode(WeatherSnapshot.self, from: json)

        XCTAssertEqual(snapshot.summary, "Partly cloudy")
        XCTAssertEqual(snapshot.tempF, 82)
        XCTAssertEqual(snapshot.precipPct, 30)
        XCTAssertEqual(snapshot.displayLine, "82°F · 30% rain")
    }

    func testDisplayLineFormatting() {
        let snapshot = WeatherSnapshot(
            summary: "Clear",
            tempF: 75,
            precipPct: 10,
            fetchedAt: Date(timeIntervalSince1970: 0)
        )
        XCTAssertEqual(snapshot.displayLine, "75°F · 10% rain")
    }

    func testOutdoorCustomLocation() {
        let session = makeSession(venue: nil, customLat: 28.6, customLng: -81.2)
        XCTAssertTrue(session.isOutdoorForWeather)
    }

    func testOutdoorOfficialVenue() {
        let venue = Venue(
            id: UUID(),
            name: "IM Fields",
            lat: 28.595,
            lng: -81.192,
            campusZone: "Main Campus",
            isOfficial: true
        )
        let session = makeSession(venue: venue, customLat: nil, customLng: nil)
        XCTAssertTrue(session.isOutdoorForWeather)
    }

    func testIndoorRWCVenueExcluded() {
        let venue = Venue(
            id: UUID(),
            name: "Basketball Courts (RWC)",
            lat: 28.607,
            lng: -81.197,
            campusZone: "Main Campus",
            isOfficial: true
        )
        let session = makeSession(venue: venue, customLat: nil, customLng: nil)
        XCTAssertFalse(session.isOutdoorForWeather)
    }

    private func makeSession(venue: Venue?, customLat: Double?, customLng: Double?) -> PickupSession {
        PickupSession(
            id: UUID(),
            hostId: UUID(),
            sport: .basketball,
            customSportName: nil,
            venueId: venue?.id,
            customLocation: customLat == nil ? nil : "Custom pin",
            customLat: customLat,
            customLng: customLng,
            startsAt: Date(timeIntervalSince1970: 0),
            endsAt: Date(timeIntervalSince1970: 3600),
            capacity: 10,
            playerCount: 1,
            skillLevel: .intermediate,
            notes: nil,
            status: .open,
            venue: venue,
            host: nil,
            weatherSnapshot: nil
        )
    }
}
