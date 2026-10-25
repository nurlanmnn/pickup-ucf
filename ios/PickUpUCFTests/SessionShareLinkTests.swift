import XCTest
@testable import PickUpUCF

final class SessionShareLinkTests: XCTestCase {
    func testURLFormat() {
        let id = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        XCTAssertEqual(
            SessionShareLink.url(for: id).absoluteString,
            "https://pickup-ucf-privacy.vercel.app/session/00000000-0000-0000-0000-000000000001"
        )
    }

    func testDeepLinkRouterParsesSessionURL() {
        let url = SessionShareLink.url(for: UUID())
        if case .session = DeepLinkRouter.destination(from: url) {
            // pass
        } else {
            XCTFail("Expected session destination")
        }
    }

    func testChatDeepLinkSurvivesSessionNavigationConsumption() {
        let sessionId = UUID()
        let appState = AppState()
        appState.session = AppSession(
            userId: UUID(),
            email: "student@ucf.edu",
            isEmailConfirmed: true
        )

        appState.queueSessionDeepLink(id: sessionId, openChat: true)
        appState.clearSessionDetailDeepLink()

        XCTAssertTrue(appState.consumeSessionDetailOpenChat(for: sessionId))
        XCTAssertFalse(appState.consumeSessionDetailOpenChat(for: sessionId))
    }
}

final class AuthCallbackBoundaryTests: XCTestCase {
    func testRejectsMalformedAuthCallbacksBeforeSDKExchange() {
        for value in [
            "pickupucf://auth/reset-password?code=intercepted",
            "https://pickup-ucf-privacy.vercel.app.attacker.invalid/auth/reset-password?code=a",
            "https://pickup-ucf-privacy.vercel.app/auth/reset-password?code=a&code=b",
            "https://pickup-ucf-privacy.vercel.app/auth/reset-password#access_token=secret",
            "https://pickup-ucf-privacy.vercel.app/auth/reset-password?code=a&redirect_to=https://attacker.invalid",
            "https://pickup-ucf-privacy.vercel.app/auth/reset-password",
            "pickupucf://auth/reset-password",
            "pickupucf://auth/reset-password?code=",
            "pickupucf://auth/reset-password?code=a&code=b",
            "pickupucf://auth/reset-password#access_token=secret&refresh_token=secret",
            "pickupucf://user@auth/reset-password?code=a",
            "pickupucf://auth:123/reset-password?code=a",
            "pickupucf://auth//reset-password?code=a",
            "pickupucf://auth/reset-password?code=a&redirect_to=https://attacker.invalid",
        ] {
            XCTAssertNil(DeepLinkRouter.destination(from: URL(string: value)!), value)
        }
    }

    func testRepositoryRejectsCustomSchemeBeforeAuthExchange() async {
        do {
            try await AuthRepository().handleAuthDeepLink(url: URL(string: "pickupucf://auth/reset-password?code=synthetic")!)
            XCTFail("Expected boundary rejection")
        } catch AuthRepositoryError.invalidCallback {} catch { XCTFail("Wrong rejection") }
    }

    func testHTTPSAndLegacySessionRoutesRejectAmbiguity() {
        let id = UUID()
        for value in [
            "https://pickup-ucf-privacy.vercel.app/session/\(id)?code=secret",
            "https://pickup-ucf-privacy.vercel.app/session/\(id)/extra",
            "https://pickup-ucf-privacy.vercel.app:443/session/\(id)",
            "http://pickup-ucf-privacy.vercel.app/session/\(id)",
            "pickupucf://session//\(id)"
        ] { XCTAssertNil(DeepLinkRouter.destination(from: URL(string: value)!)) }
        guard case .session(let parsed) = DeepLinkRouter.destination(from: URL(string: "pickupucf://session/\(id)")!) else {
            return XCTFail("Legacy session notification route must remain available")
        }
        XCTAssertEqual(parsed, id)
    }

    func testAcceptsOnePKCECodeOnExactResetRoute() {
        guard case .resetPassword = DeepLinkRouter.destination(from:
            URL(string: "https://pickup-ucf-privacy.vercel.app/auth/reset-password?code=synthetic-code")!) else {
            return XCTFail("Expected reset route")
        }
    }
}

final class ResetPasswordCompletionTests: XCTestCase {
    @MainActor
    func testValidationFailureRetryAndSuccess() async {
        let repository = RecoveryAuthSpy()
        let model = ResetPasswordViewModel(repository: repository)
        model.password = "short"
        model.confirmation = "different"
        await model.save()
        XCTAssertEqual(repository.updateCount, 0)
        XCTAssertNotNil(model.errorMessage)
        model.password = "synthetic-password"
        model.confirmation = "different"
        await model.save()
        XCTAssertEqual(repository.updateCount, 0)
        model.confirmation = model.password
        repository.shouldFail = true
        await model.save()
        XCTAssertFalse(model.didSucceed)
        XCTAssertNotNil(model.errorMessage)
        XCTAssertFalse(model.password.isEmpty)
        repository.shouldFail = false
        await model.save()
        XCTAssertTrue(model.didSucceed)
        XCTAssertEqual(model.password, "")
        XCTAssertEqual(model.confirmation, "")
        XCTAssertEqual(repository.updateCount, 2)
    }

    func testAccountTransitionClearsRecoveryContext() {
        let state = AppState()
        let id = UUID()
        state.session = AppSession(userId: id, email: "synthetic@ucf.edu", isEmailConfirmed: true)
        state.passwordRecoveryUserId = id
        state.session = nil
        XCTAssertNil(state.passwordRecoveryUserId)
    }
}

private final class RecoveryAuthSpy: AuthRepositoryProtocol {
    var shouldFail = false
    var updateCount = 0
    func updatePassword(_ newPassword: String) async throws {
        updateCount += 1
        if shouldFail { throw URLError(.notConnectedToInternet) }
    }
    func signUp(email: String, password: String, displayName: String) async throws {}
    func signIn(email: String, password: String) async throws -> AppSession { throw URLError(.unsupportedURL) }
    func signOut() async throws {}
    func resendVerificationEmail(email: String) async throws {}
    func resendVerificationOTP(email: String) async throws {}
    func verifyEmailOTP(email: String, token: String) async throws -> AppSession { throw URLError(.unsupportedURL) }
    func requestPasswordReset(email: String) async throws {}
    func changePassword(email: String, currentPassword: String, newPassword: String) async throws {}
    func handleAuthDeepLink(url: URL) async throws {}
    func currentSession() async -> AppSession? { nil }
}

final class SessionLinkDiagnosticsTests: XCTestCase {
    private var records: [SessionLinkDiagnostics.Record] = []

    func testConfirmedQueueAssignsBeforeEmissionAndPreservesOneShotChat() throws {
        let id = UUID()
        let state = AppState(linkDiagnostics: .init { self.records.append($0) })
        state.session = AppSession(userId: UUID(), email: "private@ucf.edu", isEmailConfirmed: true)
        state.queueSessionDeepLink(id: id, openChat: true)
        XCTAssertEqual(state.sessionDetailDeepLink, id)
        XCTAssertEqual(state.sessionDetailDeepLinkTarget, .discover)
        XCTAssertNil(state.pendingSessionDeepLink)
        state.clearSessionDetailDeepLink()
        XCTAssertTrue(state.consumeSessionDetailOpenChat(for: id))
        XCTAssertFalse(state.consumeSessionDetailOpenChat(for: id))
        XCTAssertEqual(records.map(\.operation), [.queueSession])
        XCTAssertEqual(records.map(\.result), [.assigned])
        try assertPrivate([id])
    }

    func testMissingAndUnconfirmedAuthenticationDeferAndReplacePendingIntent() throws {
        let first = UUID(), second = UUID()
        let state = AppState(linkDiagnostics: .init { self.records.append($0) })
        state.queueSessionDeepLink(id: first, openChat: true)
        XCTAssertEqual(state.pendingSessionDeepLink, first)
        XCTAssertTrue(state.pendingSessionDeepLinkOpenChat)
        state.session = AppSession(userId: UUID(), email: "private@ucf.edu", isEmailConfirmed: false)
        state.queueSessionDeepLink(id: second)
        XCTAssertEqual(state.pendingSessionDeepLink, second)
        XCTAssertFalse(state.pendingSessionDeepLinkOpenChat)
        XCTAssertNil(state.sessionDetailDeepLink)
        XCTAssertFalse(state.consumeSessionDetailOpenChat(for: first))
        XCTAssertFalse(state.consumeSessionDetailOpenChat(for: second))
        XCTAssertEqual(records.map(\.result), [.deferred, .deferred])
        XCTAssertEqual(Set(records.map(\.attemptID)).count, 2)
        try assertPrivate([first, second])
    }

    func testResumeGuardPrecedenceKeepsPendingStateUntilConfirmed() throws {
        let id = UUID(), user = UUID()
        let state = AppState(linkDiagnostics: .init { self.records.append($0) })
        state.consumePendingSessionDeepLinkIfNeeded()
        state.queueSessionDeepLink(id: id, openChat: true)
        state.consumePendingSessionDeepLinkIfNeeded()
        state.session = AppSession(userId: user, email: "private@ucf.edu", isEmailConfirmed: false)
        state.consumePendingSessionDeepLinkIfNeeded()
        XCTAssertEqual(state.pendingSessionDeepLink, id)
        XCTAssertTrue(state.pendingSessionDeepLinkOpenChat)
        XCTAssertNil(state.sessionDetailDeepLink)
        state.session = AppSession(userId: user, email: "private@ucf.edu", isEmailConfirmed: true)
        state.consumePendingSessionDeepLinkIfNeeded()
        XCTAssertNil(state.pendingSessionDeepLink)
        XCTAssertFalse(state.pendingSessionDeepLinkOpenChat)
        XCTAssertEqual(state.sessionDetailDeepLink, id)
        XCTAssertTrue(state.consumeSessionDetailOpenChat(for: id))
        XCTAssertFalse(state.consumeSessionDetailOpenChat(for: id))
        state.consumePendingSessionDeepLinkIfNeeded()
        XCTAssertEqual(records.map(\.operation), [.resumePending, .queueSession, .resumePending, .resumePending, .queueSession, .resumePending, .resumePending])
        XCTAssertEqual(records.map(\.result), [.noPending, .deferred, .waitingForAuth, .waitingForAuth, .assigned, .resumed, .noPending])
        XCTAssertEqual(Set(records.map(\.attemptID)).count, 7)
        try assertPrivate([id, user])
    }

    func testCompletionSinkObservesStateUpdatesAndNestedResumeOrder() throws {
        let id = UUID()
        weak var observedState: AppState?
        let state = AppState(linkDiagnostics: .init { record in
            guard let state = observedState else { return XCTFail("Missing state") }
            switch record.result {
            case .deferred:
                XCTAssertEqual(state.pendingSessionDeepLink, id)
                XCTAssertTrue(state.pendingSessionDeepLinkOpenChat)
            case .assigned, .resumed:
                XCTAssertNil(state.pendingSessionDeepLink)
                XCTAssertFalse(state.pendingSessionDeepLinkOpenChat)
                XCTAssertEqual(state.sessionDetailDeepLink, id)
            default: XCTFail("Unexpected completion")
            }
            self.records.append(record)
        })
        observedState = state
        state.queueSessionDeepLink(id: id, openChat: true)
        state.session = AppSession(userId: UUID(), email: "private@ucf.edu", isEmailConfirmed: true)
        state.consumePendingSessionDeepLinkIfNeeded()
        XCTAssertEqual(records.map(\.result), [.deferred, .assigned, .resumed])
        try assertPrivate([id])
    }

    func testAccountChangeStillClearsDeferredNavigationAndChatIntent() throws {
        let id = UUID(), user = UUID()
        let state = AppState(linkDiagnostics: .init { self.records.append($0) })
        state.session = AppSession(userId: user, email: "private@ucf.edu", isEmailConfirmed: false)
        state.queueSessionDeepLink(id: id, openChat: true)
        state.session = AppSession(userId: UUID(), email: "other-private@ucf.edu", isEmailConfirmed: true)
        state.consumePendingSessionDeepLinkIfNeeded()
        XCTAssertNil(state.pendingSessionDeepLink)
        XCTAssertFalse(state.pendingSessionDeepLinkOpenChat)
        XCTAssertNil(state.sessionDetailDeepLink)
        XCTAssertFalse(state.consumeSessionDetailOpenChat(for: id))
        XCTAssertEqual(records.map(\.result), [.deferred, .noPending])
        try assertPrivate([id, user])
    }

    func testAuthenticatedQueueRetainsExistingPendingAndReplacesChatIntent() throws {
        let pending = UUID(), current = UUID()
        let state = AppState(linkDiagnostics: .init { self.records.append($0) })
        state.queueSessionDeepLink(id: pending, openChat: true)
        state.session = AppSession(userId: UUID(), email: "private@ucf.edu", isEmailConfirmed: true)
        state.queueSessionDeepLink(id: current)
        XCTAssertEqual(state.pendingSessionDeepLink, pending)
        XCTAssertTrue(state.pendingSessionDeepLinkOpenChat)
        XCTAssertEqual(state.sessionDetailDeepLink, current)
        XCTAssertFalse(state.consumeSessionDetailOpenChat(for: pending))
        XCTAssertFalse(state.consumeSessionDetailOpenChat(for: current))
        XCTAssertEqual(records.map(\.result), [.deferred, .assigned])
        try assertPrivate([pending, current])
    }

    func testDefaultLoggerAtActualStateHandoff() {
        let state = AppState(), id = UUID()
        state.consumePendingSessionDeepLinkIfNeeded()
        state.queueSessionDeepLink(id: id, openChat: true)
        state.consumePendingSessionDeepLinkIfNeeded()
        state.session = AppSession(userId: UUID(), email: "private@ucf.edu", isEmailConfirmed: true)
        state.consumePendingSessionDeepLinkIfNeeded()
        XCTAssertEqual(state.sessionDetailDeepLink, id)
    }

    private func assertPrivate(_ ids: [UUID], file: StaticString = #filePath, line: UInt = #line) throws {
        XCTAssertFalse(records.isEmpty, file: file, line: line)
        for record in records {
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(record.json.utf8)) as? [String: Any])
            XCTAssertEqual(Set(json.keys), Set(["event", "operation", "result", "failure", "attempt_id", "duration_ms", "version", "build", "configuration", "environment"]), file: file, line: line)
            XCTAssertEqual(json["event"] as? String, "session_link_handoff", file: file, line: line)
            XCTAssertEqual(json["failure"] as? String, "none", file: file, line: line)
            XCTAssertEqual(json["environment"] as? String, "unit_test", file: file, line: line)
            XCTAssertNotNil(UUID(uuidString: record.attemptID), file: file, line: line)
            XCTAssertGreaterThanOrEqual(record.durationMS, 0, file: file, line: line)
            for secret in ids.map(\.uuidString) + ["private", "https:", "pickupucf:", "open_chat"] {
                XCTAssertFalse(record.json.contains(secret), file: file, line: line)
            }
        }
    }
}
