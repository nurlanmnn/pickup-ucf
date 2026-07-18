import SwiftUI

@main
struct PickUpUCFApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .preferredColorScheme(appState.preferredColorScheme)
                .onOpenURL { url in
                    handleDeepLink(url)
                }
                .onReceive(NotificationCenter.default.publisher(for: .pushDeepLink)) { note in
                    guard let url = note.object as? URL,
                          case .session(let id) = DeepLinkRouter.destination(from: url) else { return }
                    appState.queueSessionDeepLink(id: id)
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
        case .session(let id):
            appState.queueSessionDeepLink(id: id)
        }
    }
}

enum SessionDetailDeepLinkTarget {
    case discover
    case myGames
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
    /// Pushes `SessionDetailView` on Discover or My Games (see `sessionDetailDeepLinkTarget`).
    var sessionDetailDeepLink: UUID?
    var sessionDetailDeepLinkTarget: SessionDetailDeepLinkTarget = .discover
    /// Opened via `pickupucf://session/…` before the user signed in.
    var pendingSessionDeepLink: UUID?

    var isAuthenticated: Bool {
        session?.isEmailConfirmed == true
    }

    func touchProfileRefresh() {
        profileRefreshNonce += 1
    }

    func touchSessionFeedRefresh() {
        sessionFeedRefreshNonce += 1
    }

    func presentSessionDetail(id: UUID, on target: SessionDetailDeepLinkTarget) {
        sessionDetailDeepLink = id
        sessionDetailDeepLinkTarget = target
    }

    func clearSessionDetailDeepLink() {
        sessionDetailDeepLink = nil
    }

    func queueSessionDeepLink(id: UUID) {
        if isAuthenticated {
            presentSessionDetail(id: id, on: .discover)
        } else {
            pendingSessionDeepLink = id
        }
    }

    func consumePendingSessionDeepLinkIfNeeded() {
        guard let id = pendingSessionDeepLink, isAuthenticated else { return }
        pendingSessionDeepLink = nil
        presentSessionDetail(id: id, on: .discover)
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
