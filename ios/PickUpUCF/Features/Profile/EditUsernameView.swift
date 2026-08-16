import SwiftUI

struct EditUsernameView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = EditUsernameViewModel()
    @FocusState private var isFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.m) {
                InlineFeedbackSection(error: viewModel.errorMessage, success: viewModel.successMessage)

                FormCard(footer: "3–20 characters: letters, numbers, underscore. Shown as @username.") {
                    FormFieldRow {
                        TextField("Username", text: $viewModel.username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($isFocused)
                    }
                }

                PrimaryButton(
                    title: "Save",
                    isLoading: viewModel.isLoading,
                    isEnabled: !viewModel.isLoading
                ) {
                    Task {
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
}
