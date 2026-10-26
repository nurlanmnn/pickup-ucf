import XCTest
import Supabase
@testable import PickUpUCF

/// Uses the real Keychain: an unsigned simulator host must fail this check.
final class AuthSessionPersistenceTests: XCTestCase {
    func testSignInPersistsSessionForProfileAndAnotherClient() async throws {
        let storage = KeychainLocalStorage(service: "pickup.auth-tests.\(UUID().uuidString)")
        let key = UUID().uuidString
        defer { try? storage.remove(key: key) }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [PersistedAuthRequest.self]
        func makeClient() -> SupabaseClient {
            SupabaseClient(supabaseURL: URL(string: "https://auth-tests.invalid")!,
                           supabaseKey: "synthetic-test-key", options: .init(
                            auth: .init(storage: storage, storageKey: key, autoRefreshToken: false),
                            global: .init(session: URLSession(configuration: configuration))))
        }

        let client = makeClient()
        let signedIn = try await AuthRepository(client: client).signIn(
            email: "synthetic@ucf.edu", password: "synthetic-password")
        XCTAssertNotNil(try storage.retrieve(key: key), "Sign-in must reach Keychain, not just app UI state")
        let profile = try await ProfileRepository(client: client).fetchCurrentProfile()
        XCTAssertEqual(profile.id, signedIn.userId)
        let validated = await AuthRepository(client: client).currentSession()
        XCTAssertEqual(validated?.userId, signedIn.userId)
        let restored = try await makeClient().auth.session
        XCTAssertEqual(restored.user.id, signedIn.userId, "A new client must restore the persisted session")
        try await client.auth.signOut(scope: .local)
        XCTAssertNil(makeClient().auth.currentSession, "Local sign-out must remove the saved session")
    }
    func testRemoteLogoutFailureStillClearsRealKeychainSession() async throws {
        let storage = KeychainLocalStorage(service: "pickup.logout-tests.\(UUID().uuidString)")
        let key = UUID().uuidString
        defer { try? storage.remove(key: key) }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [PersistedAuthRequest.self]
        let client = SupabaseClient(supabaseURL: URL(string: "https://logout-error.invalid")!, supabaseKey: "synthetic-key",
                                    options: .init(auth: .init(storage: storage, storageKey: key, autoRefreshToken: false),
                                                   global: .init(session: URLSession(configuration: config))))
        let repository = AuthRepository(client: client)
        _ = try await repository.signIn(email: "synthetic@ucf.edu", password: "synthetic-password")
        do { try await repository.signOut(); XCTFail("Expected remote failure") }
        catch {}
        XCTAssertThrowsError(try storage.retrieve(key: key)) { error in
            XCTAssertTrue(error.localizedDescription.hasPrefix("errSecItemNotFound:"))
        }
        XCTAssertNil(client.auth.currentSession)
    }

    func testRelaunchRejectsDeletedAccountButRetainsSessionDuringOfflineVerification() async throws {
        for host in ["deleted-auth-tests.invalid", "offline-auth-tests.invalid"] {
            let storage = KeychainLocalStorage(service: "pickup.relaunch-tests.\(UUID().uuidString)")
            let key = UUID().uuidString
            defer { try? storage.remove(key: key) }
            let config = URLSessionConfiguration.ephemeral
            config.protocolClasses = [PersistedAuthRequest.self]
            func makeClient() -> SupabaseClient {
                SupabaseClient(supabaseURL: URL(string: "https://\(host)")!, supabaseKey: "synthetic-key",
                               options: .init(auth: .init(storage: storage, storageKey: key, autoRefreshToken: false),
                                              global: .init(session: URLSession(configuration: config))))
            }
            _ = try await AuthRepository(client: makeClient()).signIn(email: "synthetic@ucf.edu", password: "synthetic-password")
            let restoredClient = makeClient()
            let restored = await AuthRepository(client: restoredClient).currentSession()
            if host.hasPrefix("deleted") {
                XCTAssertNil(restored)
                XCTAssertThrowsError(try storage.retrieve(key: key)) { error in
                    XCTAssertTrue(error.localizedDescription.hasPrefix("errSecItemNotFound:"))
                }
            } else {
                XCTAssertNotNil(restored, "A network failure is not evidence of deletion")
                XCTAssertNotNil(try storage.retrieve(key: key))
            }
        }
    }

}

private final class PersistedAuthRequest: URLProtocol {
    private static let userId = "00000000-0000-0000-0000-000000000123"
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let payload: [String: Any]
            if request.url?.path == "/auth/v1/user" {
                if request.url?.host == "offline-auth-tests.invalid" { throw URLError(.notConnectedToInternet) }
                let deleted = request.url?.host == "deleted-auth-tests.invalid"
                let user: [String: Any] = ["id": Self.userId, "aud": "authenticated", "role": "authenticated",
                    "email": "synthetic@ucf.edu", "app_metadata": [:], "user_metadata": [:],
                    "created_at": "2026-01-01T00:00:00Z", "updated_at": "2026-01-01T00:00:00Z",
                    "email_confirmed_at": "2026-01-01T00:00:00Z", "is_anonymous": false]
                let body = deleted ? Data(#"{"code":"user_not_found","msg":"User from sub claim in JWT does not exist"}"#.utf8)
                    : try JSONSerialization.data(withJSONObject: user)
                let response = HTTPURLResponse(url: request.url!, statusCode: deleted ? 404 : 200, httpVersion: nil,
                                               headerFields: ["Content-Type": "application/json", "X-Supabase-Api-Version": "2024-01-01"])!
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: body)
                client?.urlProtocolDidFinishLoading(self)
                return
            }
            if request.url?.path == "/auth/v1/token" {
                payload = [
                    "access_token": "synthetic-access-token", "refresh_token": "synthetic-refresh-token",
                    "token_type": "bearer", "expires_in": 3600,
                    "expires_at": Date().addingTimeInterval(3600).timeIntervalSince1970,
                    "user": ["id": Self.userId, "aud": "authenticated", "role": "authenticated",
                             "email": "synthetic@ucf.edu", "app_metadata": [:], "user_metadata": [:],
                             "created_at": "2026-01-01T00:00:00Z", "updated_at": "2026-01-01T00:00:00Z",
                             "email_confirmed_at": "2026-01-01T00:00:00Z", "is_anonymous": false]
                ]
            } else if request.url?.path == "/rest/v1/profiles" {
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer synthetic-access-token")
                payload = ["id": Self.userId, "display_name": "Synthetic Knight", "games_played": 0,
                           "show_up_streak": 0, "preferred_sports": []]
            } else if request.url?.path == "/auth/v1/logout" {
                if request.url?.host == "logout-error.invalid" {
                    let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil,
                                                   headerFields: ["Content-Type": "application/json", "X-Supabase-Api-Version": "2024-01-01"])!
                    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                    client?.urlProtocol(self, didLoad: Data(#"{"code":"unexpected_failure","msg":"Synthetic logout failure"}"#.utf8))
                    client?.urlProtocolDidFinishLoading(self)
                    return
                }
                payload = [:]
            } else {
                throw URLError(.unsupportedURL)
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil,
                                           headerFields: ["Content-Type": "application/json", "X-Supabase-Api-Version": "2024-01-01"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: try JSONSerialization.data(withJSONObject: payload))
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

/// Field validation belongs next to the field. `errorMessage` (the banner) is for API failures.
final class FormValidationFeedbackTests: XCTestCase {
    @MainActor
    func testSignUpFieldErrorsDoNotSetBanner() async {
        let repository = RecordingAuthRepository()
        let viewModel = SignUpViewModel(repository: repository)

        await viewModel.signUp()

        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(repository.signUpCallCount, 0)
    }

    @MainActor
    func testSignUpRepositoryFailureSetsBanner() async {
        let repository = RecordingAuthRepository()
        repository.signUpError = StubLocalizedError("User already registered")
        let viewModel = SignUpViewModel(repository: repository)
        viewModel.displayName = "Knight"
        viewModel.email = "knight@knights.ucf.edu"
        viewModel.password = "password1"
        viewModel.confirmPassword = "password1"

        await viewModel.signUp()

        XCTAssertEqual(viewModel.errorMessage, "An account with this email already exists. Try signing in.")
        XCTAssertEqual(repository.signUpCallCount, 1)
    }

    @MainActor
    func testSignInFieldErrorsDoNotSetBanner() async {
        let repository = RecordingAuthRepository()
        let viewModel = SignInViewModel(repository: repository, profileRepository: StubProfileRepository())

        await viewModel.signIn(appState: AppState())

        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(repository.signInCallCount, 0)
    }

    @MainActor
    func testChangePasswordFieldErrorsDoNotSetBanner() async {
        let repository = RecordingAuthRepository()
        let viewModel = ChangePasswordViewModel(authRepository: repository)
        viewModel.currentPassword = "oldpass1"
        viewModel.newPassword = "short"
        viewModel.confirmPassword = "short"

        await viewModel.updatePassword(email: "knight@knights.ucf.edu")

        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(repository.changePasswordCallCount, 0)
    }

    @MainActor
    func testClearedPasswordDraftCannotSubmitPreviousCredentials() async {
        let repository = RecordingAuthRepository()
        let viewModel = ChangePasswordViewModel(authRepository: repository)
        viewModel.currentPassword = "synthetic-old"
        viewModel.newPassword = "synthetic-new"
        viewModel.confirmPassword = "synthetic-new"
        XCTAssertTrue(viewModel.canSubmit)

        viewModel.clearPasswordDraft()
        await viewModel.updatePassword(email: "synthetic@ucf.edu")

        XCTAssertEqual(viewModel.currentPassword, "")
        XCTAssertEqual(viewModel.newPassword, "")
        XCTAssertEqual(viewModel.confirmPassword, "")
        XCTAssertFalse(viewModel.canSubmit)
        XCTAssertEqual(repository.changePasswordCallCount, 0)
    }

    @MainActor
    func testClearingPasswordDraftPreservesPendingRequestAndLoadingGuard() async {
        let repository = RecordingAuthRepository()
        let started = expectation(description: "synthetic request began")
        var finishRequest: CheckedContinuation<Void, Never>?
        var shouldSuspend = true
        repository.changePasswordBody = {
            guard shouldSuspend else { return }
            shouldSuspend = false
            await withCheckedContinuation { continuation in
                finishRequest = continuation
                started.fulfill()
            }
        }
        let viewModel = ChangePasswordViewModel(authRepository: repository)
        viewModel.currentPassword = "synthetic-old"
        viewModel.newPassword = "synthetic-new"
        viewModel.confirmPassword = "synthetic-new"
        let request = Task { await viewModel.updatePassword(email: "synthetic@ucf.edu") }
        await fulfillment(of: [started], timeout: 2)

        viewModel.clearPasswordDraft()
        XCTAssertEqual(viewModel.currentPassword, "")
        XCTAssertEqual(viewModel.newPassword, "")
        XCTAssertEqual(viewModel.confirmPassword, "")
        XCTAssertTrue(viewModel.isLoading)
        // Even a newly entered valid draft must not start a second request.
        viewModel.currentPassword = "synthetic-other-old"
        viewModel.newPassword = "synthetic-other-new"
        viewModel.confirmPassword = "synthetic-other-new"
        await viewModel.updatePassword(email: "synthetic@ucf.edu")
        XCTAssertEqual(repository.changePasswordCallCount, 1)
        viewModel.clearPasswordDraft()
        XCTAssertEqual(repository.changePasswordArguments?.email, "synthetic@ucf.edu")
        XCTAssertEqual(repository.changePasswordArguments?.currentPassword, "synthetic-old")
        XCTAssertEqual(repository.changePasswordArguments?.newPassword, "synthetic-new")
        finishRequest?.resume()
        await request.value
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertTrue(viewModel.didSucceed)
        XCTAssertEqual(viewModel.currentPassword, "")
        XCTAssertEqual(viewModel.newPassword, "")
        XCTAssertEqual(viewModel.confirmPassword, "")
    }

    @MainActor
    func testEditUsernameFieldErrorsDoNotSetBanner() async {
        let repository = StubProfileRepository()
        let viewModel = EditUsernameViewModel(repository: repository)
        viewModel.username = ""

        let saved = await viewModel.save()

        XCTAssertFalse(saved)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(repository.updateUsernameCallCount, 0)
    }

    @MainActor
    func testCreateSessionFieldErrorsDoNotSetBanner() async {
        let viewModel = CreateSessionViewModel()
        viewModel.sport = .other
        viewModel.customSportName = ""

        let session = await viewModel.create()

        XCTAssertNil(session)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertNotNil(viewModel.sportNameError)
    }

    @MainActor
    func testEditSessionFieldErrorsDoNotSetBanner() async {
        let viewModel = EditSessionViewModel(session: .validationFixture(sport: .other, customSportName: nil))
        viewModel.customSportName = ""

        let session = await viewModel.save()

        XCTAssertNil(session)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertNotNil(viewModel.sportNameError)
    }
}

/// Keyboard controls must reserve layout space above the software keyboard. A
/// `.keyboard` toolbar floats over bottom-aligned composers and action bars on
/// newer iOS versions, which makes both sets of controls overlap.
final class KeyboardAccessoryLayoutTests: XCTestCase {
    func testKeyboardControlsUseSafeAreaInsetInsteadOfKeyboardToolbarPlacement() throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let sourceDirectory = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("PickUpUCF")

        let sourceFiles = try XCTUnwrap(
            FileManager.default.enumerator(
                at: sourceDirectory,
                includingPropertiesForKeys: nil
            )?.allObjects as? [URL]
        )
        let keyboardToolbarOffenders = try sourceFiles
            .filter { $0.pathExtension == "swift" }
            .filter { try String(contentsOf: $0, encoding: .utf8).contains("placement: .keyboard") }
            .map(\.lastPathComponent)

        XCTAssertTrue(
            keyboardToolbarOffenders.isEmpty,
            "System keyboard toolbars can overlap bottom content: \(keyboardToolbarOffenders)"
        )

        let accessorySource = try String(
            contentsOf: sourceDirectory
                .appendingPathComponent("DesignSystem")
                .appendingPathComponent("Keyboard")
                .appendingPathComponent("FormKeyboardToolbar.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(
            accessorySource.contains(".safeAreaInset(edge: .bottom"),
            "The shared keyboard accessory must reserve space above the keyboard."
        )
    }
}

private struct StubLocalizedError: LocalizedError {
    let errorDescription: String?
    init(_ message: String) { errorDescription = message }
}

private final class RecordingAuthRepository: AuthRepositoryProtocol {
    var signUpCallCount = 0
    var signInCallCount = 0
    var changePasswordCallCount = 0
    var changePasswordArguments: (email: String, currentPassword: String, newPassword: String)?
    var changePasswordBody: (() async -> Void)?
    var signUpError: Error?

    func signUp(email: String, password: String, displayName: String) async throws {
        signUpCallCount += 1
        if let signUpError { throw signUpError }
    }

    func signIn(email: String, password: String) async throws -> AppSession {
        signInCallCount += 1
        throw StubLocalizedError("should not sign in during field validation")
    }

    func signOut() async throws {}
    func resendVerificationEmail(email: String) async throws {}
    func resendVerificationOTP(email: String) async throws {}
    func verifyEmailOTP(email: String, token: String) async throws -> AppSession {
        throw StubLocalizedError("unimplemented")
    }
    func requestPasswordReset(email: String) async throws {}
    func updatePassword(_ newPassword: String) async throws {}
    func changePassword(email: String, currentPassword: String, newPassword: String) async throws {
        changePasswordCallCount += 1
        changePasswordArguments = (email, currentPassword, newPassword)
        await changePasswordBody?()
    }
    func handleAuthDeepLink(url: URL) async throws {}
    func currentSession() async -> AppSession? { nil }
}

private final class StubProfileRepository: ProfileRepositoryProtocol {
    var updateUsernameCallCount = 0

    func ensureProfileForCurrentUser() async throws {}
    func ensureProfile(userId: UUID, displayName: String) async throws {}
    func fetchCurrentProfile() async throws -> Profile {
        Profile(id: UUID(), displayName: "Test")
    }
    func fetchProfile(userId: UUID) async throws -> Profile {
        Profile(id: userId, displayName: "Test")
    }
    func completeOnboarding(sports: [SportType]) async throws {}
    func updatePreferredSports(_ sports: [SportType]) async throws {}
    func updateUsername(_ username: String) async throws {
        updateUsernameCallCount += 1
    }
    func deleteAccount() async throws {}
}

private extension PickupSession {
    static func validationFixture(sport: SportType, customSportName: String?) -> PickupSession {
        let venueId = UUID()
        return PickupSession(
            id: UUID(),
            hostId: UUID(),
            sport: sport,
            customSportName: customSportName,
            venueId: venueId,
            customLocation: nil,
            customLat: nil,
            customLng: nil,
            startsAt: Date().addingTimeInterval(7200),
            endsAt: Date().addingTimeInterval(7200 + 5400),
            capacity: 10,
            playerCount: 2,
            skillLevel: .intermediate,
            notes: nil,
            status: .open,
            venue: Venue(id: venueId, name: "Memory Mall", lat: 28.6, lng: -81.2, campusZone: nil, isOfficial: true),
            host: nil,
            weatherSnapshot: nil
        )
    }
}
