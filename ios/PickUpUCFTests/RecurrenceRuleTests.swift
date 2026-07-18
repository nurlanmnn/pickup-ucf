import XCTest
@testable import PickUpUCF

final class RecurrenceRuleTests: XCTestCase {
    func testWeeklyDefaultEncoding() throws {
        let rule = RecurrenceRule.weekly(count: 4)
        let json = try rule.jsonString
        XCTAssertEqual(json, #"{"frequency":"weekly","count":4}"#)
    }

    func testWeeklyCountClampedToRange() {
        XCTAssertEqual(RecurrenceRule.weekly(count: 1).count, 2)
        XCTAssertEqual(RecurrenceRule.weekly(count: 2).count, 2)
        XCTAssertEqual(RecurrenceRule.weekly(count: 4).count, 4)
        XCTAssertEqual(RecurrenceRule.weekly(count: 99).count, 4)
    }

    func testCodableRoundTrip() throws {
        let original = RecurrenceRule.weekly(count: 3)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RecurrenceRule.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}
