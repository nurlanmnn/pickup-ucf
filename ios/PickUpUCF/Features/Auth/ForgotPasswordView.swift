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

/// Presented only after the provider has accepted this install's PKCE exchange.
struct ResetPasswordView: View {
    let userId: UUID
    @Environment(AppState.self) private var appState
    @State private var model = ResetPasswordViewModel()
    @State private var showHints = false
    @FocusState private var focusedField: Field?
    private enum Field: Hashable { case password, confirmation }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.m) {
                AuthHeaderView(title: "Choose a new password", subtitle: "Save a new password for your verified account.")
                InlineFeedbackSection(error: model.errorMessage)
                FormCard {
                    FormFieldRow {
                        SecureField("New password", text: $model.password)
                            .textContentType(.newPassword)
                            .focused($focusedField, equals: .password)
                    }
                    if showHints, let hint = PasswordValidator.validationMessage(for: model.password) {
                        FieldErrorLabel(message: hint).formCardInset()
                    }
                    Divider().padding(.leading, Spacing.m)
                    FormFieldRow {
                        SecureField("Confirm new password", text: $model.confirmation)
                            .textContentType(.newPassword)
                            .focused($focusedField, equals: .confirmation)
                    }
                    if showHints, let hint = PasswordValidator.confirmationMessage(password: model.password, confirm: model.confirmation) {
                        FieldErrorLabel(message: hint).formCardInset()
                    }
                }
                .disabled(model.isLoading)
                PrimaryButton(title: "Save new password", isLoading: model.isLoading, isEnabled: !model.isLoading) {
                    showHints = true
                    focusedField = nil
                    Task {
                        guard appState.session?.userId == userId,
                              appState.passwordRecoveryUserId == userId else { return }
                        await model.save()
                        guard model.didSucceed, appState.session?.userId == userId else { return }
                        appState.passwordRecoveryUserId = nil
                        appState.showSuccess("Password updated")
                    }
                }
            }
            .padding(Spacing.m)
        }
        .appScreenBackground()
        .scrollDismissesKeyboard(.interactively)
        .dismissKeyboardOnBackgroundTap()
        .formKeyboardAccessory(isPresented: focusedField != nil, onDone: { focusedField = nil })
        .navigationTitle("Reset password")
        .navigationBarTitleDisplayMode(.inline)
    }
}

@Observable
final class ResetPasswordViewModel {
    var password = ""
    var confirmation = ""
    var isLoading = false
    var didSucceed = false
    var errorMessage: String?
    private let repository: AuthRepositoryProtocol

    init(repository: AuthRepositoryProtocol = AuthRepository()) {
        self.repository = repository
    }

    @MainActor
    func save() async {
        guard !isLoading else { return }
        didSucceed = false
        errorMessage = PasswordValidator.validationMessage(for: password)
            ?? PasswordValidator.confirmationMessage(password: password, confirm: confirmation)
        guard errorMessage == nil else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            try await repository.updatePassword(password)
            password = ""
            confirmation = ""
            didSucceed = true
        } catch {
            errorMessage = AppErrorMapper.message(for: error)
        }
    }
}
