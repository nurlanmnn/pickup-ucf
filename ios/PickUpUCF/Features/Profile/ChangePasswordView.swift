import SwiftUI

struct ChangePasswordView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = ChangePasswordViewModel()
    @State private var showFieldHints = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case current, new, confirm }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.m) {
                InlineFeedbackSection(
                    error: viewModel.errorMessage,
                    success: viewModel.didSucceed ? "Password updated successfully." : nil
                )

                FormCard {
                    FormFieldRow {
                        SecureField("Current password", text: $viewModel.currentPassword)
                            .textContentType(.password)
                            .focused($focusedField, equals: .current)
                    }
                    if showFieldHints, viewModel.currentPassword.isEmpty {
                        FieldErrorLabel(message: "Current password is required").formCardInset()
                    }
                    Divider().padding(.leading, Spacing.m)
                    FormFieldRow {
                        SecureField("New password", text: $viewModel.newPassword)
                            .textContentType(.newPassword)
                            .focused($focusedField, equals: .new)
                    }
                    if showFieldHints, let hint = PasswordValidator.validationMessage(for: viewModel.newPassword) {
                        FieldErrorLabel(message: hint).formCardInset()
                    }
                    Divider().padding(.leading, Spacing.m)
                    FormFieldRow {
                        SecureField("Confirm new password", text: $viewModel.confirmPassword)
                            .textContentType(.newPassword)
                            .focused($focusedField, equals: .confirm)
                    }
                    if showFieldHints, let hint = PasswordValidator.confirmationMessage(
                        password: viewModel.newPassword,
                        confirm: viewModel.confirmPassword
                    ) {
                        FieldErrorLabel(message: hint).formCardInset()
                    }
                }

                PrimaryButton(
                    title: "Update password",
                    isLoading: viewModel.isLoading,
                    isEnabled: !viewModel.isLoading
                ) {
                    Task { await submit() }
                }
            }
            .padding(Spacing.m)
        }
        .appScreenBackground()
        .dismissKeyboardOnBackgroundTap()
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Change password")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            FormKeyboardToolbar(
                canGoPrevious: focusedField != .current,
                canGoNext: focusedField != .confirm,
                onPrevious: { focusPrevious() },
                onNext: { focusNext() },
                onDone: { focusedField = nil }
            )
        }
    }

    @MainActor
    private func submit() async {
        guard let email = appState.session?.email else {
            viewModel.errorMessage = "Please sign in again to change your password."
            return
        }
        focusedField = nil
        showFieldHints = true
        await viewModel.updatePassword(email: email)
    }

    private func focusNext() {
        switch focusedField {
        case .current: focusedField = .new
        case .new: focusedField = .confirm
        default: break
        }
    }

    private func focusPrevious() {
        switch focusedField {
        case .confirm: focusedField = .new
        case .new: focusedField = .current
        default: break
        }
    }
}
