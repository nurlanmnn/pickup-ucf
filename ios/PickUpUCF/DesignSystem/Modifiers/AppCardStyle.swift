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
                        AppColor.border(colorScheme),
                        lineWidth: 1
                    )
            }
    }
}

extension View {
    /// Consistent hairline border and restrained elevation in both appearances.
    func appCardStyle(cornerRadius: CGFloat = 16) -> some View {
        modifier(AppCardStyle(cornerRadius: cornerRadius))
    }
}
