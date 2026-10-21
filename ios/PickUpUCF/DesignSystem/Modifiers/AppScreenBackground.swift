import SwiftUI

// MARK: - AppScreenBackground modifier

private struct AppScreenBackground: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .tint(AppColor.accent(colorScheme))
            .foregroundStyle(AppColor.textPrimary(colorScheme))
            .background(AppColor.background(colorScheme).ignoresSafeArea())
    }
}

extension View {
    /// Applies the neutral app background to a full-screen view.
    func appScreenBackground() -> some View {
        modifier(AppScreenBackground())
    }
}
