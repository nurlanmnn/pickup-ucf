import Foundation

@Observable
final class EditPreferredSportsViewModel {
    var selectedSports: Set<SportType> = []
    var errorMessage: String?
    var successMessage: String?
    var isLoading = false

    private let repository: ProfileRepositoryProtocol

    init(repository: ProfileRepositoryProtocol = ProfileRepository()) {
        self.repository = repository
    }

    var canSave: Bool {
        !selectedSports.isEmpty && !isLoading
    }

    func isSelected(_ sport: SportType) -> Bool {
        selectedSports.contains(sport)
    }

    func toggleSport(_ sport: SportType) {
        if selectedSports.contains(sport) {
            selectedSports.remove(sport)
        } else {
            selectedSports.insert(sport)
        }
    }

    @MainActor
    func loadExistingSports() async {
        errorMessage = nil
        do {
            let profile = try await repository.fetchCurrentProfile()
            selectedSports = Set(profile.preferredSports)
        } catch {
            errorMessage = AppErrorMapper.message(for: error)
        }
    }

    @MainActor
    func save() async -> Bool {
        errorMessage = nil
        successMessage = nil

        guard !selectedSports.isEmpty else {
            errorMessage = "Select at least one sport"
            return false
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await repository.updatePreferredSports(
                selectedSports.sorted { $0.displayName < $1.displayName }
            )
            successMessage = "Sports saved."
            return true
        } catch {
            errorMessage = AppErrorMapper.message(for: error)
            return false
        }
    }
}
