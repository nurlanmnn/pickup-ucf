import XCTest
@testable import PickUpUCF

final class BlockedMessageFilterTests: XCTestCase {
    func testRemovesMessagesFromBlockedUsersButKeepsOwnAndUnrelatedMessages() {
        let currentUser = UUID()
        let blockedUser = UUID()
        let otherUser = UUID()
        let sessionId = UUID()
        let messages = [
            message(userId: currentUser, sessionId: sessionId, body: "Mine"),
            message(userId: blockedUser, sessionId: sessionId, body: "Blocked"),
            message(userId: otherUser, sessionId: sessionId, body: "Visible"),
        ]

        let visible = BlockedMessageFilter.visibleMessages(
            messages,
            currentUserId: currentUser,
            blockedUserIds: [blockedUser]
        )

        XCTAssertEqual(visible.map(\.body), ["Mine", "Visible"])
    }

    private func message(userId: UUID, sessionId: UUID, body: String) -> SessionMessage {
        SessionMessage(
            id: UUID(),
            sessionId: sessionId,
            userId: userId,
            body: body,
            createdAt: .now,
            author: nil
        )
    }
}
