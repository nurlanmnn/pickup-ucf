import XCTest
import Supabase
@testable import PickUpUCF

final class DeviceTokenRepositoryTests: XCTestCase {
    func testRegistrationParamsEncodeRPCKey() throws {
        let params = DeviceTokenParams(apnsToken: "abc123")

        let data = try JSONEncoder().encode(params)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: String])

        XCTAssertEqual(json["p_apns_token"], "abc123")
    }

    func testLiveActivityRegistrationParamsEncodeRPCKeys() throws {
        let sessionId = UUID(uuidString: "B1C2D3E4-F5A6-7890-BCDE-F1234567890A")!
        let params = LiveActivityTokenRegistrationParams(
            sessionId: sessionId,
            apnsToken: "def456"
        )

        let data = try JSONEncoder().encode(params)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: String])

        XCTAssertEqual(json["p_session_id"], sessionId.uuidString)
        XCTAssertEqual(json["p_apns_token"], "def456")
    }

    func testUnregisterFallsBackToOwnerScopedDeleteOnlyWhenRPCIsMissing() async throws {
        let missingRPC = PostgrestError(code: "PGRST202", message: "redacted")
        var deletedTokens: [String] = []
        let repository = DeviceTokenRepository(
            unregisterRPC: { _ in throw missingRPC },
            deleteOwnedToken: { deletedTokens.append($0) }
        )

        try await repository.unregister(token: "safe-token")

        XCTAssertEqual(deletedTokens, ["safe-token"])
    }

    func testUnregisterDoesNotFallbackForOtherServerFailures() async {
        let serverFailure = PostgrestError(code: "PGRST500", message: "redacted")
        var deleteCount = 0
        let repository = DeviceTokenRepository(
            unregisterRPC: { _ in throw serverFailure },
            deleteOwnedToken: { _ in deleteCount += 1 }
        )

        do {
            try await repository.unregister(token: "safe-token")
            XCTFail("Expected unregister to fail")
        } catch {}

        XCTAssertEqual(deleteCount, 0)
    }

    func testUserDefaultsStorePersistsTokenAcrossInstances() throws {
        let suiteName = "DeviceTokenRepositoryTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let token = String(repeating: "ef", count: 32)

        let store = UserDefaultsDeviceTokenStore(defaults: defaults)
        store.token = token
        store.requiresServerRecovery = true

        XCTAssertEqual(UserDefaultsDeviceTokenStore(defaults: defaults).token, token)
        XCTAssertTrue(UserDefaultsDeviceTokenStore(defaults: defaults).requiresServerRecovery)
    }

    @MainActor
    func testDeviceTokenIsPersistedBeforeRegistrationAttempt() async {
        let repository = RecordingDeviceTokenRepository(registerError: TestError.failed)
        let store = InMemoryDeviceTokenStore()
        let service = PushNotificationService(
            tokenRepository: repository,
            tokenStore: store,
            registerForRemoteNotifications: {},
            unregisterForRemoteNotifications: {},
            endLiveActivities: {}
        )

        await service.registerStoredTokenIfAvailable()
        await service.handleDeviceToken(Data(repeating: 0xAB, count: 32))

        let expectedToken = String(repeating: "ab", count: 32)
        XCTAssertEqual(store.token, expectedToken)
        XCTAssertEqual(repository.registeredTokens, [expectedToken])
    }

    @MainActor
    func testStoredTokenCanBeRegisteredForTheNextAccount() async {
        let repository = RecordingDeviceTokenRepository()
        let token = String(repeating: "cd", count: 32)
        let store = InMemoryDeviceTokenStore(token: token)
        let service = PushNotificationService(
            tokenRepository: repository,
            tokenStore: store,
            registerForRemoteNotifications: {},
            unregisterForRemoteNotifications: {},
            endLiveActivities: {}
        )

        await service.registerStoredTokenIfAvailable()
        await service.registerStoredTokenIfAvailable()

        XCTAssertEqual(
            repository.registeredTokens,
            [token, token]
        )
        XCTAssertEqual(store.token, token)
    }

    @MainActor
    func testAccountTransitionUnregistersOwnedTokenAndLocalPushState() async throws {
        let repository = RecordingDeviceTokenRepository()
        let store = InMemoryDeviceTokenStore(token: "owned-token")
        var localUnregisterCount = 0
        var liveActivityEndCount = 0
        let service = PushNotificationService(
            tokenRepository: repository,
            tokenStore: store,
            registerForRemoteNotifications: {},
            unregisterForRemoteNotifications: { localUnregisterCount += 1 },
            endLiveActivities: { liveActivityEndCount += 1 }
        )

        try await service.unregisterForAccountTransition()

        XCTAssertEqual(repository.unregisteredTokens, ["owned-token"])
        XCTAssertNil(store.token)
        XCTAssertFalse(store.requiresServerRecovery)
        XCTAssertEqual(localUnregisterCount, 1)
        XCTAssertEqual(liveActivityEndCount, 1)
    }

    @MainActor
    func testFailedBackendCleanupStillUnregistersLocallyAndRetainsToken() async {
        let repository = RecordingDeviceTokenRepository(unregisterError: TestError.failed)
        let store = InMemoryDeviceTokenStore(token: "retry-token")
        var localUnregisterCount = 0
        var liveActivityEndCount = 0
        let service = PushNotificationService(
            tokenRepository: repository,
            tokenStore: store,
            registerForRemoteNotifications: {},
            unregisterForRemoteNotifications: { localUnregisterCount += 1 },
            endLiveActivities: { liveActivityEndCount += 1 }
        )

        do {
            try await service.unregisterForAccountTransition()
            XCTFail("Expected backend cleanup to fail")
        } catch {}

        XCTAssertEqual(repository.unregisteredTokens, ["retry-token", "retry-token"])
        XCTAssertEqual(store.token, "retry-token")
        XCTAssertTrue(store.requiresServerRecovery)
        XCTAssertEqual(localUnregisterCount, 1)
        XCTAssertEqual(liveActivityEndCount, 1)
    }

    @MainActor
    func testAccountTransitionWithoutStoredTokenStillClearsLocalPushState() async throws {
        let repository = RecordingDeviceTokenRepository()
        var localUnregisterCount = 0
        var liveActivityEndCount = 0
        let service = PushNotificationService(
            tokenRepository: repository,
            tokenStore: InMemoryDeviceTokenStore(),
            registerForRemoteNotifications: {},
            unregisterForRemoteNotifications: { localUnregisterCount += 1 },
            endLiveActivities: { liveActivityEndCount += 1 }
        )

        try await service.unregisterForAccountTransition()

        XCTAssertTrue(repository.unregisteredTokens.isEmpty)
        XCTAssertEqual(localUnregisterCount, 1)
        XCTAssertEqual(liveActivityEndCount, 1)
    }

    @MainActor
    func testAuthorizationRefreshRegistersStoredTokenBeforeRemoteNotifications() async {
        let token = String(repeating: "12", count: 32)
        let repository = RecordingDeviceTokenRepository()
        var localRegisterCount = 0
        let service = PushNotificationService(
            tokenRepository: repository,
            tokenStore: InMemoryDeviceTokenStore(token: token),
            registerForRemoteNotifications: { localRegisterCount += 1 },
            unregisterForRemoteNotifications: {},
            endLiveActivities: {}
        )

        await service.refreshRegistrationAfterAuthorizationChange()

        XCTAssertEqual(repository.registeredTokens, [token])
        XCTAssertEqual(localRegisterCount, 1)
    }

    @MainActor
    func testConfirmedSignOutCleanupPreventsStoredTokenReuseByNextAccount() async throws {
        let tokenData = Data(repeating: 0x34, count: 32)
        let token = String(repeating: "34", count: 32)
        let repository = RecordingDeviceTokenRepository()
        let service = PushNotificationService(
            tokenRepository: repository,
            tokenStore: InMemoryDeviceTokenStore(),
            registerForRemoteNotifications: {},
            unregisterForRemoteNotifications: {},
            endLiveActivities: {}
        )

        await service.registerStoredTokenIfAvailable()
        await service.handleDeviceToken(tokenData)
        try await service.unregisterForAccountTransition()
        await service.registerStoredTokenIfAvailable()

        XCTAssertEqual(
            repository.actions,
            ["register:\(token)", "unregister:\(token)"]
        )
    }

    @MainActor
    func testFailedCleanupQuarantinesPushUntilAtomicRegistrationRecovers() async {
        let token = String(repeating: "34", count: 32)
        let repository = RecordingDeviceTokenRepository(
            registerResults: [.failure(TestError.failed), .success(())],
            unregisterResults: [.failure(TestError.failed), .failure(TestError.failed)]
        )
        let store = InMemoryDeviceTokenStore(token: token)
        var localRegisterCount = 0
        var localUnregisterCount = 0
        let service = PushNotificationService(
            tokenRepository: repository,
            tokenStore: store,
            registerForRemoteNotifications: { localRegisterCount += 1 },
            unregisterForRemoteNotifications: { localUnregisterCount += 1 },
            endLiveActivities: {}
        )

        do {
            try await service.unregisterForAccountTransition()
            XCTFail("Expected backend cleanup to fail")
        } catch {}

        await service.registerStoredTokenIfAvailable()
        await service.requestAuthorizationAndRegister(requestAuthorization: { true })

        XCTAssertTrue(store.requiresServerRecovery)
        XCTAssertEqual(localRegisterCount, 0)
        XCTAssertEqual(localUnregisterCount, 2)

        await service.refreshRegistrationAfterAuthorizationChange()

        XCTAssertFalse(store.requiresServerRecovery)
        XCTAssertEqual(localRegisterCount, 1)
    }

    @MainActor
    func testTokenCallbackAfterSignOutWaitsForNextAuthenticatedSession() async throws {
        let firstToken = String(repeating: "56", count: 32)
        let nextToken = String(repeating: "78", count: 32)
        let repository = RecordingDeviceTokenRepository()
        let service = PushNotificationService(
            tokenRepository: repository,
            tokenStore: InMemoryDeviceTokenStore(),
            registerForRemoteNotifications: {},
            unregisterForRemoteNotifications: {},
            endLiveActivities: {}
        )

        await service.registerStoredTokenIfAvailable()
        await service.handleDeviceToken(Data(repeating: 0x56, count: 32))
        try await service.unregisterForAccountTransition()
        await service.handleDeviceToken(Data(repeating: 0x78, count: 32))
        await service.registerStoredTokenIfAvailable()

        XCTAssertEqual(
            repository.actions,
            [
                "register:\(firstToken)",
                "unregister:\(firstToken)",
                "register:\(nextToken)",
            ]
        )
    }

    @MainActor
    func testTokenRotationUnregistersOldTokenBeforeRegisteringReplacement() async {
        let oldToken = String(repeating: "9a", count: 32)
        let newToken = String(repeating: "bc", count: 32)
        let repository = RecordingDeviceTokenRepository()
        let service = PushNotificationService(
            tokenRepository: repository,
            tokenStore: InMemoryDeviceTokenStore(),
            registerForRemoteNotifications: {},
            unregisterForRemoteNotifications: {},
            endLiveActivities: {}
        )

        await service.registerStoredTokenIfAvailable()
        await service.handleDeviceToken(Data(repeating: 0x9A, count: 32))
        await service.handleDeviceToken(Data(repeating: 0xBC, count: 32))

        XCTAssertEqual(
            repository.actions,
            [
                "register:\(oldToken)",
                "unregister:\(oldToken)",
                "register:\(newToken)",
            ]
        )
    }
}

private enum TestError: Error {
    case failed
}

private final class InMemoryDeviceTokenStore: DeviceTokenStoring {
    var token: String?
    var requiresServerRecovery: Bool

    init(token: String? = nil, requiresServerRecovery: Bool = false) {
        self.token = token
        self.requiresServerRecovery = requiresServerRecovery
    }
}

private final class RecordingDeviceTokenRepository: DeviceTokenRepositoryProtocol {
    private let registerError: Error?
    private let unregisterError: Error?
    private var registerResults: [Result<Void, Error>]
    private var unregisterResults: [Result<Void, Error>]
    private(set) var registeredTokens: [String] = []
    private(set) var unregisteredTokens: [String] = []
    private(set) var actions: [String] = []

    init(
        registerError: Error? = nil,
        unregisterError: Error? = nil,
        registerResults: [Result<Void, Error>] = [],
        unregisterResults: [Result<Void, Error>] = []
    ) {
        self.registerError = registerError
        self.unregisterError = unregisterError
        self.registerResults = registerResults
        self.unregisterResults = unregisterResults
    }

    func register(token: String) async throws {
        registeredTokens.append(token)
        actions.append("register:\(token)")
        if !registerResults.isEmpty {
            try registerResults.removeFirst().get()
            return
        }
        if let registerError { throw registerError }
    }

    func unregister(token: String) async throws {
        unregisteredTokens.append(token)
        actions.append("unregister:\(token)")
        if !unregisterResults.isEmpty {
            try unregisterResults.removeFirst().get()
            return
        }
        if let unregisterError { throw unregisterError }
    }
}

final class AccountTransitionCoordinatorTests: XCTestCase {
    @MainActor
    func testSignOutCleansUpBeforeLogoutAndClearsAppState() async {
        let appState = authenticatedAppState()
        var events: [String] = []

        let outcome = await AccountTransitionCoordinator.signOut(
            appState: appState,
            unregisterToken: { events.append("unregister") },
            signOut: { events.append("signOut") }
        )

        XCTAssertEqual(events, ["unregister", "signOut"])
        XCTAssertNil(appState.session)
        XCTAssertEqual(outcome, .completed)
    }

    @MainActor
    func testSignOutReportsTokenCleanupFailureAndClearsAppState() async {
        let appState = authenticatedAppState()
        var events: [String] = []

        let outcome = await AccountTransitionCoordinator.signOut(
            appState: appState,
            unregisterToken: {
                events.append("unregister")
                throw TestError.failed
            },
            signOut: { events.append("signOut") }
        )

        XCTAssertEqual(events, ["unregister", "signOut"])
        XCTAssertNil(appState.session)
        XCTAssertEqual(outcome, .completedWithWarning([.deviceTokenCleanup]))
    }

    @MainActor
    func testSignOutReportsRemoteFailureAndClearsLocalSession() async {
        let appState = authenticatedAppState()
        var events: [String] = []

        let outcome = await AccountTransitionCoordinator.signOut(
            appState: appState,
            unregisterToken: { events.append("unregister") },
            signOut: {
                events.append("signOut")
                throw TestError.failed
            }
        )

        XCTAssertEqual(events, ["unregister", "signOut"])
        XCTAssertNil(appState.session)
        XCTAssertEqual(outcome, .completedWithWarning([.remoteSignOut]))
    }

    @MainActor
    func testDeletionCleansUpBeforeDeletingAndClearsStateAfterSuccess() async throws {
        let appState = authenticatedAppState()
        var events: [String] = []

        let outcome = try await AccountTransitionCoordinator.deleteAccount(
            appState: appState,
            unregisterToken: { events.append("unregister") },
            deleteAccount: { events.append("delete") },
            signOut: { events.append("signOut") },
            restoreNotifications: { events.append("restore") }
        )

        XCTAssertEqual(events, ["unregister", "delete", "signOut"])
        XCTAssertNil(appState.session)
        XCTAssertEqual(outcome, .completed)
    }

    @MainActor
    func testDeletionFailureKeepsSessionAndRestoresNotifications() async {
        let appState = authenticatedAppState()
        var events: [String] = []

        do {
            _ = try await AccountTransitionCoordinator.deleteAccount(
                appState: appState,
                unregisterToken: { events.append("unregister") },
                deleteAccount: {
                    events.append("delete")
                    throw TestError.failed
                },
                signOut: { events.append("signOut") },
                restoreNotifications: { events.append("restore") }
            )
            XCTFail("Expected deletion to fail")
        } catch {}

        XCTAssertEqual(events, ["unregister", "delete", "restore"])
        XCTAssertNotNil(appState.session)
    }

    @MainActor
    private func authenticatedAppState() -> AppState {
        let appState = AppState()
        appState.session = AppSession(
            userId: UUID(uuidString: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890")!,
            email: "student@ucf.edu",
            isEmailConfirmed: true
        )
        return appState
    }
}
