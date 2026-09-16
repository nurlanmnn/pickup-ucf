import XCTest
@testable import PickUpUCF

final class BlockedUsersTests: XCTestCase {
    func testBlockedUserDecodesListRPCFields() throws {
        let blockedId = UUID(uuidString: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890")!

        let json = """
        {
          "id": "\(blockedId.uuidString)",
          "display_name": "Blocked Person",
          "username": "blockeduser"
        }
        """.data(using: .utf8)!

        let user = try JSONDecoder().decode(BlockedUser.self, from: json)

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
