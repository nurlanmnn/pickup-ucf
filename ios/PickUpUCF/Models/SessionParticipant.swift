import Foundation

struct SessionParticipant: Identifiable, Decodable, Equatable {
    let userId: UUID
    let displayName: String
    let username: String?

    var id: UUID { userId }

    enum CodingKeys: String, CodingKey {
        case userId = "id"
        case displayName = "display_name"
        case username
    }

    var handle: String {
        if let username, !username.isEmpty { return "@\(username)" }
        return displayName
    }
}
