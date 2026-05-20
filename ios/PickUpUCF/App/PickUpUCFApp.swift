import SwiftUI

@main
struct PickUpUCFApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .preferredColorScheme(appState.preferredColorScheme)
                .onOpenURL { url in
                    handleDeepLink(url)
                }
                .task {
                    if !AppConfig.isConfigured {
                        appState.showError(
                            "Supabase is not configured. Copy Config.xcconfig.example → Config.xcconfig and add your project URL and anon key."
                        )
                    }
                    if let session = await AuthRepository().currentSession() {
                        await AuthenticatedSessionCoordinator.bootstrap(session: session, appState: appState)
                    }
                }
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard let destination = DeepLinkRouter.destination(from: url) else { return }
        switch destination {
        case .confirmEmail, .resetPassword:
            Task {
                do {
                    try await AuthRepository().handleAuthDeepLink(url: url)
                    if let session = await AuthRepository().currentSession() {
                        await AuthenticatedSessionCoordinator.bootstrap(session: session, appState: appState)
                    }
                } catch {
                    appState.showError(error)
                }
            }
        case .session:
            break
        }
    }
}

@Observable
final class AppState {
    var session: AppSession?
    var preferredColorScheme: ColorScheme?
    var bannerMessage: String?
    var bannerIsError = true
    /// Increment so Profile (and similar) can reload after account edits.
    private(set) var profileRefreshNonce = 0
    /// Increment so Discover / My Games reload after creating or editing sessions.
    private(set) var sessionFeedRefreshNonce = 0

    var isAuthenticated: Bool {
        session?.isEmailConfirmed == true
    }

    func touchProfileRefresh() {
        profileRefreshNonce += 1
    }

    func touchSessionFeedRefresh() {
        sessionFeedRefreshNonce += 1
    }

    func showError(_ error: Error) {
        bannerMessage = AppErrorMapper.message(for: error)
        bannerIsError = true
    }

    func showError(_ message: String) {
        bannerMessage = message
        bannerIsError = true
    }

    func showSuccess(_ message: String) {
        bannerMessage = message
        bannerIsError = false
    }

    func clearBanner() {
        bannerMessage = nil
    }
}

struct AppSession {
    let userId: UUID
    let email: String
    let isEmailConfirmed: Bool
}
