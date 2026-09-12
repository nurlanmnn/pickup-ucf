import SwiftUI

extension View {
    /// Renders a floating toast at the bottom of the screen so it never
    /// collides with the navigation bar at the top.
    func globalBannerOverlay(appState: AppState) -> some View {
        modifier(GlobalBannerOverlayModifier(appState: appState))
    }
}

private struct GlobalBannerOverlayModifier: ViewModifier {
    let appState: AppState

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let message = appState.bannerMessage {
                    Group {
                        if appState.bannerIsError {
                            ErrorBanner(message: message) {
                                appState.clearBanner()
                            }
                        } else {
                            SuccessBanner(message: message) {
                                appState.clearBanner()
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.m)
                    // Sit above the tab bar + home indicator.
                    .padding(.bottom, 90)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                    .zIndex(999)
                }
            }
            .animation(
                reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.80),
                value: appState.bannerMessage
            )
    }
}
