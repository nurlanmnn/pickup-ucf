import XCTest
@testable import PickUpUCF

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
        repository.signUpError = StubLocalizedError("An account with this email already exists. Try signing in.")
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

private struct StubLocalizedError: LocalizedError {
    let errorDescription: String?
    init(_ message: String) { errorDescription = message }
}

private final class RecordingAuthRepository: AuthRepositoryProtocol {
    var signUpCallCount = 0
    var signInCallCount = 0
    var changePasswordCallCount = 0
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
