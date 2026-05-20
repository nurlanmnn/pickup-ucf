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

        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            errorMessage = "Display name is required"
            return
        }
        if let emailError = EmailDomainValidator.validationMessage(for: email) {
            errorMessage = emailError
            return
        }
        if let passwordError = PasswordValidator.validationMessage(for: password) {
            errorMessage = passwordError
            return
        }
        if let confirmError = PasswordValidator.confirmationMessage(password: password, confirm: confirmPassword) {
            errorMessage = confirmError
            return
        }

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
