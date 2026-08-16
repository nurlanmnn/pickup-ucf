import XCTest
@testable import PickUpUCF

final class DeviceTokenRepositoryTests: XCTestCase {
    func testUpsertRowEncodesSnakeCaseKeys() throws {
        let userId = UUID(uuidString: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890")!
        let row = DeviceTokenUpsertRow(userId: userId, apnsToken: "abc123")

        let data = try JSONEncoder().encode(row)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: String])

        XCTAssertEqual(json["user_id"], userId.uuidString)
        XCTAssertEqual(json["apns_token"], "abc123")
    }
}
