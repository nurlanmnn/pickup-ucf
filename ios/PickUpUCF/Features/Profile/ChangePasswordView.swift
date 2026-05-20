import SwiftUI

struct ChangePasswordView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = ChangePasswordViewModel()
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case current, new, confirm }

    var body: some View {
        Form {
            InlineFeedbackSection(
                error: viewModel.errorMessage,
                success: viewModel.didSucceed ? "Password updated successfully." : nil
            )

            Section {
                SecureField("Current password", text: $viewModel.currentPassword)
                    .textContentType(.password)
                    .focused($focusedField, equals: .current)
                SecureField("New password", text: $viewModel.newPassword)
                    .textContentType(.newPassword)
                    .focused($focusedField, equals: .new)
                SecureField("Confirm new password", text: $viewModel.confirmPassword)
                    .textContentType(.newPassword)
                    .focused($focusedField, equals: .confirm)

                if let hint = PasswordValidator.validationMessage(for: viewModel.newPassword) {
                    Text(hint)
                        .font(AppFont.caption())
                        .foregroundStyle(AppColor.destructive)
                }
            }

            Section {
                PrimaryButton(
                    title: "Update password",
                    isLoading: viewModel.isLoading,
                    isEnabled: !viewModel.isLoading
                ) {
                    Task { await submit() }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Change password")
        .navigationBarTitleDisplayMode(.inline)
        .dismissKeyboardOnBackgroundTap()
        .scrollDismissesKeyboard(.interactively)
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
