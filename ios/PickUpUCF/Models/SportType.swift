import Foundation

enum SportType: String, CaseIterable, Codable, Identifiable {
    case basketball
    case soccer
    case tennis
    case volleyball
    case football
    case other

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }

    var systemImage: String {
        switch self {
        case .basketball: return "basketball.fill"
        case .soccer: return "soccerball"
        case .tennis: return "tennisball.fill"
        case .volleyball: return "volleyball.fill"
        case .football: return "football.fill"
        case .other: return "sportscourt.fill"
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
