import Foundation

@Observable
final class EditUsernameViewModel {
    var username = ""
    var errorMessage: String?
    var successMessage: String?
    var isLoading = false

    private let repository: ProfileRepositoryProtocol

    init(repository: ProfileRepositoryProtocol = ProfileRepository()) {
        self.repository = repository
    }

    @MainActor
    func loadExistingUsername() async {
        errorMessage = nil
        do {
            let profile = try await repository.fetchCurrentProfile()
            if let existing = profile.username, !existing.isEmpty {
                username = existing
            }
        } catch {
            errorMessage = AppErrorMapper.message(for: error)
        }
    }

    @MainActor
    func save() async -> Bool {
        errorMessage = nil
        successMessage = nil

        if UsernameValidator.validationMessage(for: username) != nil {
            return false
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await repository.updateUsername(username)
            successMessage = "Username saved."
            return true
        } catch {
            errorMessage = AppErrorMapper.message(for: error)
            return false
        }
    }
}
