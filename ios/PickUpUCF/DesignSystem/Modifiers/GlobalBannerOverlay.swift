import SwiftUI

extension View {
    /// Renders a floating toast at the bottom of the screen so it never
    /// collides with the navigation bar at the top.
    func globalBannerOverlay(appState: AppState) -> some View {
        overlay(alignment: .bottom) {
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
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(999)
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.80), value: appState.bannerMessage)
    }
}
