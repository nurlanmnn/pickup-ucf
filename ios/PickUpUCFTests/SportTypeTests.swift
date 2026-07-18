import XCTest
@testable import PickUpUCF

final class SportTypeTests: XCTestCase {
    func testBasketballDisplayName() {
        XCTAssertEqual(SportType.basketball.displayName, "Basketball")
    }
}
