import Foundation

@Observable
final class SignUpViewModel {
    var email = ""
    var password = ""
    var confirmPassword = ""
    var displayName = ""
    var errorMessage: String?
    var isLoading = false
    var didSignUp = false

    private let repository: AuthRepositoryProtocol

    init(repository: AuthRepositoryProtocol = AuthRepository()) {
        self.repository = repository
    }

    var canSubmit: Bool {
        EmailDomainValidator.validationMessage(for: email) == nil
            && PasswordValidator.validationMessage(for: password) == nil
            && PasswordValidator.confirmationMessage(password: password, confirm: confirmPassword) == nil
            && !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isLoading
    }

    @MainActor
    func signUp() async {
        errorMessage = nil
        guard canSubmit else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            try await repository.signUp(
                email: email,
                password: password,
                displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            didSignUp = true
        } catch {
            errorMessage = AppErrorMapper.message(for: error)
        }
    }
}
