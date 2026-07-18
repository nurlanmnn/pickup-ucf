import XCTest
@testable import PickUpUCF

final class SportTypeTests: XCTestCase {
    func testBasketballDisplayName() {
        XCTAssertEqual(SportType.basketball.displayName, "Basketball")
    }

    func testPickleballDisplayName() {
        XCTAssertEqual(SportType.pickleball.displayName, "Pickleball")
    }

    func testAllCasesMatchDatabaseCount() {
        // 6 original + 9 new = 15
        XCTAssertEqual(SportType.allCases.count, 15)
    }

    func testCodableRoundTrip() throws {
        let data = try JSONEncoder().encode(SportType.flagFootball)
        let decoded = try JSONDecoder().decode(SportType.self, from: data)
        XCTAssertEqual(decoded, .flagFootball)
    }
}
