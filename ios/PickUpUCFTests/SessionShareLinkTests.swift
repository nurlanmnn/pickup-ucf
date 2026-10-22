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
