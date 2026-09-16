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
    private let tokenStore: DeviceTokenStoring
    private let registerForRemoteNotifications: @MainActor () -> Void
    private let unregisterForRemoteNotifications: @MainActor () -> Void
    private let endLiveActivities: @MainActor () async -> Void
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
        },
        endLiveActivities: @escaping @MainActor () async -> Void = {
            await GameLiveActivityCoordinator.endAllForAccountTransition()
        }
    ) {
        self.tokenRepository = tokenRepository
        self.tokenStore = tokenStore
        self.registerForRemoteNotifications = registerForRemoteNotifications
        self.unregisterForRemoteNotifications = unregisterForRemoteNotifications
        self.endLiveActivities = endLiveActivities
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
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        let previousToken = tokenStore.token
        tokenStore.token = token
        guard acceptsTokenRegistration else { return }
        await enqueueRegistration {
            do {
                if let previousToken, previousToken != token {
                    try? await self.tokenRepository.unregister(token: previousToken)
                }
                try await self.tokenRepository.register(token: token)
                self.tokenStore.requiresServerRecovery = false
            } catch {
                self.quarantineRegistration()
            }
        }
    }

    func registerStoredTokenIfAvailable() async {
        acceptsTokenRegistration = true
        guard let token = tokenStore.token else { return }
        await enqueueRegistration {
            do {
                try await self.tokenRepository.register(token: token)
                self.tokenStore.requiresServerRecovery = false
            } catch {
                self.quarantineRegistration()
            }
        }
    }

    func unregisterForAccountTransition() async throws {
        acceptsTokenRegistration = false
        let token = tokenStore.token
        await endLiveActivities()
        unregisterForRemoteNotifications()
        await pendingRegistration?.value
        guard let token else {
            tokenStore.requiresServerRecovery = false
            return
        }

        do {
            try await tokenRepository.unregister(token: token)
        } catch {
            do {
                try await tokenRepository.unregister(token: token)
            } catch {
                tokenStore.requiresServerRecovery = true
                throw error
            }
        }

        tokenStore.token = nil
        tokenStore.requiresServerRecovery = false
    }

    func restoreAfterFailedAccountDeletion() async {
        await refreshRegistrationAfterAuthorizationChange()
    }

    func refreshRegistrationAfterAuthorizationChange() async {
        await registerStoredTokenIfAvailable()
        guard acceptsTokenRegistration else { return }
        registerForRemoteNotifications()
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
