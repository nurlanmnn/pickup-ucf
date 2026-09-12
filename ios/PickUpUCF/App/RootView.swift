import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if appState.isAuthenticated {
                if appState.needsOnboarding {
                    OnboardingView()
                } else {
                    MainTabView()
                }
            } else {
                WelcomeView()
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: appState.isAuthenticated)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: appState.needsOnboarding)
        .globalBannerOverlay(appState: appState)
    }
}

#Preview {
    RootView()
        .environment(AppState())
}
