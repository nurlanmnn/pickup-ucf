import XCTest
@testable import PickUpUCF

final class CreateSessionDefaultsStorageTests: XCTestCase {
    func testSaveLoadRoundTrip() {
        let defaults = UserDefaults(suiteName: #function)!
        defer { defaults.removePersistentDomain(forName: #function) }

        let venueId = UUID()
        CreateSessionDefaultsStorage.save(sport: .volleyball, venueId: venueId, to: defaults)

        let loaded = CreateSessionDefaultsStorage.load(from: defaults)
        XCTAssertEqual(loaded.sport, .volleyball)
        XCTAssertEqual(loaded.venueId, venueId)
    }

    func testSaveWithoutVenueKeepsPreviousVenue() {
        let defaults = UserDefaults(suiteName: #function)!
        defer { defaults.removePersistentDomain(forName: #function) }

        let venueId = UUID()
        CreateSessionDefaultsStorage.save(sport: .basketball, venueId: venueId, to: defaults)
        CreateSessionDefaultsStorage.save(sport: .soccer, venueId: nil, to: defaults)

        let loaded = CreateSessionDefaultsStorage.load(from: defaults)
        XCTAssertEqual(loaded.sport, .soccer)
        XCTAssertEqual(loaded.venueId, venueId)
    }

    func testLoadReturnsEmptyDefaultsWhenUnset() {
        let defaults = UserDefaults(suiteName: #function)!
        defer { defaults.removePersistentDomain(forName: #function) }

        let loaded = CreateSessionDefaultsStorage.load(from: defaults)
        XCTAssertNil(loaded.sport)
        XCTAssertNil(loaded.venueId)
    }
}
