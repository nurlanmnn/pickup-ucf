import Foundation

struct Profile: Codable, Identifiable, Equatable {
    let id: UUID
    var displayName: String
    var username: String?
    var gamesPlayed: Int
    var showUpStreak: Int
    var preferredSports: [SportType]
    var skillLevel: SkillLevel?
    var onboardingCompletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case username
        case gamesPlayed = "games_played"
        case showUpStreak = "show_up_streak"
        case preferredSports = "preferred_sports"
        case skillLevel = "skill_level"
        case onboardingCompletedAt = "onboarding_completed_at"
    }

    init(
        id: UUID,
        displayName: String,
        username: String? = nil,
        gamesPlayed: Int = 0,
        showUpStreak: Int = 0,
        preferredSports: [SportType] = [],
        skillLevel: SkillLevel? = nil,
        onboardingCompletedAt: Date? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.username = username
        self.gamesPlayed = gamesPlayed
        self.showUpStreak = showUpStreak
        self.preferredSports = preferredSports
        self.skillLevel = skillLevel
        self.onboardingCompletedAt = onboardingCompletedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        username = try container.decodeIfPresent(String.self, forKey: .username)
        gamesPlayed = try container.decodeIfPresent(Int.self, forKey: .gamesPlayed) ?? 0
        showUpStreak = try container.decodeIfPresent(Int.self, forKey: .showUpStreak) ?? 0
        preferredSports = try container.decodeIfPresent([SportType].self, forKey: .preferredSports) ?? []
        skillLevel = try container.decodeIfPresent(SkillLevel.self, forKey: .skillLevel)
        onboardingCompletedAt = try container.decodeIfPresent(Date.self, forKey: .onboardingCompletedAt)
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
