import SwiftUI

/// Central hub for shared visual tokens.
/// Prefer the helpers here over raw `AppColor` calls when building full-screen layouts.
enum AppTheme {

    // MARK: - Card shadow tokens

    /// Soft drop shadow for elevated cards (light mode).
    static let cardShadowLight = Color.black.opacity(0.035)
    static let cardShadowRadius: CGFloat = 8
    static let cardShadowY: CGFloat = 2

    /// Subtle inner-glow tint for dark mode card borders.
    static func cardGlowDark(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.035) : Color.clear
    }

    // MARK: - Sport card gradients

    /// Full-bleed gradient for a sport card header or strip.
    static func sportCardGradient(_ sport: SportType, scheme: ColorScheme) -> LinearGradient {
        let base = courtColor(sport)
        return LinearGradient(colors: [base, base], startPoint: .top, endPoint: .bottom)
    }

    static func courtColor(_ sport: SportType) -> Color {
        switch sport {
        case .basketball, .football, .flagFootball, .softball, .dodgeball, .cornhole:
            return AppColor.courtClay
        case .volleyball, .floorHockey, .racquetball:
            return AppColor.courtBlue
        default:
            return AppColor.courtGreen
        }
    }

    // MARK: - Relative-time badge palette

    static let badgeGold = AppColor.gold
    static let badgeGoldText = Color.black

    static func badgeSoon(_ scheme: ColorScheme) -> Color {
        Color(red: 0.70, green: 0.20, blue: 0.14)
    }
}

/// Original court illustration, shared by welcome, discovery, and game details.
/// Decorative only; the surrounding screen supplies the game information.
struct CourtArtwork: View {
    let sport: SportType

    var body: some View {
        Canvas { context, size in
            let court = CGRect(x: size.width * 0.10, y: size.height * 0.12,
                               width: size.width * 0.80, height: size.height * 0.76)
            var lines = Path()
            lines.addRect(court)
            lines.move(to: CGPoint(x: court.midX, y: court.minY))
            lines.addLine(to: CGPoint(x: court.midX, y: court.maxY))
            if [.tennis, .pickleball, .badminton, .volleyball].contains(sport) {
                let inner = court.insetBy(dx: 0, dy: court.height * 0.18)
                lines.addRect(inner)
                let service = inner.insetBy(dx: court.width * 0.22, dy: 0)
                lines.addRect(service)
                lines.move(to: CGPoint(x: service.minX, y: court.midY))
                lines.addLine(to: CGPoint(x: service.maxX, y: court.midY))
            } else {
                let radius = court.height * 0.19
                lines.addEllipse(in: CGRect(x: court.midX - radius, y: court.midY - radius,
                                           width: radius * 2, height: radius * 2))
                let boxWidth = court.width * 0.18
                let boxHeight = court.height * 0.48
                for x in [court.minX, court.maxX - boxWidth] {
                    lines.addRect(CGRect(x: x, y: court.midY - boxHeight / 2,
                                         width: boxWidth, height: boxHeight))
                }
            }
            context.stroke(lines, with: .color(AppColor.courtLine.opacity(0.65)), lineWidth: 1.5)
            // Two small player markers give the illustration a sense of life.
            for point in [CGPoint(x: court.width * 0.32 + court.minX, y: court.midY * 0.85),
                          CGPoint(x: court.width * 0.73 + court.minX, y: court.midY * 1.20)] {
                let marker = CGRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10)
                context.fill(Path(ellipseIn: marker), with: .color(AppColor.gold))
                context.stroke(Path(ellipseIn: marker), with: .color(AppColor.courtLine), lineWidth: 2)
            }
        }
        .background(AppTheme.courtColor(sport))
        .accessibilityHidden(true)
    }
}
