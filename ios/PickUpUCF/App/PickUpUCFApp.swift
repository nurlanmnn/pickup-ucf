import SwiftUI

@main
struct PickUpUCFApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var appState = AppState()

    init() {
        AppTestMode.current.preparePreferences()
        #if DEBUG && targetEnvironment(simulator)
        if AppTestMode.current == .uiSmokeAuthenticated {
            let state = AppState()
            state.session = AuthenticatedUISmokeFixture.appSession
            _appState = State(initialValue: state)
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch AppConfig.currentLaunchMode {
                case .ready:
                    RootView()
                case .serviceUnavailable:
                    ContentUnavailableView(
                        "Service Unavailable",
                        systemImage: "exclamationmark.triangle",
                        description: Text("Please try again later.")
                    )
                }
            }
            #if DEBUG && targetEnvironment(simulator)
            .safeAreaInset(edge: .top) {
                if AppTestMode.current == .uiSmokeAuthenticated {
                    HStack {
                        Button("Test session link") {
                            appState.queueSessionDeepLink(id: AuthenticatedUISmokeFixture.gameID)
                        }
                        Button("Test chat alert") {
                            appState.queueSessionDeepLink(id: AuthenticatedUISmokeFixture.gameID, openChat: true)
                        }
                    }
                }
            }
            #endif
            .environment(appState)
            .preferredColorScheme(appState.preferredColorScheme)
            .onOpenURL { url in
                handleDeepLink(url)
            }
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                if let url = activity.webpageURL { handleDeepLink(url) }
            }
            .onReceive(NotificationCenter.default.publisher(for: .pushDeepLink)) { note in
                guard !AppTestMode.current.isIsolated else { return }
                guard let target = note.object as? PushNavigationTarget else { return }
                appState.queueSessionDeepLink(id: target.sessionId, openChat: target.openChat)
            }
            .task {
                // Isolated test hosts must not restore a real account or touch system/backend state.
                guard !AppTestMode.current.isIsolated else { return }
                await GameLiveActivityCoordinator.endExpired()
                guard AppConfig.currentLaunchMode == .ready else { return }
                if let session = await AuthRepository().currentSession() {
                    await AuthenticatedSessionCoordinator.bootstrap(session: session, appState: appState)
                } else if appState.session == nil {
                    AccountLocalDataCleanup.clear()
                    await PushNotificationService.shared.prepareForMissingSession()
                }
            }
            .task(id: scenePhase) {
                guard !AppTestMode.current.isIsolated, scenePhase == .active else { return }
                while !Task.isCancelled {
                    await GameLiveActivityCoordinator.endExpired()
                    await SessionNotificationCleanup.removeDelivered()
                    let delay = await GameLiveActivityCoordinator.nextCleanupDelay()
                    do { try await Task.sleep(for: .seconds(delay)) }
                    catch { return }
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard !AppTestMode.current.isIsolated, newPhase == .active else { return }
                Task {
                    await GameLiveActivityCoordinator.endExpired()
                    await SessionNotificationCleanup.removeDelivered(resolveSessions: appState.isAuthenticated)
                    guard appState.isAuthenticated, let userId = appState.session?.userId else { return }
                    await GameLiveActivityCoordinator.refreshForCurrentUser(userId: userId)
                    await PushNotificationService.shared
                        .refreshRegistrationAfterAuthorizationChange()
                }
            }
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard !AppTestMode.current.isIsolated, AppConfig.currentLaunchMode == .ready else { return }
        guard let destination = DeepLinkRouter.destination(from: url) else { return }
        switch destination {
        case .confirmEmail, .resetPassword:
            Task {
                do {
                    try await AuthRepository().handleAuthDeepLink(url: url)
                    if let session = await AuthRepository().currentSession() {
                        await AuthenticatedSessionCoordinator.bootstrap(session: session, appState: appState)
                        if case .resetPassword = destination,
                           appState.session?.userId == session.userId {
                            appState.passwordRecoveryUserId = session.userId
                        }
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
    private let linkDiagnostics: SessionLinkDiagnostics

    init(linkDiagnostics: SessionLinkDiagnostics = .init()) {
        self.linkDiagnostics = linkDiagnostics
    }

    var session: AppSession? {
        didSet {
            if let previous = oldValue, previous.userId != session?.userId {
                clearAccountContext()
            }
        }
    }
    var preferredColorScheme: ColorScheme?
    var bannerMessage: String?
    var bannerIsError = true
    private var bannerDismissTask: Task<Void, Never>?
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
    /// The session whose chat should open after its detail finishes loading.
    private(set) var sessionDetailOpenChatId: UUID?
    /// True when the signed-in user has not finished first-run onboarding.
    var needsOnboarding = false
    var passwordRecoveryUserId: UUID?
    /// Incremented to request presenting Create session from tabs (e.g. Discover host nudge).
    private(set) var createSessionRequestNonce = 0
    private(set) var discoverRequestNonce = 0
    var pendingCreateSessionPrefill: CreateSessionPrefill?

    private func clearAccountContext() {
        AccountLocalDataCleanup.clear()
        clearBanner()
        needsOnboarding = false
        passwordRecoveryUserId = nil
        sessionDetailDeepLink = nil
        sessionDetailDeepLinkTarget = .discover
        pendingSessionDeepLink = nil
        pendingSessionDeepLinkOpenChat = false
        sessionDetailOpenChatId = nil
        pendingCreateSessionPrefill = nil
        profileRefreshNonce += 1
        sessionFeedRefreshNonce += 1
    }

    var isAuthenticated: Bool {
        session?.isEmailConfirmed == true
    }

    func touchProfileRefresh() {
        profileRefreshNonce += 1
    }

    func touchSessionFeedRefresh() {
        sessionFeedRefreshNonce += 1
    }

    func requestDiscover() {
        discoverRequestNonce += 1
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
    }

    func queueSessionDeepLink(id: UUID, openChat: Bool = false) {
        let attempt = SessionLinkDiagnostics.Attempt()
        sessionDetailOpenChatId = openChat ? id : nil
        if isAuthenticated {
            presentSessionDetail(id: id, on: .discover)
            linkDiagnostics.finish(.queueAssigned, attempt: attempt)
        } else {
            pendingSessionDeepLink = id
            pendingSessionDeepLinkOpenChat = openChat
            linkDiagnostics.finish(.queueDeferred, attempt: attempt)
        }
    }

    func consumePendingSessionDeepLinkIfNeeded() {
        let attempt = SessionLinkDiagnostics.Attempt()
        guard let id = pendingSessionDeepLink else {
            linkDiagnostics.finish(.resumeNoPending, attempt: attempt)
            return
        }
        guard isAuthenticated else {
            linkDiagnostics.finish(.resumeWaitingForAuth, attempt: attempt)
            return
        }
        let openChat = pendingSessionDeepLinkOpenChat
        pendingSessionDeepLink = nil
        pendingSessionDeepLinkOpenChat = false
        queueSessionDeepLink(id: id, openChat: openChat)
        linkDiagnostics.finish(.resumeAssigned, attempt: attempt)
    }

    func consumeSessionDetailOpenChat(for sessionId: UUID) -> Bool {
        guard sessionDetailOpenChatId == sessionId else { return false }
        sessionDetailOpenChatId = nil
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

    func showSuccess(_ message: String, autoDismissAfter seconds: Double = 3) {
        bannerMessage = message
        bannerIsError = false
        scheduleBannerDismiss(after: seconds)
    }

    func clearBanner() {
        bannerDismissTask?.cancel()
        bannerDismissTask = nil
        bannerMessage = nil
    }

    private func scheduleBannerDismiss(after seconds: Double) {
        bannerDismissTask?.cancel()
        bannerDismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            bannerMessage = nil
        }
    }
}

struct AppSession {
    let userId: UUID
    let email: String
    let isEmailConfirmed: Bool
}
