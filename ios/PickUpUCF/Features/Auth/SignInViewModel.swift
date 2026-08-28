import Foundation

@Observable
final class SignInViewModel {
    var email = ""
    var password = ""
    var errorMessage: String?
    var isLoading = false
    var needsEmailVerification = false

    private let repository: AuthRepositoryProtocol
    private let profileRepository: ProfileRepositoryProtocol

    init(
        repository: AuthRepositoryProtocol = AuthRepository(),
        profileRepository: ProfileRepositoryProtocol = ProfileRepository()
    ) {
        self.repository = repository
        self.profileRepository = profileRepository
    }

    var canSubmit: Bool {
        EmailDomainValidator.validationMessage(for: email) == nil
            && !password.isEmpty
            && !isLoading
    }

    @MainActor
    func signIn(appState: AppState) async {
        errorMessage = nil
        needsEmailVerification = false
        guard canSubmit else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let session = try await repository.signIn(email: email, password: password)
            await AuthenticatedSessionCoordinator.bootstrap(session: session, appState: appState)
        } catch AuthRepositoryError.emailNotConfirmed {
            needsEmailVerification = true
        } catch {
            errorMessage = AppErrorMapper.message(for: error)
        }
    }
}
