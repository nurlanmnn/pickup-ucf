import SwiftUI

struct RootView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if appState.isAuthenticated {
                if let recoveryId = appState.passwordRecoveryUserId,
                   recoveryId == appState.session?.userId {
                    NavigationStack { ResetPasswordView(userId: recoveryId) }
                } else if appState.needsOnboarding {
                    OnboardingView()
                } else {
                    MainTabView()
                        .id(appState.session?.userId)
                }
            } else {
                WelcomeView()
            }
        }
        .tint(AppColor.accent(colorScheme))
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: appState.isAuthenticated)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: appState.needsOnboarding)
        .globalBannerOverlay(appState: appState)
    }
}

#Preview {
    RootView()
        .environment(AppState())
}
