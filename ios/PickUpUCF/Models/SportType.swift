import Foundation

enum SportType: String, CaseIterable, Codable, Identifiable {
    case basketball
    case soccer
    case tennis
    case volleyball
    case football
    case other
    case pickleball
    case flagFootball = "flag_football"
    case spikeball
    case softball
    case floorHockey = "floor_hockey"
    case dodgeball
    case racquetball
    case badminton
    case cornhole

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .basketball: return "Basketball"
        case .soccer: return "Soccer"
        case .tennis: return "Tennis"
        case .volleyball: return "Volleyball"
        case .football: return "Football"
        case .other: return "Other"
        case .pickleball: return "Pickleball"
        case .flagFootball: return "Flag Football"
        case .spikeball: return "Spikeball"
        case .softball: return "Softball"
        case .floorHockey: return "Floor Hockey"
        case .dodgeball: return "Dodgeball"
        case .racquetball: return "Racquetball"
        case .badminton: return "Badminton"
        case .cornhole: return "Cornhole"
        }
    }

    var systemImage: String {
        switch self {
        case .basketball: return "basketball.fill"
        case .soccer: return "soccerball"
        case .tennis: return "tennisball.fill"
        case .volleyball: return "volleyball.fill"
        case .football: return "football.fill"
        case .other: return "sportscourt.fill"
        case .pickleball: return "tennisball"
        case .flagFootball: return "figure.american.football"
        case .spikeball: return "network"
        case .softball: return "figure.softball"
        case .floorHockey: return "figure.hockey"
        case .dodgeball: return "figure.run"
        case .racquetball: return "circle.circle"
        case .badminton: return "figure.badminton"
        case .cornhole: return "target"
        }
    }
}

enum SkillLevel: String, CaseIterable, Codable, Identifiable {
    case any
    case beginner
    case intermediate
    case advanced

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .any: return "Any"
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        }
    }
}
