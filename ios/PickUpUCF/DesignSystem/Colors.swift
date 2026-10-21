import SwiftUI

enum AppColor {
    // Gold is reserved for filled actions and highlights; use accent for readable links.
    static let gold = Color(red: 0.96, green: 0.76, blue: 0.24)
    static let goldDark = Color(red: 0.77, green: 0.57, blue: 0.12)
    static let courtGreen = Color(red: 0.16, green: 0.32, blue: 0.28)
    static let courtClay = Color(red: 0.67, green: 0.32, blue: 0.23)
    static let courtBlue = Color(red: 0.22, green: 0.37, blue: 0.48)
    static let courtLine = Color(red: 0.96, green: 0.93, blue: 0.83)

    static func background(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.07, green: 0.08, blue: 0.08)
            : Color(red: 0.985, green: 0.978, blue: 0.96)
    }

    static func surface(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.115, green: 0.125, blue: 0.12) : .white
    }

    static func elevatedSurface(_ scheme: ColorScheme) -> Color { surface(scheme) }

    static func mutedSurface(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.16, green: 0.17, blue: 0.165)
            : Color(red: 0.945, green: 0.935, blue: 0.91)
    }

    static func border(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.12)
    }

    static func textPrimary(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.96, green: 0.96, blue: 0.94)
            : Color(red: 0.13, green: 0.15, blue: 0.14)
    }

    static func textSecondary(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.69, green: 0.71, blue: 0.69)
            : Color(red: 0.39, green: 0.41, blue: 0.39)
    }

    static func accent(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? gold : textPrimary(scheme)
    }

    static let destructive = Color.red
    static let success = Color.green

    // MARK: - Sport accents

    static func sportAccent(_ sport: SportType) -> Color {
        switch sport {
        case .basketball: return Color(red: 0.96, green: 0.50, blue: 0.14)
        case .soccer: return Color(red: 0.22, green: 0.72, blue: 0.33)
        case .tennis: return Color(red: 0.75, green: 0.85, blue: 0.10)
        case .volleyball: return Color(red: 0.24, green: 0.55, blue: 0.94)
        case .football: return Color(red: 0.55, green: 0.35, blue: 0.15)
        case .other: return Color(red: 0.55, green: 0.55, blue: 0.60)
        case .pickleball: return Color(red: 0.13, green: 0.72, blue: 0.67)
        case .flagFootball: return Color(red: 0.96, green: 0.45, blue: 0.18)
        case .spikeball: return Color(red: 0.96, green: 0.78, blue: 0.08)
        case .softball: return Color(red: 0.95, green: 0.65, blue: 0.20)
        case .floorHockey: return Color(red: 0.24, green: 0.55, blue: 0.94)
        case .dodgeball: return Color(red: 0.88, green: 0.24, blue: 0.24)
        case .racquetball: return Color(red: 0.64, green: 0.24, blue: 0.88)
        case .badminton: return Color(red: 0.16, green: 0.78, blue: 0.62)
        case .cornhole: return Color(red: 0.58, green: 0.38, blue: 0.18)
        }
    }

    /// Two-stop gradient representing the sport on a card header strip.
    static func sportGradient(_ sport: SportType) -> LinearGradient {
        let accent = sportAccent(sport)
        return LinearGradient(
            colors: [accent, accent.opacity(0.65)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
