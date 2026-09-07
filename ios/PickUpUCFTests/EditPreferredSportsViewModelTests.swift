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

final class ProfilePreferredSportsNavigationTests: XCTestCase {
    func testPreferredSportsCardLinksDirectlyToSportsEditor() throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let profileViewURL = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("PickUpUCF")
            .appendingPathComponent("Features")
            .appendingPathComponent("Profile")
            .appendingPathComponent("ProfileView.swift")
        let source = try String(contentsOf: profileViewURL, encoding: .utf8)
        let preferredSportsLink = #"NavigationLink\s*\{\s*EditPreferredSportsView\(\)\s*\}\s*label:\s*\{\s*sportChipsCard\(sports\)"#

        XCTAssertNotNil(
            source.range(of: preferredSportsLink, options: .regularExpression),
            "The preferred sports card should navigate directly to EditPreferredSportsView."
        )
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
