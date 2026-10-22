import XCTest
@testable import PickUpUCF

final class UserContentPolicyTests: XCTestCase {
    func testNormalizeTrimsAndCollapsesWhitespace() throws {
        let value = try UserContentPolicy.validate("  Morning   pickup\n game  ", field: .sessionNotes)
        XCTAssertEqual(value, "Morning pickup game")
    }

    func testOptionalBlankValueNormalizesToNil() throws {
        XCTAssertNil(try UserContentPolicy.validateOptional(" \n ", field: .sessionNotes))
    }

    func testRejectsControlCharacters() {
        XCTAssertThrowsError(try UserContentPolicy.validate("hello\u{0000}world", field: .chatMessage))
    }

    func testRejectsDirectThreatsButAllowsSportsIdioms() throws {
        XCTAssertThrowsError(try UserContentPolicy.validate("I will k1ll you", field: .chatMessage))
        XCTAssertEqual(
            try UserContentPolicy.validate("We are going to kill it on the court", field: .chatMessage),
            "We are going to kill it on the court"
        )
    }

    func testRejectsSexualSolicitationAndContactSpam() {
        XCTAssertThrowsError(try UserContentPolicy.validate("send nudes", field: .displayName))
        XCTAssertThrowsError(try UserContentPolicy.validate("text me at 407-555-1212", field: .sessionNotes))
        XCTAssertThrowsError(try UserContentPolicy.validate("join https://spam.example", field: .chatMessage))
    }

    func testEnforcesFieldSpecificLengths() throws {
        XCTAssertThrowsError(try UserContentPolicy.validate(String(repeating: "a", count: 81), field: .displayName))
        XCTAssertThrowsError(try UserContentPolicy.validate(String(repeating: "a", count: 1001), field: .sessionNotes))
        XCTAssertThrowsError(try UserContentPolicy.validate(String(repeating: "a", count: 501), field: .chatMessage))
        XCTAssertEqual(try UserContentPolicy.validate("Flag football", field: .customSport), "Flag football")
    }

    func testErrorMessagesDoNotEchoRejectedContent() {
        let rejected = "I will k1ll you"

        XCTAssertThrowsError(try UserContentPolicy.validate(rejected, field: .chatMessage)) { error in
            XCTAssertFalse(error.localizedDescription.localizedCaseInsensitiveContains(rejected))
        }
    }
    func testNFCAndUnicodeWhitespaceMatchServerContract() throws {
        let normalized = try UserContentPolicy.validate(" \u{00A0}Cafe\u{0301}\u{2007}\nteam\u{3000}", field: .displayName)
        XCTAssertEqual(normalized, "Café team")
        XCTAssertEqual(normalized.unicodeScalars.count, 9)
    }

    func testEmojiSequencesCountCodePointsAndRemainAllowed() throws {
        let family = "👩‍👩‍👧‍👦" // Seven code points, one grapheme.
        XCTAssertEqual(try UserContentPolicy.validate(family, field: .chatMessage), family)
        XCTAssertThrowsError(try UserContentPolicy.validate(String(repeating: family, count: 72), field: .chatMessage))
    }

    func testOptionalContentCannotNormalizeAwayForbiddenControls() {
        for raw in ["hello\u{000B}world", "\u{0085}", "hello\u{000C}"] {
            XCTAssertThrowsError(try UserContentPolicy.validateOptional(raw, field: .sessionNotes))
        }
    }

    func testAllFieldBoundariesUseNormalizedCodePoints() throws {
        for field in [UserContentField.displayName, .sessionNotes, .customSport, .customLocation, .chatMessage, .reportContext] {
            XCTAssertThrowsError(try UserContentPolicy.validate(" \n\t", field: field))
            XCTAssertEqual(try UserContentPolicy.validate("é", field: field), "é")
            XCTAssertEqual(try UserContentPolicy.validate(String(repeating: "e\u{0301}", count: field.maximumLength), field: field), String(repeating: "é", count: field.maximumLength))
            XCTAssertThrowsError(try UserContentPolicy.validate(String(repeating: "🏀", count: field.maximumLength + 1), field: field))
        }
    }

}
