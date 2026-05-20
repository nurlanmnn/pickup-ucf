import Foundation

struct SessionMessage: Codable, Identifiable, Equatable {
    let id: UUID
    let sessionId: UUID
    let userId: UUID
    let body: String
    let createdAt: Date
    var author: ProfileSummary?

    enum CodingKeys: String, CodingKey {
        case id
        case sessionId = "session_id"
        case userId = "user_id"
        case body
        case createdAt = "created_at"
        case author
    }

    func senderLabel(currentUserId: UUID) -> String {
        if userId == currentUserId { return "You" }
        return author?.handle ?? "Player"
    }
}

struct MessageInsert: Encodable {
    let sessionId: UUID
    let userId: UUID
    let body: String

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case userId = "user_id"
        case body
    }
}
