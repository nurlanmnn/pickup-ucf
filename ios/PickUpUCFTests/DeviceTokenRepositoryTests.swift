import XCTest
import UserNotifications
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
    func testMissingSessionClearsLocalNotificationsAndKeepsTokenQuarantinedForNextOwner() async {
        let token = String(repeating: "ab", count: 32)
        let store = InMemoryDeviceTokenStore(token: token)
        var unregisterCount = 0
        var activityEndCount = 0
        let repository = RecordingDeviceTokenRepository()
        let service = PushNotificationService(tokenRepository: repository, tokenStore: store,
            registerForRemoteNotifications: {}, unregisterForRemoteNotifications: { unregisterCount += 1 },
            endLiveActivities: { activityEndCount += 1 })
        await service.prepareForMissingSession()
        XCTAssertEqual(unregisterCount, 1)
        XCTAssertEqual(activityEndCount, 1)
        XCTAssertEqual(store.token, token)
        XCTAssertTrue(store.requiresServerRecovery)
        XCTAssertTrue(repository.registeredTokens.isEmpty)
    }

    @MainActor
    func testAuthorizationRefreshDoesNotRegisterRemoteNotificationsWithoutPermission() async {
        for status: UNAuthorizationStatus in [.notDetermined, .denied] {
            var registerCount = 0
            var unregisterCount = 0
            let service = PushNotificationService(
                tokenRepository: RecordingDeviceTokenRepository(),
                tokenStore: InMemoryDeviceTokenStore(),
                registerForRemoteNotifications: { registerCount += 1 },
                unregisterForRemoteNotifications: { unregisterCount += 1 },
                endLiveActivities: {}, authorizationStatus: { status }
            )
            await service.refreshRegistrationAfterAuthorizationChange()
            XCTAssertEqual(registerCount, 0)
            XCTAssertEqual(unregisterCount, 1)
        }
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
            endLiveActivities: {},
            authorizationStatus: { .authorized }
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
            endLiveActivities: {},
            authorizationStatus: { .authorized }
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
    private let registerHook: (() async -> Void)?
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
        unregisterResults: [Result<Void, Error>] = [],
        registerHook: (() async -> Void)? = nil
    ) {
        self.registerHook = registerHook
        self.registerError = registerError
        self.unregisterError = unregisterError
        self.registerResults = registerResults
        self.unregisterResults = unregisterResults
    }

    func register(token: String) async throws {
        registeredTokens.append(token)
        actions.append("register:\(token)")
        await registerHook?()
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
    func testSuccessfulSignOutClearsAccountNavigationAndDraftsDespiteRemoteFailure() async {
        let appState = authenticatedAppState()
        let sessionId = UUID()
        appState.queueSessionDeepLink(id: sessionId, openChat: true)
        appState.requestCreateSession(prefill: CreateSessionPrefill(sport: .basketball))
        appState.showError("Previous account banner")
        appState.needsOnboarding = true
        _ = await AccountTransitionCoordinator.signOut(appState: appState, unregisterToken: {}, signOut: { throw TestError.failed })
        XCTAssertNil(appState.sessionDetailDeepLink)
        XCTAssertNil(appState.pendingCreateSessionPrefill)
        XCTAssertNil(appState.bannerMessage)
        XCTAssertFalse(appState.needsOnboarding)
        XCTAssertFalse(appState.consumeSessionDetailOpenChat(for: sessionId))
    }

    func testAccountLocalCleanupPreservesQuarantineAndUnrelatedSettings() throws {
        let name = "pickup.cleanup.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        for key in ["calendar_export_event_id_example", "createSession.lastSport", "createSession.lastVenueId", "discoverSportFilterMode"] {
            defaults.set("synthetic", forKey: key)
        }
        defaults.set(true, forKey: "pushNotifications.requiresServerRecovery")
        defaults.set("synthetic-token", forKey: "pushNotifications.lastAPNSToken")
        defaults.set(true, forKey: "welcomeIntroCompleted")
        AccountLocalDataCleanup.clear(defaults: defaults)
        XCTAssertNil(defaults.string(forKey: "calendar_export_event_id_example"))
        XCTAssertNil(defaults.string(forKey: "createSession.lastVenueId"))
        XCTAssertTrue(defaults.bool(forKey: "pushNotifications.requiresServerRecovery"))
        XCTAssertEqual(defaults.string(forKey: "pushNotifications.lastAPNSToken"), "synthetic-token")
        XCTAssertTrue(defaults.bool(forKey: "welcomeIntroCompleted"))
        AccountLocalDataCleanup.clear(defaults: defaults)
    }

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

final class DeviceTokenDiagnosticsTests: XCTestCase {
    private var records: [DeviceTokenDiagnostics.Record] = []
    private var requests: [URLRequest] = []
    private let userID = UUID()
    private let token = "private-apns-token"

    override func tearDown() {
        DeviceDiagnosticRequest.respond = nil
        super.tearDown()
    }

    func testRealRegisterAndUnregisterRPCPreservePayloadAndFreshAttempts() async throws {
        let (repo, _) = makeClient { _ in (204, Data()) }
        try await repo.register(token: token)
        try await repo.unregister(token: token)
        XCTAssertEqual(requests.map { $0.url!.path }, ["/rest/v1/rpc/register_device_token", "/rest/v1/rpc/unregister_device_token"])
        for request in requests {
            XCTAssertEqual(request.httpMethod, "POST")
            let payload = try body(request)
            XCTAssertEqual(Set(payload.keys), Set(["p_apns_token"]))
            XCTAssertEqual(payload["p_apns_token"] as? String, token)
        }
        XCTAssertEqual(records.map(\.operation), [.registerRPC, .unregisterRPC])
        XCTAssertEqual(records.map(\.result), [.succeeded, .succeeded])
        XCTAssertEqual(Set(records.map(\.attemptID)).count, 2)
        try assertPrivate()
    }

    func testMissingRPCUsesExactOwnerAndTokenDeleteWithSharedAttempt() async throws {
        let (repo, client) = makeClient { request in
            if request.url!.path.hasSuffix("/token") { return (200, try self.authSession()) }
            if request.httpMethod == "DELETE" { return (204, Data()) }
            return self.failure("PGRST202", status: 404)
        }
        _ = try await client.auth.signIn(email: "private@ucf.edu", password: "private-password")
        requests.removeAll()
        try await repo.unregister(token: token)
        XCTAssertEqual(requests.map(\.httpMethod), ["POST", "DELETE"])
        let deletion = requests[1]
        XCTAssertEqual(deletion.url!.path, "/rest/v1/device_tokens")
        XCTAssertEqual(query(deletion, "user_id"), "eq.\(userID.uuidString)")
        XCTAssertEqual(query(deletion, "apns_token"), "eq.\(token)")
        XCTAssertEqual(Set(URLComponents(url: deletion.url!, resolvingAgainstBaseURL: false)!.queryItems!.map(\.name)), Set(["user_id", "apns_token"]))
        XCTAssertEqual(records.map(\.operation), [.unregisterRPC, .deleteOwnedToken])
        XCTAssertEqual(records.map(\.result), [.failed, .succeeded])
        XCTAssertEqual(records.map(\.failure), [.backend, .none])
        XCTAssertEqual(Set(records.map(\.attemptID)).count, 1)
        try assertPrivate()
    }

    func testMissingUserFailsClosedWithoutDelete() async throws {
        let (repo, _) = makeClient { _ in self.failure("PGRST202", status: 404) }
        do { try await repo.unregister(token: token); XCTFail("Expected missing user") }
        catch { XCTAssertFalse(error is PostgrestError) }
        XCTAssertEqual(requests.map(\.httpMethod), ["POST"])
        XCTAssertEqual(records.map(\.operation), [.unregisterRPC, .deleteOwnedToken])
        XCTAssertEqual(records.map(\.result), [.failed, .failed])
        XCTAssertEqual(records.map(\.failure), [.backend, .localPolicy])
        try assertPrivate()
    }

    func testNonMissingRPCErrorNeverDeletesAndRetainsOriginalError() async throws {
        let (repo, _) = makeClient { _ in self.failure("42501") }
        for _ in 0..<2 {
            do { try await repo.unregister(token: token); XCTFail() }
            catch let error as PostgrestError { XCTAssertEqual(error.code, "42501"); XCTAssertEqual(error.message, "private-server-message") }
        }
        XCTAssertEqual(requests.map(\.httpMethod), ["POST", "POST"])
        XCTAssertEqual(records.map(\.operation), [.unregisterRPC, .unregisterRPC])
        XCTAssertEqual(records.map(\.result), [.failed, .failed])
        XCTAssertEqual(Set(records.map(\.attemptID)).count, 2)
        try assertPrivate()
    }

    func testFallbackFailureRethrowsDeleteError() async throws {
        let (repo, client) = makeClient { request in
            if request.url!.path.hasSuffix("/token") { return (200, try self.authSession()) }
            return self.failure(request.httpMethod == "DELETE" ? "42501" : "PGRST202", status: 404)
        }
        _ = try await client.auth.signIn(email: "private@ucf.edu", password: "private-password")
        requests.removeAll()
        do { try await repo.unregister(token: token); XCTFail() }
        catch let error as PostgrestError { XCTAssertEqual(error.code, "42501") }
        XCTAssertEqual(requests.map(\.httpMethod), ["POST", "DELETE"])
        XCTAssertEqual(records.map(\.operation), [.unregisterRPC, .deleteOwnedToken])
        XCTAssertEqual(records.map(\.result), [.failed, .failed])
        XCTAssertEqual(records.map(\.failure), [.backend, .backend])
        XCTAssertEqual(Set(records.map(\.attemptID)).count, 1)
        try assertPrivate()
    }

    func testRegisterTransportAndCancellationPreserveErrors() async throws {
        for code in [URLError.notConnectedToInternet, .cancelled] {
            records.removeAll(); requests.removeAll()
            let (repo, _) = makeClient { _ in throw URLError(code, userInfo: [NSLocalizedDescriptionKey: "private-error"]) }
            do { try await repo.register(token: token); XCTFail() }
            catch let error as URLError { XCTAssertEqual(error.code, code) }
            XCTAssertEqual(requests.map(\.httpMethod), ["POST"])
            XCTAssertEqual(records.map(\.operation), [.registerRPC])
            XCTAssertEqual(records.map(\.result), [code == .cancelled ? .cancelled : .failed])
            XCTAssertEqual(records.map(\.failure), [code == .cancelled ? .cancelled : .transport])
            try assertPrivate()
        }
    }

    @MainActor
    func testRotationContinuesAfterIgnoredCleanupFailureAtActualRepository() async throws {
        let (repo, _) = makeClient { request in
            if request.url!.path.hasSuffix("/unregister_device_token") { return self.failure("42501") }
            return (204, Data())
        }
        let store = InMemoryDeviceTokenStore(token: token)
        let service = PushNotificationService(tokenRepository: repo, tokenStore: store,
            registerForRemoteNotifications: {}, unregisterForRemoteNotifications: {}, endLiveActivities: {})
        await service.registerStoredTokenIfAvailable()
        await service.handleDeviceToken(Data([0xab]))
        XCTAssertEqual(requests.map { $0.url!.lastPathComponent }, ["register_device_token", "unregister_device_token", "register_device_token"])
        XCTAssertEqual(records.map(\.operation), [.registerRPC, .unregisterRPC, .registerRPC])
        XCTAssertEqual(records.map(\.result), [.succeeded, .failed, .succeeded])
        XCTAssertEqual(store.token, "ab")
        XCTAssertFalse(store.requiresServerRecovery)
        try assertPrivate()
    }

    @MainActor
    func testAccountTransitionRetriesActualRepositoryAndRetainsQuarantineOnFailure() async throws {
        let (repo, _) = makeClient { _ in self.failure("42501") }
        let store = InMemoryDeviceTokenStore(token: token)
        var events: [String] = []
        let service = PushNotificationService(tokenRepository: repo, tokenStore: store,
            registerForRemoteNotifications: {}, unregisterForRemoteNotifications: { events.append("local") },
            endLiveActivities: { events.append("activity") })
        do { try await service.unregisterForAccountTransition(); XCTFail() }
        catch let error as PostgrestError { XCTAssertEqual(error.code, "42501") }
        XCTAssertEqual(events, ["activity", "local"])
        XCTAssertEqual(requests.map { $0.url!.lastPathComponent }, ["unregister_device_token", "unregister_device_token"])
        XCTAssertEqual(records.map(\.result), [.failed, .failed])
        XCTAssertEqual(Set(records.map(\.attemptID)).count, 2)
        XCTAssertEqual(store.token, token)
        XCTAssertTrue(store.requiresServerRecovery)
        try assertPrivate()
    }

    @MainActor
    func testBackendRegistrationFailureQuarantinesAndPreservesToken() async throws {
        let (repo, _) = makeClient { _ in self.failure("42501") }
        let store = InMemoryDeviceTokenStore(token: token)
        var localUnregisterCount = 0
        let service = PushNotificationService(tokenRepository: repo, tokenStore: store,
            registerForRemoteNotifications: {}, unregisterForRemoteNotifications: { localUnregisterCount += 1 },
            endLiveActivities: {})
        await service.registerStoredTokenIfAvailable()
        XCTAssertEqual(records.map(\.operation), [.registerRPC])
        XCTAssertEqual(records.map(\.result), [.failed])
        XCTAssertEqual(records.map(\.failure), [.backend])
        XCTAssertEqual(store.token, token)
        XCTAssertTrue(store.requiresServerRecovery)
        XCTAssertEqual(localUnregisterCount, 1)
        // A later APNs callback is persisted, but quarantine still prevents upload.
        await service.handleDeviceToken(Data([0xab]))
        XCTAssertEqual(store.token, "ab")
        XCTAssertEqual(requests.count, 1)
        try assertPrivate()
    }

    @MainActor
    func testAccountTransitionSecondAttemptSuccessClearsRetainedState() async throws {
        var attempts = 0
        let (repo, _) = makeClient { _ in
            attempts += 1
            return attempts == 1 ? self.failure("42501") : (204, Data())
        }
        let store = InMemoryDeviceTokenStore(token: token, requiresServerRecovery: true)
        let service = PushNotificationService(tokenRepository: repo, tokenStore: store,
            registerForRemoteNotifications: {}, unregisterForRemoteNotifications: {}, endLiveActivities: {})
        try await service.unregisterForAccountTransition()
        XCTAssertEqual(requests.map { $0.url!.lastPathComponent }, ["unregister_device_token", "unregister_device_token"])
        XCTAssertEqual(records.map(\.operation), [.unregisterRPC, .unregisterRPC])
        XCTAssertEqual(records.map(\.result), [.failed, .succeeded])
        XCTAssertEqual(Set(records.map(\.attemptID)).count, 2)
        XCTAssertNil(store.token)
        XCTAssertFalse(store.requiresServerRecovery)
        try assertPrivate()
    }

    @MainActor
    func testCleanupDecisionReportsFirstReturnThenNoStoredTokenWithFreshIDs() async throws {
        let (repo, _) = makeClient { _ in (204, Data()) }
        let store = InMemoryDeviceTokenStore(token: token, requiresServerRecovery: true)
        var cleanup: [DeviceTokenDiagnostics.Record] = []
        var events: [String] = []
        let service = PushNotificationService(tokenRepository: repo, tokenStore: store,
            registerForRemoteNotifications: {}, unregisterForRemoteNotifications: { events.append("local") },
            endLiveActivities: { events.append("activity") }, diagnostics: .init {
                guard $0.operation == .accountTransitionCleanup else { return }
                XCTAssertNil(store.token)
                XCTAssertFalse(store.requiresServerRecovery)
                events.append("diagnostic")
                cleanup.append($0)
            })
        try await service.unregisterForAccountTransition()
        try await service.unregisterForAccountTransition()
        XCTAssertEqual(events, ["activity", "local", "diagnostic", "activity", "local", "diagnostic"])
        XCTAssertEqual(requests.map { $0.url!.lastPathComponent }, ["unregister_device_token"])
        XCTAssertEqual(cleanup.map(\.result), [.returnedFirstAttempt, .noStoredToken])
        XCTAssertEqual(cleanup.map(\.failure), [.none, .none])
        XCTAssertEqual(Set(cleanup.map(\.attemptID)).count, 2)
        XCTAssertTrue(Set(cleanup.map(\.attemptID)).isDisjoint(with: records.map(\.attemptID)))
        try assertCleanupPrivate(cleanup)
    }

    @MainActor
    func testCleanupDecisionReportsRetryReturnAfterStateCleared() async throws {
        var attempts = 0
        let (repo, _) = makeClient { _ in
            attempts += 1
            return attempts == 1 ? self.failure("42501") : (204, Data())
        }
        let store = InMemoryDeviceTokenStore(token: token, requiresServerRecovery: true)
        var cleanup: [DeviceTokenDiagnostics.Record] = []
        let service = PushNotificationService(tokenRepository: repo, tokenStore: store,
            registerForRemoteNotifications: {}, unregisterForRemoteNotifications: {}, endLiveActivities: {},
            diagnostics: .init {
                guard $0.operation == .accountTransitionCleanup else { return }
                XCTAssertNil(store.token)
                XCTAssertFalse(store.requiresServerRecovery)
                cleanup.append($0)
            })
        try await service.unregisterForAccountTransition()
        XCTAssertEqual(requests.map { $0.url!.lastPathComponent }, ["unregister_device_token", "unregister_device_token"])
        XCTAssertEqual(records.map(\.result), [.failed, .succeeded])
        XCTAssertEqual(cleanup.map(\.result), [.returnedAfterRetry])
        XCTAssertEqual(cleanup.map(\.failure), [.none])
        try assertCleanupPrivate(cleanup)
    }

    @MainActor
    func testCleanupDecisionReportsRecoveryAndPreservesSecondSDKError() async throws {
        var attempts = 0
        let (repo, _) = makeClient { _ in
            attempts += 1
            return self.failure(attempts == 1 ? "42501" : "23503")
        }
        let store = InMemoryDeviceTokenStore(token: token)
        var cleanup: [DeviceTokenDiagnostics.Record] = []
        let service = PushNotificationService(tokenRepository: repo, tokenStore: store,
            registerForRemoteNotifications: {}, unregisterForRemoteNotifications: {}, endLiveActivities: {},
            diagnostics: .init {
                guard $0.operation == .accountTransitionCleanup else { return }
                XCTAssertEqual(store.token, self.token)
                XCTAssertTrue(store.requiresServerRecovery)
                cleanup.append($0)
            })
        do { try await service.unregisterForAccountTransition(); XCTFail() }
        catch let error as PostgrestError { XCTAssertEqual(error.code, "23503"); XCTAssertEqual(error.message, "private-server-message") }
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(cleanup.map(\.result), [.recoveryRequired])
        XCTAssertEqual(cleanup.map(\.failure), [.backend])
        await service.handleDeviceToken(Data([0xab]))
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(store.token, "ab")
        try assertCleanupPrivate(cleanup)
    }

    @MainActor
    func testCleanupDecisionRetainsRetryPolicyAndCancellationErrorIdentity() async throws {
        let first = NSError(domain: "private-first", code: 17)
        let second = NSError(domain: NSURLErrorDomain, code: URLError.cancelled.rawValue,
                             userInfo: [NSLocalizedDescriptionKey: "private-second"])
        let repo = RecordingDeviceTokenRepository(unregisterResults: [.failure(first), .failure(second)])
        let store = InMemoryDeviceTokenStore(token: token)
        var cleanup: [DeviceTokenDiagnostics.Record] = []
        let service = PushNotificationService(tokenRepository: repo, tokenStore: store,
            registerForRemoteNotifications: {}, unregisterForRemoteNotifications: {}, endLiveActivities: {},
            diagnostics: .init { if $0.operation == .accountTransitionCleanup { cleanup.append($0) } })
        do { try await service.unregisterForAccountTransition(); XCTFail() }
        catch { XCTAssertTrue(error as NSError === second) }
        XCTAssertEqual(repo.unregisteredTokens, [token, token])
        XCTAssertEqual(store.token, token)
        XCTAssertTrue(store.requiresServerRecovery)
        XCTAssertEqual(cleanup.map(\.result), [.recoveryRequired])
        XCTAssertEqual(cleanup.map(\.failure), [.cancelled])
        try assertCleanupPrivate(cleanup)
    }

    @MainActor
    func testCleanupWaitsForPendingRegistrationAndKeepsCapturedToken() async throws {
        let gate = DeviceRegistrationGate()
        let activityGate = DeviceRegistrationGate()
        let repo = RecordingDeviceTokenRepository(registerHook: { await gate.wait() })
        let store = InMemoryDeviceTokenStore(token: token)
        let localCleanup = expectation(description: "local cleanup before queued wait")
        var cleanup: [DeviceTokenDiagnostics.Record] = []
        var events: [String] = []
        let service = PushNotificationService(tokenRepository: repo, tokenStore: store,
            registerForRemoteNotifications: {}, unregisterForRemoteNotifications: {
                events.append("local"); localCleanup.fulfill()
            }, endLiveActivities: { events.append("activity"); await activityGate.wait() },
            diagnostics: .init { if $0.operation == .accountTransitionCleanup { events.append("diagnostic"); cleanup.append($0) } })
        let registration = Task { await service.registerStoredTokenIfAvailable() }
        await gate.waitUntilStarted()
        let transition = Task { try await service.unregisterForAccountTransition() }
        await activityGate.waitUntilStarted()
        let activityStart = ProcessInfo.processInfo.systemUptime
        try await Task.sleep(nanoseconds: 30_000_000)
        let activityHeld = ProcessInfo.processInfo.systemUptime - activityStart
        XCTAssertEqual(events, ["activity"])
        XCTAssertTrue(cleanup.isEmpty)
        await activityGate.release()
        await fulfillment(of: [localCleanup], timeout: 2)
        XCTAssertEqual(events, ["activity", "local"])
        XCTAssertTrue(repo.unregisteredTokens.isEmpty)
        XCTAssertTrue(cleanup.isEmpty)
        // A post-transition callback persists a replacement but cannot upload it.
        await service.handleDeviceToken(Data([0xab]))
        XCTAssertEqual(store.token, "ab")
        XCTAssertEqual(repo.registeredTokens, [token])
        let registrationStart = ProcessInfo.processInfo.systemUptime
        try await Task.sleep(nanoseconds: 30_000_000)
        let registrationHeld = ProcessInfo.processInfo.systemUptime - registrationStart
        await gate.release()
        await registration.value
        try await transition.value
        XCTAssertEqual(repo.actions, ["register:\(token)", "unregister:\(token)"])
        XCTAssertEqual(events, ["activity", "local", "diagnostic"])
        XCTAssertNil(store.token)
        XCTAssertFalse(store.requiresServerRecovery)
        XCTAssertEqual(cleanup.map(\.result), [.returnedFirstAttempt])
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(cleanup.first).durationMS,
                                    Int((activityHeld + registrationHeld) * 1000) - 2)
        try assertCleanupPrivate(cleanup)
    }

    @MainActor
    func testCleanupRetriesFirstAttemptCancellationAndReturnsAfterRetry() async throws {
        let repo = RecordingDeviceTokenRepository(unregisterResults: [.failure(CancellationError()), .success(())])
        let store = InMemoryDeviceTokenStore(token: token, requiresServerRecovery: true)
        var cleanup: [DeviceTokenDiagnostics.Record] = []
        let service = PushNotificationService(tokenRepository: repo, tokenStore: store,
            registerForRemoteNotifications: {}, unregisterForRemoteNotifications: {}, endLiveActivities: {},
            diagnostics: .init { if $0.operation == .accountTransitionCleanup { cleanup.append($0) } })
        try await service.unregisterForAccountTransition()
        XCTAssertEqual(repo.unregisteredTokens, [token, token])
        XCTAssertNil(store.token)
        XCTAssertFalse(store.requiresServerRecovery)
        XCTAssertEqual(cleanup.map(\.result), [.returnedAfterRetry])
        XCTAssertEqual(cleanup.map(\.failure), [.none])
        try assertCleanupPrivate(cleanup)
    }

    @MainActor
    func testCleanupDefaultLoggerSmokeAtActualServiceBoundary() async throws {
        for outcome in 0..<3 {
            var calls = 0
            let (repo, _) = makeClient { _ in
                calls += 1
                return outcome == 0 || (outcome == 1 && calls > 1) ? (204, Data()) : self.failure("42501")
            }
            let service = PushNotificationService(tokenRepository: repo, tokenStore: InMemoryDeviceTokenStore(token: token),
                registerForRemoteNotifications: {}, unregisterForRemoteNotifications: {}, endLiveActivities: {})
            do { try await service.unregisterForAccountTransition(); XCTAssertNotEqual(outcome, 2) }
            catch { XCTAssertEqual(outcome, 2) }
            if outcome == 0 { try await service.unregisterForAccountTransition() }
        }
    }

    @MainActor
    func testRegistrationDecisionsPersistSuppressedCallbackAndEnableStoredToken() async throws {
        let (repo, _) = makeClient { _ in (204, Data()) }
        let store = InMemoryDeviceTokenStore(requiresServerRecovery: true)
        var decisions: [DeviceTokenDiagnostics.Record] = []
        let service = PushNotificationService(tokenRepository: repo, tokenStore: store,
            registerForRemoteNotifications: {}, unregisterForRemoteNotifications: {}, endLiveActivities: {},
            diagnostics: .init { decisions.append($0) })
        await service.handleDeviceToken(Data([0xab]))
        XCTAssertEqual(store.token, "ab")
        XCTAssertTrue(store.requiresServerRecovery)
        XCTAssertTrue(requests.isEmpty)
        await service.registerStoredTokenIfAvailable()
        XCTAssertFalse(store.requiresServerRecovery)
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(try body(requests[0])["p_apns_token"] as? String, "ab")
        XCTAssertEqual(decisions.map { $0.operation.rawValue }, ["apns_callback_registration", "stored_token_registration"])
        XCTAssertEqual(decisions.map { $0.result.rawValue }, ["registration_suppressed", "registration_returned"])
        XCTAssertEqual(decisions.map(\.failure), [.none, .none])
        XCTAssertEqual(Set(decisions.map(\.attemptID)).count, 2)
        XCTAssertTrue(Set(decisions.map(\.attemptID)).isDisjoint(with: records.map(\.attemptID)))
        try assertRegistrationPrivate(decisions)
    }

    @MainActor
    func testRegistrationDecisionNoTokenLeavesRecoveryAndEnablesNextCallback() async throws {
        let (repo, _) = makeClient { _ in (204, Data()) }
        let store = InMemoryDeviceTokenStore(requiresServerRecovery: true)
        var decisions: [DeviceTokenDiagnostics.Record] = []
        let service = PushNotificationService(tokenRepository: repo, tokenStore: store,
            registerForRemoteNotifications: {}, unregisterForRemoteNotifications: {}, endLiveActivities: {},
            diagnostics: .init {
                if $0.result.rawValue == "no_stored_token" { XCTAssertTrue(store.requiresServerRecovery) }
                else { XCTAssertFalse(store.requiresServerRecovery) }
                decisions.append($0)
            })
        await service.registerStoredTokenIfAvailable()
        XCTAssertTrue(requests.isEmpty)
        XCTAssertNil(store.token)
        XCTAssertTrue(store.requiresServerRecovery)
        await service.handleDeviceToken(Data([0xab]))
        XCTAssertEqual(store.token, "ab")
        XCTAssertFalse(store.requiresServerRecovery)
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(decisions.map { $0.operation.rawValue }, ["stored_token_registration", "apns_callback_registration"])
        XCTAssertEqual(decisions.map { $0.result.rawValue }, ["no_stored_token", "registration_returned"])
        try assertRegistrationPrivate(decisions)
    }

    @MainActor
    func testRegistrationDecisionRotationIgnoresCleanupFailureAndEmitsAfterRecoveryCleared() async throws {
        let (repo, _) = makeClient { request in
            request.url!.path.hasSuffix("/unregister_device_token") ? self.failure("42501") : (204, Data())
        }
        let store = InMemoryDeviceTokenStore(token: token, requiresServerRecovery: true)
        var decisions: [DeviceTokenDiagnostics.Record] = []
        let service = PushNotificationService(tokenRepository: repo, tokenStore: store,
            registerForRemoteNotifications: {}, unregisterForRemoteNotifications: { XCTFail("No quarantine") },
            endLiveActivities: {}, diagnostics: .init {
                XCTAssertFalse(store.requiresServerRecovery)
                decisions.append($0)
            })
        await service.registerStoredTokenIfAvailable()
        store.requiresServerRecovery = true
        await service.handleDeviceToken(Data([0xab]))
        XCTAssertEqual(requests.map { $0.url!.lastPathComponent }, ["register_device_token", "unregister_device_token", "register_device_token"])
        XCTAssertEqual(try body(requests[1])["p_apns_token"] as? String, token)
        XCTAssertEqual(try body(requests[2])["p_apns_token"] as? String, "ab")
        XCTAssertEqual(store.token, "ab")
        XCTAssertEqual(records.map(\.result), [.succeeded, .failed, .succeeded])
        XCTAssertEqual(decisions.map { $0.result.rawValue }, ["registration_returned", "registration_returned"])
        XCTAssertEqual(decisions.map(\.failure), [.none, .none])
        try assertRegistrationPrivate(decisions)
    }

    @MainActor
    func testRegistrationDecisionFailureEmitsAfterLocalQuarantineAndSuppressesNextCallback() async throws {
        let (repo, _) = makeClient { _ in self.failure("42501") }
        let store = InMemoryDeviceTokenStore(token: token)
        var decisions: [DeviceTokenDiagnostics.Record] = []
        var events: [String] = []
        let service = PushNotificationService(tokenRepository: repo, tokenStore: store,
            registerForRemoteNotifications: {}, unregisterForRemoteNotifications: {
                XCTAssertTrue(store.requiresServerRecovery)
                events.append("local")
            }, endLiveActivities: {}, diagnostics: .init {
                XCTAssertTrue(store.requiresServerRecovery)
                events.append("diagnostic")
                decisions.append($0)
            })
        await service.registerStoredTokenIfAvailable()
        XCTAssertEqual(store.token, token)
        await service.handleDeviceToken(Data([0xab]))
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(store.token, "ab")
        XCTAssertEqual(events, ["local", "diagnostic", "diagnostic"])
        XCTAssertEqual(decisions.map { $0.result.rawValue }, ["registration_quarantined", "registration_suppressed"])
        XCTAssertEqual(decisions.map(\.failure), [.backend, .none])
        try assertRegistrationPrivate(decisions)
    }

    @MainActor
    func testRegistrationDecisionCallbackCancellationStillQuarantines() async throws {
        let repo = RecordingDeviceTokenRepository(registerError: CancellationError())
        let store = InMemoryDeviceTokenStore()
        var decisions: [DeviceTokenDiagnostics.Record] = []
        var localCount = 0
        let service = PushNotificationService(tokenRepository: repo, tokenStore: store,
            registerForRemoteNotifications: {}, unregisterForRemoteNotifications: { localCount += 1 },
            endLiveActivities: {}, diagnostics: .init { decisions.append($0) })
        await service.registerStoredTokenIfAvailable()
        await service.handleDeviceToken(Data([0xab]))
        XCTAssertEqual(repo.registeredTokens, ["ab"])
        XCTAssertEqual(localCount, 1)
        XCTAssertTrue(store.requiresServerRecovery)
        XCTAssertEqual(decisions.map { $0.result.rawValue }, ["no_stored_token", "registration_quarantined"])
        XCTAssertEqual(decisions.map(\.failure), [.none, .cancelled])
        try assertRegistrationPrivate(decisions)
    }

    @MainActor
    func testRegistrationQueueRetainsCapturedTokenAndDoesNotRecheckGuardAfterEarlierQuarantine() async throws {
        let gate = DeviceRegistrationGate()
        var calls = 0
        let repo = RecordingDeviceTokenRepository(unregisterError: TestError.failed,
            registerResults: [.failure(URLError(.notConnectedToInternet)), .success(())],
            registerHook: { calls += 1; if calls == 1 { await gate.wait() } })
        let store = InMemoryDeviceTokenStore(token: token)
        var decisions: [DeviceTokenDiagnostics.Record] = []
        var events: [String] = []
        let service = PushNotificationService(tokenRepository: repo, tokenStore: store,
            registerForRemoteNotifications: {}, unregisterForRemoteNotifications: { events.append("local") },
            endLiveActivities: {}, diagnostics: .init {
                if $0.result.rawValue == "registration_quarantined" { XCTAssertTrue(store.requiresServerRecovery) }
                if $0.result.rawValue == "registration_returned" { XCTAssertFalse(store.requiresServerRecovery) }
                decisions.append($0)
            })
        let first = Task { await service.registerStoredTokenIfAvailable() }
        await gate.waitUntilStarted()
        let callback = Task { await service.handleDeviceToken(Data([0xab])) }
        // Yield until the callback has persisted its captured token and entered the queue.
        for _ in 0..<100 where store.token != "ab" { await Task.yield() }
        XCTAssertEqual(store.token, "ab")
        XCTAssertTrue(decisions.isEmpty)
        XCTAssertEqual(repo.registeredTokens, [token])
        let queuedStart = ProcessInfo.processInfo.systemUptime
        try await Task.sleep(nanoseconds: 40_000_000)
        let heldMS = Int((ProcessInfo.processInfo.systemUptime - queuedStart) * 1000)
        XCTAssertTrue(decisions.isEmpty)
        await gate.release()
        await first.value
        await callback.value
        XCTAssertEqual(repo.actions, ["register:\(token)", "unregister:\(token)", "register:ab"])
        XCTAssertEqual(events, ["local"])
        XCTAssertEqual(decisions.map { $0.result.rawValue }, ["registration_quarantined", "registration_returned"])
        XCTAssertEqual(decisions.map(\.failure), [.transport, .none])
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(decisions.last).durationMS, heldMS - 3)
        XCTAssertFalse(store.requiresServerRecovery)
        // A queued success does not re-enable the guard disabled by the earlier failure.
        await service.handleDeviceToken(Data([0xcd]))
        XCTAssertEqual(store.token, "cd")
        XCTAssertEqual(repo.registeredTokens, [token, "ab"])
        XCTAssertEqual(decisions.last?.result.rawValue, "registration_suppressed")
        XCTAssertEqual(Set(decisions.map(\.attemptID)).count, 3)
        try assertRegistrationPrivate(decisions)
    }

    @MainActor
    func testRegistrationDefaultLoggerSmokeAtActualServiceBoundary() async throws {
        let (repo, _) = makeClient { request in
            if request.url!.path.hasSuffix("/unregister_device_token") { return self.failure("42501") }
            return (204, Data())
        }
        let store = InMemoryDeviceTokenStore()
        let service = PushNotificationService(tokenRepository: repo, tokenStore: store,
            registerForRemoteNotifications: {}, unregisterForRemoteNotifications: {}, endLiveActivities: {})
        await service.handleDeviceToken(Data([0xab]))
        store.token = nil
        await service.registerStoredTokenIfAvailable()
        await service.handleDeviceToken(Data([0xab]))
        await service.handleDeviceToken(Data([0xcd]))
        DeviceDiagnosticRequest.respond = { _ in self.failure("42501") }
        await service.registerStoredTokenIfAvailable()
    }

    private func assertRegistrationPrivate(_ decisions: [DeviceTokenDiagnostics.Record], file: StaticString = #filePath, line: UInt = #line) throws {
        XCTAssertFalse(decisions.isEmpty, file: file, line: line)
        for record in decisions {
            XCTAssertTrue(["stored_token_registration", "apns_callback_registration"].contains(record.operation.rawValue), file: file, line: line)
            XCTAssertTrue(["no_stored_token", "registration_suppressed", "registration_returned", "registration_quarantined"].contains(record.result.rawValue), file: file, line: line)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(record.json.utf8)) as? [String: Any])
            XCTAssertEqual(Set(json.keys), Set(["event", "operation", "result", "failure", "attempt_id", "duration_ms", "version", "build", "configuration", "environment"]), file: file, line: line)
            XCTAssertEqual(json["event"] as? String, "device_token_operation", file: file, line: line)
            XCTAssertEqual(json["environment"] as? String, "unit_test", file: file, line: line)
            XCTAssertNotNil(UUID(uuidString: record.attemptID), file: file, line: line)
            XCTAssertGreaterThanOrEqual(record.durationMS, 0, file: file, line: line)
            for secret in ["private", token, userID.uuidString, "PGRST202", "https:"] {
                XCTAssertFalse(record.json.contains(secret), file: file, line: line)
            }
        }
    }

    private func assertCleanupPrivate(_ cleanup: [DeviceTokenDiagnostics.Record], file: StaticString = #filePath, line: UInt = #line) throws {
        XCTAssertFalse(cleanup.isEmpty, file: file, line: line)
        for record in cleanup {
            XCTAssertEqual(record.operation, .accountTransitionCleanup, file: file, line: line)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(record.json.utf8)) as? [String: Any])
            XCTAssertEqual(Set(json.keys), Set(["event", "operation", "result", "failure", "attempt_id", "duration_ms", "version", "build", "configuration", "environment"]), file: file, line: line)
            XCTAssertEqual(json["event"] as? String, "device_token_operation", file: file, line: line)
            XCTAssertEqual(json["environment"] as? String, "unit_test", file: file, line: line)
            XCTAssertNotNil(UUID(uuidString: record.attemptID), file: file, line: line)
            XCTAssertGreaterThanOrEqual(record.durationMS, 0, file: file, line: line)
            for secret in ["private", token, userID.uuidString, "PGRST202", "https:"] {
                XCTAssertFalse(record.json.contains(secret), file: file, line: line)
            }
        }
    }

    func testDefaultLoggerSmokeWithRealSDKStages() async throws {
        let (repo, _) = makeClient(capture: false) { request in
            if request.url!.path.hasSuffix("/register_device_token") { return (204, Data()) }
            return self.failure("PGRST202", status: 404)
        }
        try await repo.register(token: token)
        do { try await repo.unregister(token: token); XCTFail() } catch {}
    }

    func testLiveActivityRPCPreservesOriginalPayloadAndFreshAttemptForEveryInvocation() async throws {
        let sessionID = UUID()
        let (_, client) = makeClient { _ in (204, Data()) }
        let repo = LiveActivityTokenRepository(client: client, diagnostics: .init { self.records.append($0) })
        for _ in 0..<2 { try await repo.register(sessionId: sessionID, token: "  \(token)  ") }
        XCTAssertEqual(requests.map { $0.url!.path }, Array(repeating: "/rest/v1/rpc/register_live_activity_token", count: 2))
        for request in requests {
            XCTAssertEqual(request.httpMethod, "POST")
            let payload = try body(request)
            XCTAssertEqual(Set(payload.keys), Set(["p_session_id", "p_apns_token"]))
            XCTAssertEqual(payload["p_session_id"] as? String, sessionID.uuidString)
            XCTAssertEqual(payload["p_apns_token"] as? String, "  \(token)  ")
        }
        XCTAssertEqual(records.map(\.operation), [.registerLiveActivityRPC, .registerLiveActivityRPC])
        XCTAssertEqual(records.map(\.result), [.succeeded, .succeeded])
        XCTAssertEqual(records.map(\.failure), [.none, .none])
        XCTAssertEqual(Set(records.map(\.attemptID)).count, 2)
        try assertLiveActivityPrivate(sessionID)
    }

    func testLiveActivityRPCRejectionPreservesErrorAndNeverUsesDeviceTokenFallback() async throws {
        let sessionID = UUID()
        for code in ["42501", "PGRST202"] {
            records.removeAll(); requests.removeAll()
            let (_, client) = makeClient { _ in self.failure(code, status: 404) }
            let repo = LiveActivityTokenRepository(client: client, diagnostics: .init { self.records.append($0) })
            do { try await repo.register(sessionId: sessionID, token: token); XCTFail() }
            catch let error as PostgrestError {
                XCTAssertEqual(error.code, code)
                XCTAssertEqual(error.message, "private-server-message")
            }
            XCTAssertEqual(requests.map(\.httpMethod), ["POST"])
            XCTAssertEqual(requests.map { $0.url!.path }, ["/rest/v1/rpc/register_live_activity_token"])
            XCTAssertEqual(records.map(\.operation), [.registerLiveActivityRPC])
            XCTAssertEqual(records.map(\.result), [.failed])
            XCTAssertEqual(records.map(\.failure), [.backend])
            try assertLiveActivityPrivate(sessionID)
        }
    }

    func testLiveActivityTransportAndCancellationRetainOriginalErrors() async throws {
        let sessionID = UUID()
        for code in [URLError.notConnectedToInternet, .cancelled] {
            records.removeAll(); requests.removeAll()
            let (_, client) = makeClient { _ in throw URLError(code, userInfo: [NSLocalizedDescriptionKey: "private-error"]) }
            let repo = LiveActivityTokenRepository(client: client, diagnostics: .init { self.records.append($0) })
            do { try await repo.register(sessionId: sessionID, token: token); XCTFail() }
            catch let error as URLError { XCTAssertEqual(error.code, code) }
            XCTAssertEqual(requests.map(\.httpMethod), ["POST"])
            XCTAssertEqual(records.map(\.operation), [.registerLiveActivityRPC])
            XCTAssertEqual(records.map(\.result), [code == .cancelled ? .cancelled : .failed])
            XCTAssertEqual(records.map(\.failure), [code == .cancelled ? .cancelled : .transport])
            try assertLiveActivityPrivate(sessionID)
        }
    }

    func testLiveActivityDefaultLoggerSmokeWithActualSDK() async throws {
        var attempts = 0
        let (_, client) = makeClient { _ in
            attempts += 1
            return attempts == 1 ? (204, Data()) : self.failure("42501")
        }
        let repo = LiveActivityTokenRepository(client: client)
        let sessionID = UUID()
        try await repo.register(sessionId: sessionID, token: token)
        do { try await repo.register(sessionId: sessionID, token: token); XCTFail() }
        catch let error as PostgrestError { XCTAssertEqual(error.code, "42501") }
        XCTAssertEqual(requests.count, 2)
    }

    private func assertLiveActivityPrivate(_ sessionID: UUID) throws {
        try assertPrivate()
        for record in records {
            XCTAssertFalse(record.json.contains(sessionID.uuidString))
            XCTAssertNotEqual(record.attemptID, sessionID.uuidString)
        }
    }

    private func failure(_ code: String, status: Int = 403) -> (Int, Data) {
        (status, try! JSONSerialization.data(withJSONObject: ["code": code, "message": "private-server-message", "details": token, "hint": "private-url"]))
    }

    private func assertPrivate() throws {
        XCTAssertFalse(records.isEmpty)
        for record in records {
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(record.json.utf8)) as? [String: Any])
            XCTAssertEqual(Set(json.keys), Set(["event", "operation", "result", "failure", "attempt_id", "duration_ms", "version", "build", "configuration", "environment"]))
            XCTAssertEqual(json["event"] as? String, "device_token_operation")
            XCTAssertEqual(json["environment"] as? String, "unit_test")
            XCTAssertNotNil(UUID(uuidString: record.attemptID))
            XCTAssertNotEqual(record.attemptID, userID.uuidString)
            XCTAssertGreaterThanOrEqual(record.durationMS, 0)
            for secret in ["private", token, userID.uuidString, "PGRST202", "42501", "https:"] { XCTAssertFalse(record.json.contains(secret)) }
        }
    }

    private func makeClient(capture: Bool = true, _ responder: @escaping (URLRequest) throws -> (Int, Data)) -> (DeviceTokenRepository, SupabaseClient) {
        DeviceDiagnosticRequest.respond = { request in
            XCTAssertEqual(request.url?.host, "device-diagnostics.invalid")
            self.requests.append(request)
            return try responder(request)
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [DeviceDiagnosticRequest.self]
        let client = SupabaseClient(supabaseURL: URL(string: "https://device-diagnostics.invalid")!, supabaseKey: "synthetic-key",
            options: .init(auth: .init(storage: DeviceDiagnosticStorage(), autoRefreshToken: false),
                           global: .init(session: URLSession(configuration: config), logger: nil)))
        return (DeviceTokenRepository(client: client, diagnostics: capture ? .init { self.records.append($0) } : .init()), client)
    }

    private func authSession() throws -> Data {
        try JSONSerialization.data(withJSONObject: ["access_token": "private-token", "refresh_token": "private-refresh",
            "token_type": "bearer", "expires_in": 3600, "expires_at": Date().timeIntervalSince1970 + 3600,
            "user": ["id": userID.uuidString, "aud": "authenticated", "role": "authenticated", "email": "private@ucf.edu",
                     "app_metadata": [:], "user_metadata": [:], "created_at": "2026-01-01T00:00:00Z", "updated_at": "2026-01-01T00:00:00Z", "is_anonymous": false]])
    }

    private func query(_ request: URLRequest, _ name: String) -> String? {
        URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == name }?.value
    }

    private func body(_ request: URLRequest) throws -> [String: Any] {
        var data = request.httpBody ?? Data()
        if let stream = request.httpBodyStream {
            stream.open(); defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 2048)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                data.append(contentsOf: buffer.prefix(count))
            }
        }
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}

private final class DeviceDiagnosticStorage: AuthLocalStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Data] = [:]
    func store(key: String, value: Data) throws { lock.lock(); defer { lock.unlock() }; values[key] = value }
    func retrieve(key: String) throws -> Data? { lock.lock(); defer { lock.unlock() }; return values[key] }
    func remove(key: String) throws { lock.lock(); defer { lock.unlock() }; values.removeValue(forKey: key) }
}

private final class DeviceDiagnosticRequest: URLProtocol {
    static var respond: ((URLRequest) throws -> (Int, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (status, data) = try XCTUnwrap(Self.respond)(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil,
                headerFields: ["Content-Type": "application/json", "X-Supabase-Api-Version": "2024-01-01"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

private actor DeviceRegistrationGate {
    private var pending: CheckedContinuation<Void, Never>?
    private var started: CheckedContinuation<Void, Never>?

    func wait() async {
        await withCheckedContinuation { continuation in
            pending = continuation
            started?.resume()
            started = nil
        }
    }

    func waitUntilStarted() async {
        if pending != nil { return }
        await withCheckedContinuation { started = $0 }
    }

    func release() {
        pending?.resume()
        pending = nil
    }
}
