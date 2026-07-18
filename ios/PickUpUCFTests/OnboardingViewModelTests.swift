import XCTest
@testable import PickUpUCF

final class OnboardingViewModelTests: XCTestCase {
    func testCannotSubmitWithZeroSportsSelected() {
        let viewModel = OnboardingViewModel()

        XCTAssertTrue(viewModel.selectedSports.isEmpty)
        XCTAssertFalse(viewModel.canSubmit)
    }

    func testCanSubmitWhenSportSelected() {
        let viewModel = OnboardingViewModel()
        viewModel.selectedSports.insert(.basketball)

        XCTAssertTrue(viewModel.canSubmit)
    }

    @MainActor
    func testSubmitWithZeroSportsSetsValidationError() async {
        let viewModel = OnboardingViewModel(repository: StubProfileRepository())
        let appState = AppState()

        await viewModel.submit(appState: appState)

        XCTAssertEqual(viewModel.errorMessage, "Select at least one sport")
        XCTAssertFalse(viewModel.canSubmit)
    }
}

private final class StubProfileRepository: ProfileRepositoryProtocol {
    func ensureProfileForCurrentUser() async throws {}

    func ensureProfile(userId: UUID, displayName: String) async throws {}

    func fetchCurrentProfile() async throws -> Profile {
        Profile(id: userId, displayName: "Test")
    }

    func completeOnboarding(sports: [SportType], skillLevel: SkillLevel) async throws {
        XCTFail("completeOnboarding should not be called without selected sports")
    }

    func updateUsername(_ username: String) async throws {}

    func deleteAccount() async throws {}

    private let userId = UUID()
}
