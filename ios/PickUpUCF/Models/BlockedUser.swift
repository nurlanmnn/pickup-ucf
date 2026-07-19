import Foundation

struct BlockUserParams: Encodable {
    let pBlockedId: UUID

    enum CodingKeys: String, CodingKey {
        case pBlockedId = "p_blocked_id"
    }
}

struct BlockedUser: Identifiable, Equatable {
    let id: UUID
    let displayName: String
    let username: String?

    var handle: String {
        if let username, !username.isEmpty { return "@\(username)" }
        return displayName
    }
}

struct BlockedUserRow: Decodable {
    let blockedId: UUID
    let blocked: ProfileSummary

    enum CodingKeys: String, CodingKey {
        case blockedId = "blocked_id"
        case blocked = "profiles"
    }

    var blockedUser: BlockedUser {
        BlockedUser(
            id: blockedId,
            displayName: blocked.displayName,
            username: blocked.username
        )
    }
}

struct UnblockUserParams: Encodable {
    let pBlockedId: UUID

    enum CodingKeys: String, CodingKey {
        case pBlockedId = "p_blocked_id"
    }
}
