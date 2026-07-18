import Foundation

enum AuthenticatedSessionCoordinator {
    @MainActor
    static func bootstrap(session: AppSession, appState: AppState) async {
        appState.session = session
        guard session.isEmailConfirmed else { return }
        do {
            try await ProfileRepository().ensureProfileForCurrentUser()
        } catch {
            appState.showError(error)
        }
        appState.consumePendingSessionDeepLinkIfNeeded()
        await PushNotificationService.shared.requestAuthorizationAndRegister()
    }
}
