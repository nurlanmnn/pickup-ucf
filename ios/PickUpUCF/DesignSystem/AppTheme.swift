import SwiftUI

/// Central hub for "Night Court" visual identity tokens.
/// Prefer the helpers here over raw `AppColor` calls when building full-screen layouts.
enum AppTheme {

    // MARK: - Screen background gradient

    /// Radial gold glow layered on top of the flat background — used by `AppScreenBackground`.
    static func backgroundGlow(_ scheme: ColorScheme) -> RadialGradient {
        RadialGradient(
            colors: [
                AppColor.gold.opacity(scheme == .dark ? 0.10 : 0.06),
                Color.clear
            ],
            center: .top,
            startRadius: 0,
            endRadius: 320
        )
    }

    // MARK: - Card shadow tokens

    /// Soft drop shadow for elevated cards (light mode).
    static let cardShadowLight = Color.black.opacity(0.07)
    static let cardShadowRadius: CGFloat = 12
    static let cardShadowY: CGFloat = 4

    /// Subtle inner-glow tint for dark mode card borders.
    static func cardGlowDark(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.07) : Color.clear
    }

    // MARK: - Sport card gradients

    /// Full-bleed gradient for a sport card header or strip.
    static func sportCardGradient(_ sport: SportType, scheme: ColorScheme) -> LinearGradient {
        let base = AppColor.sportAccent(sport)
        return LinearGradient(
            colors: scheme == .dark
                ? [base.opacity(0.85), base.opacity(0.40)]
                : [base.opacity(0.80), base.opacity(0.35)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    // MARK: - Relative-time badge palette

    static let badgeGold = AppColor.gold
    static let badgeGoldText = Color.black

    static func badgeSoon(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 1.0, green: 0.35, blue: 0.25) : Color(red: 0.95, green: 0.25, blue: 0.15)
    }
}
