import SwiftUI

struct OnboardingView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppState.self) private var appState
    @State private var viewModel = OnboardingViewModel()

    var body: some View {
        @Bindable var vm = viewModel

        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                header

                if let error = vm.errorMessage {
                    ErrorBanner(message: error)
                }

                sportsSection(vm: vm)

                PrimaryButton(
                    title: "Get started",
                    isLoading: vm.isLoading,
                    isEnabled: vm.canSubmit
                ) {
                    Task {
                        await vm.submit(appState: appState)
                    }
                }
            }
            .padding(Spacing.l)
        }
        .appScreenBackground()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("Welcome to PickUp UCF")
                .font(AppFont.title(.bold))
                .foregroundStyle(AppColor.textPrimary(colorScheme))

            Text("Tell us what you play so we can surface the right games on campus.")
                .font(AppFont.body())
                .foregroundStyle(AppColor.textSecondary(colorScheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sportsSection(vm: OnboardingViewModel) -> some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            sectionTitle("Preferred sports")
            Text("Pick one or more")
                .font(AppFont.caption())
                .foregroundStyle(AppColor.textSecondary(colorScheme))

            SportPickerGrid(
                selectedSports: vm.selectedSports,
                onToggle: { vm.toggleSport($0) }
            )
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(AppFont.headline(.semibold))
            .foregroundStyle(AppColor.textPrimary(colorScheme))
    }
}

#Preview {
    OnboardingView()
        .environment(AppState())
}
