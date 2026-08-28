import SwiftUI

struct EditUsernameView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = EditUsernameViewModel()
    @State private var showFieldHints = false
    @FocusState private var isFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.m) {
                InlineFeedbackSection(error: viewModel.errorMessage, success: viewModel.successMessage)

                FormCard(footer: usernameFooter) {
                    FormFieldRow {
                        TextField("Username", text: $viewModel.username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($isFocused)
                    }
                    if showFieldHints, let hint = UsernameValidator.validationMessage(for: viewModel.username) {
                        FieldErrorLabel(message: hint).formCardInset()
                    }
                }

                PrimaryButton(
                    title: "Save",
                    isLoading: viewModel.isLoading,
                    isEnabled: !viewModel.isLoading
                ) {
                    Task {
                        showFieldHints = true
                        isFocused = false
                        if await viewModel.save() {
                            appState.touchProfileRefresh()
                            try? await Task.sleep(for: .seconds(0.6))
                            dismiss()
                        }
                    }
                }
            }
            .padding(Spacing.m)
        }
        .appScreenBackground()
        .dismissKeyboardOnBackgroundTap()
        .navigationTitle("Username")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            FormKeyboardToolbar(onDone: { isFocused = false })
        }
        .task { await viewModel.loadExistingUsername() }
    }

    private var usernameFooter: String? {
        showFieldHints && UsernameValidator.validationMessage(for: viewModel.username) != nil
            ? nil
            : "3–20 characters: letters, numbers, underscore. Shown as @username."
    }
}
