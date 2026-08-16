import SwiftUI

struct EditPreferredSportsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = EditPreferredSportsViewModel()

    var body: some View {
        @Bindable var vm = viewModel

        ScrollView {
            VStack(spacing: Spacing.m) {
                InlineFeedbackSection(error: vm.errorMessage, success: vm.successMessage)

                FormCard(footer: "Pick one or more sports you play on campus.") {
                    SportPickerGrid(
                        selectedSports: vm.selectedSports,
                        onToggle: { vm.toggleSport($0) }
                    )
                    .padding(Spacing.m)
                }

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
            }
            .padding(Spacing.m)
        }
        .appScreenBackground()
        .navigationTitle("Edit sports")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadExistingSports() }
    }
}

#Preview {
    NavigationStack {
        EditPreferredSportsView()
            .environment(AppState())
    }
}
