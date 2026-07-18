import Foundation

struct Profile: Codable, Identifiable, Equatable {
    let id: UUID
    var displayName: String
    var username: String?
    var gamesPlayed: Int
    var showUpStreak: Int

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case username
        case gamesPlayed = "games_played"
        case showUpStreak = "show_up_streak"
    }
}

struct ProfileUpsert: Encodable {
    let id: UUID
    let displayName: String

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
    }
}
