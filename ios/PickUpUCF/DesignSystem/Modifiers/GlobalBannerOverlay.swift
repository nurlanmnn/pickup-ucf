import SwiftUI

extension View {
    func globalBannerOverlay(appState: AppState) -> some View {
        overlay(alignment: .top) {
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
                .padding(.top, Spacing.s)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: appState.bannerMessage)
    }
}
