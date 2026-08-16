import Foundation

enum AuthenticatedSessionCoordinator {
    @MainActor
    static func bootstrap(session: AppSession, appState: AppState) async {
        appState.session = session
        guard session.isEmailConfirmed else { return }
        do {
            let repository = ProfileRepository()
            try await repository.ensureProfileForCurrentUser()
            let profile = try await repository.fetchCurrentProfile()
            appState.needsOnboarding = profile.onboardingCompletedAt == nil
        } catch {
            appState.showError(error)
        }
        appState.consumePendingSessionDeepLinkIfNeeded()
        await PushNotificationService.shared.requestAuthorizationAndRegister()
    }
}
