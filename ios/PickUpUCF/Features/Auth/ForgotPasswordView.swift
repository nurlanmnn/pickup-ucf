import SwiftUI

struct ForgotPasswordView: View {
    @State private var email = ""
    @State private var isLoading = false
    @State private var didSend = false
    @State private var errorMessage: String?
    @State private var showValidationHints = false
    @FocusState private var isEmailFocused: Bool

    private let repository: AuthRepositoryProtocol = AuthRepository()

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.m) {
                InlineFeedbackSection(error: errorMessage)

                if didSend {
                    SuccessBanner(message: "If an account exists for this email, we sent a password reset link.")
                }

                FormCard {
                    FormFieldRow {
                        TextField("UCF email", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($isEmailFocused)
                            .submitLabel(.go)
                            .onSubmit { Task { await sendReset() } }
                    }
                    if showValidationHints, let hint = EmailDomainValidator.validationMessage(for: email) {
                        Text(hint)
                            .font(AppFont.caption())
                            .foregroundStyle(AppColor.destructive)
                            .padding(.horizontal, Spacing.m)
                            .padding(.bottom, Spacing.xs)
                    }
                }

                PrimaryButton(title: "Send reset link", isLoading: isLoading, isEnabled: !isLoading) {
                    Task { await sendReset() }
                }
            }
            .padding(Spacing.m)
        }
        .appScreenBackground()
        .scrollDismissesKeyboard(.interactively)
        .dismissKeyboardOnBackgroundTap()
        .navigationTitle("Forgot password")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            FormKeyboardToolbar(onDone: { isEmailFocused = false })
        }
    }

    @MainActor
    private func sendReset() async {
        errorMessage = nil
        showValidationHints = true
        isEmailFocused = false
        if let err = EmailDomainValidator.validationMessage(for: email) {
            errorMessage = err
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            try await repository.requestPasswordReset(email: email)
            didSend = true
        } catch {
            errorMessage = AppErrorMapper.message(for: error)
        }
    }
}

#Preview {
    NavigationStack { ForgotPasswordView() }
}
