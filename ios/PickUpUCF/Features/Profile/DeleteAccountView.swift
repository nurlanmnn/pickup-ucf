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
        ScrollView {
            VStack(spacing: Spacing.m) {
                // Warning card
                HStack(alignment: .top, spacing: Spacing.s) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(AppColor.destructive)
                        .font(.system(size: 16, weight: .semibold))
                    Text("This permanently deletes your profile, messages, and game history. Open sessions you host will be cancelled.")
                        .font(AppFont.body())
                        .foregroundStyle(.primary)
                }
                .padding(Spacing.m)
                .background(AppColor.destructive.opacity(0.07))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppColor.destructive.opacity(0.20), lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                InlineFeedbackSection(error: errorMessage)

                FormCard(footer: "Type DELETE in all caps to enable the button.") {
                    FormFieldRow {
                        TextField("Type DELETE to confirm", text: $confirmation)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                    }
                }

                Button(role: .destructive) {
                    Task { await deleteAccount() }
                } label: {
                    Group {
                        if isDeleting {
                            ProgressView().tint(.white)
                        } else {
                            Text("Delete account")
                                .font(AppFont.body(.semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .foregroundStyle(.white)
                    .background(confirmation == "DELETE" ? AppColor.destructive : AppColor.destructive.opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(confirmation != "DELETE" || isDeleting)
            }
            .padding(Spacing.m)
        }
        .appScreenBackground()
        .dismissKeyboardOnBackgroundTap()
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
