import XCTest
@testable import PickUpUCF

final class BlockedUsersTests: XCTestCase {
    func testBlockedUserRowMapsProfileFields() throws {
        let blockedId = UUID(uuidString: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890")!
        let profileId = UUID(uuidString: "B1B2C3D4-E5F6-7890-ABCD-EF1234567890")!

        let json = """
        {
          "blocked_id": "\(blockedId.uuidString)",
          "profiles": {
            "id": "\(profileId.uuidString)",
            "display_name": "Blocked Person",
            "username": "blockeduser"
          }
        }
        """.data(using: .utf8)!

        let row = try JSONDecoder().decode(BlockedUserRow.self, from: json)
        let user = row.blockedUser

        XCTAssertEqual(user.id, blockedId)
        XCTAssertEqual(user.displayName, "Blocked Person")
        XCTAssertEqual(user.username, "blockeduser")
        XCTAssertEqual(user.handle, "@blockeduser")
    }

    func testBlockedUserHandleFallsBackToDisplayName() {
        let user = BlockedUser(id: UUID(), displayName: "No Username", username: nil)
        XCTAssertEqual(user.handle, "No Username")
    }
}
