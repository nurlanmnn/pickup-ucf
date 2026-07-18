import XCTest
@testable import PickUpUCF

final class SessionShareLinkTests: XCTestCase {
    func testURLFormat() {
        let id = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        XCTAssertEqual(
            SessionShareLink.url(for: id).absoluteString,
            "pickupucf://session/00000000-0000-0000-0000-000000000001"
        )
    }

    func testDeepLinkRouterParsesSessionURL() {
        let url = SessionShareLink.url(for: UUID())
        if case .session = DeepLinkRouter.destination(from: url) {
            // pass
        } else {
            XCTFail("Expected session destination")
        }
    }
}
