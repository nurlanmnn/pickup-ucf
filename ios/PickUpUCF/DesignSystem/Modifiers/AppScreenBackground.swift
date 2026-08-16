import SwiftUI

// MARK: - AppScreenBackground modifier

private struct AppScreenBackground: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    AppColor.background(colorScheme)
                        .ignoresSafeArea()

                    // Subtle gold radial glow from the top — Night Court atmosphere.
                    AppTheme.backgroundGlow(colorScheme)
                        .ignoresSafeArea()
                }
            }
    }
}

extension View {
    /// Applies the "Night Court" warm background with a subtle top gold radial glow.
    /// Use on the outermost `ScrollView` or `ZStack` of a full-screen view.
    func appScreenBackground() -> some View {
        modifier(AppScreenBackground())
    }
}
