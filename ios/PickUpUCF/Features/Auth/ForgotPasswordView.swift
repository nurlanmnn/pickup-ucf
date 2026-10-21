import SwiftUI

struct ForgotPasswordView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var email: String
    @State private var isLoading = false
    @State private var didSend = false
    @State private var errorMessage: String?
    @State private var showValidationHints = false
    @FocusState private var isEmailFocused: Bool

    private let repository: AuthRepositoryProtocol = AuthRepository()

    init(email: String = "") {
        _email = State(initialValue: email)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.m) {
                AuthHeaderView(
                    title: "Reset Password",
                    subtitle: "Enter your UCF email and we'll send a reset link."
                )

                InlineFeedbackSection(error: errorMessage)

                if didSend {
                    SuccessBanner(message: "If an account exists for this email, we sent a password reset link.")
                }

                FormCard {
                    FormFieldRow {
                        TextField("UCF email", text: $email, prompt: Text("UCF email").foregroundColor(AppColor.textSecondary(colorScheme)))
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($isEmailFocused)
                            .submitLabel(.go)
                            .onSubmit { Task { await sendReset() } }
                    }
                    if showValidationHints, let hint = EmailDomainValidator.validationMessage(for: email) {
                        FieldErrorLabel(message: hint).formCardInset()
                    }
                }

                .disabled(isLoading)

                PrimaryButton(title: didSend ? "Send another link" : "Send reset link", isLoading: isLoading, isEnabled: !isLoading) {
                    Task { await sendReset() }
                }
                SecondaryButton(title: "Back to sign in") { dismiss() }
                    .disabled(isLoading)
                    .accessibilityIdentifier("reset-back-to-sign-in")
            }
            .padding(Spacing.m)
        }
        .appScreenBackground()
        .toolbarBackground(.hidden, for: .navigationBar)
        .scrollDismissesKeyboard(.interactively)
        .dismissKeyboardOnBackgroundTap()
        .onChange(of: email) { _, _ in
            didSend = false
            errorMessage = nil
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .formKeyboardAccessory(
            isPresented: isEmailFocused,
            onDone: { isEmailFocused = false }
        )
    }

    @MainActor
    private func sendReset() async {
        guard !isLoading else { return }
        errorMessage = nil
        showValidationHints = true
        isEmailFocused = false
        if EmailDomainValidator.validationMessage(for: email) != nil {
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
