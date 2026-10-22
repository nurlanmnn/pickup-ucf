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
            guard appState.session?.userId == session.userId else { return }
            appState.needsOnboarding = profile.onboardingCompletedAt == nil
        } catch {
            guard appState.session?.userId == session.userId else { return }
            appState.showError(error)
        }
        guard appState.session?.userId == session.userId else { return }
        appState.consumePendingSessionDeepLinkIfNeeded()
        await PushNotificationService.shared.refreshRegistrationAfterAuthorizationChange()
    }
}
