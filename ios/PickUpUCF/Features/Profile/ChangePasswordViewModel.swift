import Foundation

@Observable
final class ChangePasswordViewModel {
    var currentPassword = ""
    var newPassword = ""
    var confirmPassword = ""
    var errorMessage: String?
    var didSucceed = false
    var isLoading = false

    private let authRepository: AuthRepositoryProtocol

    init(authRepository: AuthRepositoryProtocol = AuthRepository()) {
        self.authRepository = authRepository
    }

    var canSubmit: Bool {
        PasswordValidator.validationMessage(for: newPassword) == nil
            && PasswordValidator.confirmationMessage(password: newPassword, confirm: confirmPassword) == nil
            && !currentPassword.isEmpty
            && !isLoading
    }

    @MainActor
    func updatePassword(email: String) async {
        errorMessage = nil
        didSucceed = false

        if let passwordError = PasswordValidator.validationMessage(for: newPassword) {
            errorMessage = passwordError
            return
        }
        if let confirmError = PasswordValidator.confirmationMessage(password: newPassword, confirm: confirmPassword) {
            errorMessage = confirmError
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await authRepository.changePassword(
                email: email,
                currentPassword: currentPassword,
                newPassword: newPassword
            )
            didSucceed = true
        } catch {
            errorMessage = AppErrorMapper.message(for: error)
        }
    }
}
