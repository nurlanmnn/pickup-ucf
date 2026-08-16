import SwiftUI

enum AppColor {
    static let gold = Color(red: 1.0, green: 0.788, blue: 0.016)
    static let goldDark = Color(red: 0.9, green: 0.7, blue: 0.0)

    // MARK: - Base surfaces

    static func background(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.05, green: 0.05, blue: 0.06) : Color(red: 0.973, green: 0.969, blue: 0.957)
    }

    static func surface(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.11, green: 0.11, blue: 0.12) : .white
    }

    // MARK: - Semantic elevation tokens

    /// Slightly raised surface — cards on a coloured background (light: pure white, dark: mid-grey).
    static func elevatedSurface(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.14, green: 0.14, blue: 0.15) : Color.white
    }

    /// Toned-down fill for secondary areas, tag backgrounds, skeleton placeholders.
    static func mutedSurface(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.09, green: 0.09, blue: 0.10) : Color(red: 0.94, green: 0.94, blue: 0.93)
    }

    // MARK: - Text

    static func textPrimary(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? .white : Color(red: 0.05, green: 0.05, blue: 0.05)
    }

    static func textSecondary(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.55) : Color.black.opacity(0.50)
    }

    // MARK: - Gold glows + accents

    /// Soft ambient glow — use as a radial gradient stop, not solid fill.
    static let goldGlow = Color(red: 1.0, green: 0.788, blue: 0.016).opacity(0.18)

    // MARK: - Semantic state

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
