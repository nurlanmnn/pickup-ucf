import SwiftUI

enum AppColor {
    static let gold = Color(red: 1.0, green: 0.788, blue: 0.016)
    static let goldDark = Color(red: 0.9, green: 0.7, blue: 0.0)

    static func background(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.05, green: 0.05, blue: 0.06) : Color(red: 0.973, green: 0.969, blue: 0.957)
    }

    static func surface(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.11, green: 0.11, blue: 0.12) : .white
    }

    static func textPrimary(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? .white : Color(red: 0.05, green: 0.05, blue: 0.05)
    }

    static func textSecondary(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.65) : Color.black.opacity(0.55)
    }

    static let destructive = Color.red
    static let success = Color.green

    static func sportAccent(_ sport: SportType) -> Color {
        switch sport {
        case .basketball: return Color.orange
        case .soccer: return Color.green
        case .tennis: return Color.yellow
        case .volleyball: return Color.blue
        case .football: return Color.brown
        case .other: return Color.gray
        case .pickleball, .spikeball, .softball, .floorHockey, .dodgeball, .racquetball, .badminton, .cornhole:
            return Color.gray
        case .flagFootball: return Color.brown
        }
    }
}
