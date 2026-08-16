import XCTest
@testable import PickUpUCF

final class SessionRosterTests: XCTestCase {
    private let decoder = JSONDecoder()

    func testDecodeSampleJson() throws {
        let hostId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let playerId = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!

        let json = """
        {
          "joined": [
            {
              "user_id": "\(hostId.uuidString)",
              "display_name": "Host Player",
              "username": "hostplayer",
              "role": "host"
            },
            {
              "user_id": "\(playerId.uuidString)",
              "display_name": "Joined Player",
              "username": null,
              "role": "player"
            }
          ],
          "waitlist_count": 2,
          "viewer_waitlist_position": 1
        }
        """.data(using: .utf8)!

        let roster = try decoder.decode(SessionRoster.self, from: json)

        XCTAssertEqual(roster.joined.count, 2)
        XCTAssertEqual(roster.joined[0].role, .host)
        XCTAssertEqual(roster.joined[1].displayName, "Joined Player")
        XCTAssertEqual(roster.waitlistCount, 2)
        XCTAssertEqual(roster.viewerWaitlistPosition, 1)
    }

    func testWaitlistLabelFormatting() {
        let roster = SessionRoster(
            joined: [],
            waitlistCount: 3,
            viewerWaitlistPosition: 2
        )

        XCTAssertEqual(
            roster.waitlistLabel(participantStatus: .waitlist),
            "You're #2 on the waitlist (3 waiting)"
        )
        XCTAssertNil(roster.waitlistLabel(participantStatus: .joined))
        XCTAssertNil(
            SessionRoster(joined: [], waitlistCount: 1, viewerWaitlistPosition: nil)
                .waitlistLabel(participantStatus: .waitlist)
        )
    }
}
