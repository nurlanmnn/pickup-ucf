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
                    guard let target = note.object as? PushNavigationTarget else { return }
                    appState.queueSessionDeepLink(id: target.sessionId, openChat: target.openChat)
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
            appState.queueSessionDeepLink(id: id, openChat: false)
        }
    }
}

enum SessionDetailDeepLinkTarget {
    case discover
    case myGames
}

struct PushNavigationTarget: Equatable {
    let sessionId: UUID
    let openChat: Bool
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
    var pendingSessionDeepLinkOpenChat = false
    /// When true, session detail should push chat after loading (from chat push).
    var sessionDetailOpenChat = false
    /// True when the signed-in user has not finished first-run onboarding.
    var needsOnboarding = false
    /// Incremented to request presenting Create session from tabs (e.g. Discover host nudge).
    private(set) var createSessionRequestNonce = 0
    var pendingCreateSessionPrefill: CreateSessionPrefill?

    var isAuthenticated: Bool {
        session?.isEmailConfirmed == true
    }

    func touchProfileRefresh() {
        profileRefreshNonce += 1
    }

    func touchSessionFeedRefresh() {
        sessionFeedRefreshNonce += 1
    }

    func requestCreateSession(prefill: CreateSessionPrefill? = nil) {
        pendingCreateSessionPrefill = prefill
        createSessionRequestNonce += 1
    }

    func consumePendingCreateSessionPrefill() -> CreateSessionPrefill? {
        defer { pendingCreateSessionPrefill = nil }
        return pendingCreateSessionPrefill
    }

    func presentSessionDetail(id: UUID, on target: SessionDetailDeepLinkTarget) {
        sessionDetailDeepLink = id
        sessionDetailDeepLinkTarget = target
    }

    func clearSessionDetailDeepLink() {
        sessionDetailDeepLink = nil
        sessionDetailOpenChat = false
    }

    func queueSessionDeepLink(id: UUID, openChat: Bool = false) {
        sessionDetailOpenChat = openChat
        if isAuthenticated {
            presentSessionDetail(id: id, on: .discover)
        } else {
            pendingSessionDeepLink = id
            pendingSessionDeepLinkOpenChat = openChat
        }
    }

    func consumePendingSessionDeepLinkIfNeeded() {
        guard let id = pendingSessionDeepLink, isAuthenticated else { return }
        let openChat = pendingSessionDeepLinkOpenChat
        pendingSessionDeepLink = nil
        pendingSessionDeepLinkOpenChat = false
        queueSessionDeepLink(id: id, openChat: openChat)
    }

    func consumeSessionDetailOpenChat(for sessionId: UUID) -> Bool {
        guard sessionDetailDeepLink == sessionId, sessionDetailOpenChat else { return false }
        sessionDetailOpenChat = false
        return true
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
