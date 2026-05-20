import SwiftUI

struct DeleteAccountView: View {
    @Environment(AppState.self) private var appState
    @State private var confirmation = ""
    @State private var isDeleting = false
    @State private var errorMessage: String?

    private let profileRepository: ProfileRepositoryProtocol
    private let authRepository: AuthRepositoryProtocol

    init(
        profileRepository: ProfileRepositoryProtocol = ProfileRepository(),
        authRepository: AuthRepositoryProtocol = AuthRepository()
    ) {
        self.profileRepository = profileRepository
        self.authRepository = authRepository
    }

    var body: some View {
        Form {
            Section {
                Text("This permanently deletes your profile, messages, and game history. Open sessions you host will be cancelled.")
                    .font(AppFont.body())
            }

            InlineFeedbackSection(error: errorMessage)

            Section {
                TextField("Type DELETE to confirm", text: $confirmation)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
            }

            Section {
                Button(role: .destructive) {
                    Task { await deleteAccount() }
                } label: {
                    HStack {
                        Spacer()
                        if isDeleting {
                            ProgressView()
                        } else {
                            Text("Delete account")
                        }
                        Spacer()
                    }
                }
                .disabled(confirmation != "DELETE" || isDeleting)
            }
        }
        .navigationTitle("Delete account")
        .navigationBarTitleDisplayMode(.inline)
    }

    @MainActor
    private func deleteAccount() async {
        errorMessage = nil
        isDeleting = true
        defer { isDeleting = false }

        do {
            try await profileRepository.deleteAccount()
            try await authRepository.signOut()
            appState.session = nil
        } catch {
            errorMessage = AppErrorMapper.message(for: error)
        }
    }
}
