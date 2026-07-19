import XCTest
@testable import PickUpUCF

final class CalendarExportServiceTests: XCTestCase {
    func testStorageRoundTrip() {
        let defaults = UserDefaults(suiteName: #function)!
        defer { defaults.removePersistentDomain(forName: #function) }

        let storage = UserDefaultsCalendarExportEventStorage(defaults: defaults)
        let sessionId = UUID()

        XCTAssertNil(storage.eventIdentifier(for: sessionId))

        storage.setEventIdentifier("event-123", for: sessionId)
        XCTAssertEqual(storage.eventIdentifier(for: sessionId), "event-123")

        storage.setEventIdentifier(nil, for: sessionId)
        XCTAssertNil(storage.eventIdentifier(for: sessionId))
    }
}
