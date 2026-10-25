import SwiftUI

struct RootView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
        .overlay(alignment: .topLeading) {
            #if DEBUG && targetEnvironment(simulator)
            if AppTestMode.current.isUISmoke {
                Color.clear.frame(width: 1, height: 1)
                    .accessibilityElement()
                    .accessibilityLabel("Isolated UI smoke")
                    .accessibilityValue(String(describing: dynamicTypeSize))
                    .accessibilityIdentifier("ui-smoke-isolated")
            }
            #endif
        }
    }
}

#Preview {
    RootView()
        .environment(AppState())
}
