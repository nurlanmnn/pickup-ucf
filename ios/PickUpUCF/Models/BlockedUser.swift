import Foundation

struct BlockUserParams: Encodable {
    let pBlockedId: UUID

    enum CodingKeys: String, CodingKey {
        case pBlockedId = "p_blocked_id"
    }
}

struct BlockedUser: Codable, Identifiable, Equatable {
    let id: UUID
    let displayName: String
    let username: String?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case username
    }

    var handle: String {
        if let username, !username.isEmpty { return "@\(username)" }
        return displayName
    }
}

struct UnblockUserParams: Encodable {
    let pBlockedId: UUID

    enum CodingKeys: String, CodingKey {
        case pBlockedId = "p_blocked_id"
    }
}
