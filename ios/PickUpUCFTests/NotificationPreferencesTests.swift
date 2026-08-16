import XCTest
@testable import PickUpUCF

final class NotificationPreferencesTests: XCTestCase {
    func testDefaultsAreAllTrueWhenNoRow() {
        let userId = UUID(uuidString: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890")!
        let preferences = NotificationPreferences.defaults(userId: userId)

        XCTAssertEqual(preferences.userId, userId)
        XCTAssertTrue(preferences.sessionReminders)
        XCTAssertTrue(preferences.waitlistPromoted)
        XCTAssertTrue(preferences.sessionCancelled)
        XCTAssertTrue(preferences.hostPlayerJoined)
        XCTAssertTrue(preferences.hostSessionReminder)
        XCTAssertTrue(preferences.chatMessages)
        XCTAssertNil(preferences.updatedAt)
    }

    func testEncodesSnakeCaseKeys() throws {
        let userId = UUID(uuidString: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890")!
        let preferences = NotificationPreferences(
            userId: userId,
            sessionReminders: false,
            waitlistPromoted: true,
            sessionCancelled: false,
            hostPlayerJoined: true,
            hostSessionReminder: false,
            chatMessages: true
        )

        let data = try JSONEncoder().encode(preferences)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(json["user_id"] as? String, userId.uuidString)
        XCTAssertEqual(json["session_reminders"] as? Bool, false)
        XCTAssertEqual(json["waitlist_promoted"] as? Bool, true)
        XCTAssertEqual(json["session_cancelled"] as? Bool, false)
        XCTAssertEqual(json["host_player_joined"] as? Bool, true)
        XCTAssertEqual(json["host_session_reminder"] as? Bool, false)
        XCTAssertEqual(json["chat_messages"] as? Bool, true)
    }
}
