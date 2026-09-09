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

    func testLiveActivityRegistrationParamsEncodeRPCKeys() throws {
        let sessionId = UUID(uuidString: "B1C2D3E4-F5A6-7890-BCDE-F1234567890A")!
        let params = LiveActivityTokenRegistrationParams(
            sessionId: sessionId,
            apnsToken: "def456"
        )

        let data = try JSONEncoder().encode(params)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: String])

        XCTAssertEqual(json["p_session_id"], sessionId.uuidString)
        XCTAssertEqual(json["p_apns_token"], "def456")
    }
}
