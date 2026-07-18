import SwiftUI

struct EditPreferredSportsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = EditPreferredSportsViewModel()

    var body: some View {
        @Bindable var vm = viewModel

        Form {
            InlineFeedbackSection(error: vm.errorMessage, success: vm.successMessage)

            Section {
                SportPickerGrid(
                    selectedSports: vm.selectedSports,
                    onToggle: { vm.toggleSport($0) }
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            } footer: {
                Text("Pick one or more sports you play on campus.")
            }

            Section {
                PrimaryButton(
                    title: "Save",
                    isLoading: vm.isLoading,
                    isEnabled: vm.canSave
                ) {
                    Task {
                        if await vm.save() {
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
        .navigationTitle("Edit sports")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadExistingSports()
        }
    }
}

#Preview {
    NavigationStack {
        EditPreferredSportsView()
            .environment(AppState())
    }
}
