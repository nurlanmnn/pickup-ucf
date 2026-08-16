import SwiftUI

// MARK: - AppCardStyle modifier

private struct AppCardStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(
                color: colorScheme == .dark
                    ? Color.black.opacity(0.30)
                    : AppTheme.cardShadowLight,
                radius: AppTheme.cardShadowRadius,
                x: 0,
                y: AppTheme.cardShadowY
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        colorScheme == .dark
                            ? Color.white.opacity(0.07)
                            : Color.clear,
                        lineWidth: 0.5
                    )
            }
    }
}

extension View {
    /// Applies "Night Court" card styling: soft shadow (light) / dark inner glow (dark),
    /// no hairline border in light mode.
    func appCardStyle(cornerRadius: CGFloat = 20) -> some View {
        modifier(AppCardStyle(cornerRadius: cornerRadius))
    }
}
