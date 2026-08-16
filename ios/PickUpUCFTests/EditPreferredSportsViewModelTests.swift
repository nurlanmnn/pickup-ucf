import XCTest
@testable import PickUpUCF

final class EditPreferredSportsViewModelTests: XCTestCase {
    func testCannotSaveWithZeroSportsSelected() {
        let viewModel = EditPreferredSportsViewModel()

        XCTAssertTrue(viewModel.selectedSports.isEmpty)
        XCTAssertFalse(viewModel.canSave)
    }

    func testCanSaveWhenSportSelected() {
        let viewModel = EditPreferredSportsViewModel()
        viewModel.selectedSports.insert(.pickleball)

        XCTAssertTrue(viewModel.canSave)
    }

    @MainActor
    func testSaveWithZeroSportsSetsValidationError() async {
        let viewModel = EditPreferredSportsViewModel(repository: StubEditSportsRepository())

        let saved = await viewModel.save()

        XCTAssertFalse(saved)
        XCTAssertEqual(viewModel.errorMessage, "Select at least one sport")
    }
}

private final class StubEditSportsRepository: ProfileRepositoryProtocol {
    func ensureProfileForCurrentUser() async throws {}

    func ensureProfile(userId: UUID, displayName: String) async throws {}

    func fetchCurrentProfile() async throws -> Profile {
        Profile(id: UUID(), displayName: "Test", preferredSports: [.basketball])
    }

    func fetchProfile(userId: UUID) async throws -> Profile {
        Profile(id: userId, displayName: "Test", preferredSports: [.basketball])
    }

    func completeOnboarding(sports: [SportType]) async throws {}

    func updatePreferredSports(_ sports: [SportType]) async throws {
        XCTFail("updatePreferredSports should not be called without selected sports")
    }

    func updateUsername(_ username: String) async throws {}

    func deleteAccount() async throws {}
}
