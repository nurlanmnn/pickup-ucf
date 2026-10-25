import UIKit
import UserNotifications

protocol DeviceTokenStoring: AnyObject {
    var token: String? { get set }
    var requiresServerRecovery: Bool { get set }
}

final class UserDefaultsDeviceTokenStore: DeviceTokenStoring {
    private static let tokenKey = "pushNotifications.lastAPNSToken"
    private static let recoveryKey = "pushNotifications.requiresServerRecovery"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var token: String? {
        get { defaults.string(forKey: Self.tokenKey) }
        set { defaults.set(newValue, forKey: Self.tokenKey) }
    }

    var requiresServerRecovery: Bool {
        get { defaults.bool(forKey: Self.recoveryKey) }
        set { defaults.set(newValue, forKey: Self.recoveryKey) }
    }
}

@MainActor
final class PushNotificationService: NSObject {
    static let shared = PushNotificationService()
    private let tokenRepository: DeviceTokenRepositoryProtocol
    private let diagnostics: DeviceTokenDiagnostics
    private let tokenStore: DeviceTokenStoring
    private let registerForRemoteNotifications: @MainActor () -> Void
    private let unregisterForRemoteNotifications: @MainActor () -> Void
    private let endLiveActivities: @MainActor () async -> Void
    private let authorizationStatus: @MainActor () async -> UNAuthorizationStatus
    private var acceptsTokenRegistration = false
    private var pendingRegistration: Task<Void, Never>?

    init(
        tokenRepository: DeviceTokenRepositoryProtocol = DeviceTokenRepository(),
        tokenStore: DeviceTokenStoring = UserDefaultsDeviceTokenStore(),
        registerForRemoteNotifications: @escaping @MainActor () -> Void = {
            UIApplication.shared.registerForRemoteNotifications()
        },
        unregisterForRemoteNotifications: @escaping @MainActor () -> Void = {
            UIApplication.shared.unregisterForRemoteNotifications()
            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        },
        endLiveActivities: @escaping @MainActor () async -> Void = {
            await GameLiveActivityCoordinator.endAllForAccountTransition()
        },
        diagnostics: DeviceTokenDiagnostics = .init(),
        authorizationStatus: @escaping @MainActor () async -> UNAuthorizationStatus = {
            await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        }
    ) {
        self.diagnostics = diagnostics
        self.tokenRepository = tokenRepository
        self.tokenStore = tokenStore
        self.registerForRemoteNotifications = registerForRemoteNotifications
        self.unregisterForRemoteNotifications = unregisterForRemoteNotifications
        self.endLiveActivities = endLiveActivities
        self.authorizationStatus = authorizationStatus
    }

    func requestAuthorizationAndRegister() async {
        await requestAuthorizationAndRegister {
            try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        }
    }

    func requestAuthorizationAndRegister(
        requestAuthorization: () async throws -> Bool
    ) async {
        do {
            let granted = try await requestAuthorization()
            guard granted, acceptsTokenRegistration else { return }
            registerForRemoteNotifications()
        } catch {
            // Non-fatal; user can enable later in Settings.
        }
    }

    func handleDeviceToken(_ deviceToken: Data) async {
        let attempt = DeviceTokenDiagnostics.Attempt()
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        let previousToken = tokenStore.token
        tokenStore.token = token
        guard acceptsTokenRegistration else {
            diagnostics.finishRegistration(.suppressed, source: .apnsCallback, attempt: attempt)
            return
        }
        await enqueueRegistration {
            do {
                if let previousToken, previousToken != token {
                    try? await self.tokenRepository.unregister(token: previousToken)
                }
                try await self.tokenRepository.register(token: token)
                self.tokenStore.requiresServerRecovery = false
                self.diagnostics.finishRegistration(.returned, source: .apnsCallback, attempt: attempt)
            } catch {
                self.quarantineRegistration()
                self.diagnostics.finishRegistration(.quarantined(error), source: .apnsCallback, attempt: attempt)
            }
        }
    }

    func registerStoredTokenIfAvailable() async {
        let attempt = DeviceTokenDiagnostics.Attempt()
        acceptsTokenRegistration = true
        guard let token = tokenStore.token else {
            diagnostics.finishRegistration(.noStoredToken, source: .storedToken, attempt: attempt)
            return
        }
        await enqueueRegistration {
            do {
                try await self.tokenRepository.register(token: token)
                self.tokenStore.requiresServerRecovery = false
                self.diagnostics.finishRegistration(.returned, source: .storedToken, attempt: attempt)
            } catch {
                self.quarantineRegistration()
                self.diagnostics.finishRegistration(.quarantined(error), source: .storedToken, attempt: attempt)
            }
        }
    }

    func unregisterForAccountTransition() async throws {
        let attempt = DeviceTokenDiagnostics.Attempt()
        acceptsTokenRegistration = false
        let token = tokenStore.token
        await endLiveActivities()
        unregisterForRemoteNotifications()
        await pendingRegistration?.value
        guard let token else {
            tokenStore.requiresServerRecovery = false
            diagnostics.finishCleanup(.noStoredToken, attempt: attempt)
            return
        }

        var returnedAfterRetry = false
        do {
            try await tokenRepository.unregister(token: token)
        } catch {
            do {
                try await tokenRepository.unregister(token: token)
                returnedAfterRetry = true
            } catch {
                tokenStore.requiresServerRecovery = true
                diagnostics.finishCleanup(.recoveryRequired(error), attempt: attempt)
                throw error
            }
        }

        tokenStore.token = nil
        tokenStore.requiresServerRecovery = false
        diagnostics.finishCleanup(returnedAfterRetry ? .returnedAfterRetry : .returnedFirstAttempt, attempt: attempt)
    }

    func prepareForMissingSession() async {
        acceptsTokenRegistration = false
        if tokenStore.token != nil { tokenStore.requiresServerRecovery = true }
        unregisterForRemoteNotifications()
        await endLiveActivities()
    }

    func restoreAfterFailedAccountDeletion() async {
        await refreshRegistrationAfterAuthorizationChange()
    }

    func refreshRegistrationAfterAuthorizationChange() async {
        await registerStoredTokenIfAvailable()
        guard acceptsTokenRegistration else { return }
        let status = await authorizationStatus()
        guard acceptsTokenRegistration, !tokenStore.requiresServerRecovery else { return }
        switch status {
        case .authorized, .provisional, .ephemeral: registerForRemoteNotifications()
        default: unregisterForRemoteNotifications()
        }
    }

    private func enqueueRegistration(_ operation: @escaping () async -> Void) async {
        let previousRegistration = pendingRegistration
        let registration = Task { @MainActor in
            await previousRegistration?.value
            await operation()
        }
        pendingRegistration = registration
        await registration.value
    }

    private func quarantineRegistration() {
        tokenStore.requiresServerRecovery = true
        acceptsTokenRegistration = false
        unregisterForRemoteNotifications()
    }
}
