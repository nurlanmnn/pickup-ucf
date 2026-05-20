import SwiftUI

struct EditUsernameView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = EditUsernameViewModel()
    @FocusState private var isFocused: Bool

    var body: some View {
        Form {
            InlineFeedbackSection(error: viewModel.errorMessage, success: viewModel.successMessage)

            Section {
                TextField("Username", text: $viewModel.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($isFocused)
            } footer: {
                Text(
                    "3–20 characters: letters, numbers, underscore. Shown as @username. "
                        + "This is separate from your display name from sign up."
                )
            }

            Section {
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
                .buttonStyle(.borderless)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Username")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            FormKeyboardToolbar(onDone: { isFocused = false })
        }
        .dismissKeyboardOnBackgroundTap()
        .task {
            await viewModel.loadExistingUsername()
        }
    }
}
