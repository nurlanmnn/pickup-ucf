import Foundation

@Observable
final class OnboardingViewModel {
    var selectedSports: Set<SportType> = []
    var errorMessage: String?
    var isLoading = false

    private let repository: ProfileRepositoryProtocol

    init(repository: ProfileRepositoryProtocol = ProfileRepository()) {
        self.repository = repository
    }

    var canSubmit: Bool {
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
    func submit(appState: AppState) async {
        errorMessage = nil

        guard !selectedSports.isEmpty else {
            errorMessage = "Select at least one sport"
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await repository.completeOnboarding(
                sports: selectedSports.sorted { $0.displayName < $1.displayName }
            )
            appState.needsOnboarding = false
            appState.touchProfileRefresh()
        } catch {
            errorMessage = AppErrorMapper.message(for: error)
        }
    }
}
