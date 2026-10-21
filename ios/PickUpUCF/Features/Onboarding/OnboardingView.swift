import SwiftUI

struct OnboardingView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppState.self) private var appState
    @State private var showSignOutConfirm = false
    @State private var isSigningOut = false
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

            }
            .padding(Spacing.l)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: Spacing.s) {
                Text(vm.selectedSports.isEmpty
                     ? "Choose at least one sport to continue."
                     : "\(vm.selectedSports.count) selected · Change these anytime in Profile.")
                    .font(AppFont.caption())
                    .foregroundStyle(AppColor.textSecondary(colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
                PrimaryButton(title: "Get started", isLoading: vm.isLoading, isEnabled: vm.canSubmit && !isSigningOut) {
                    Task { await vm.submit(appState: appState) }
                }
                .accessibilityIdentifier("onboarding-continue")
            }
            .padding(Spacing.m)
            .background(AppColor.background(colorScheme))
            .overlay(alignment: .top) { Divider() }
        }
        .appScreenBackground()
        .confirmationDialog("Sign out and use a different account?", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) {
                Task {
                    isSigningOut = true
                    let outcome = await AccountTransitionCoordinator.signOut(
                        appState: appState,
                        unregisterToken: { try await PushNotificationService.shared.unregisterForAccountTransition() },
                        signOut: { try await AuthRepository().signOut() }
                    )
                    if outcome.hasWarning {
                        appState.showError("You’re signed out. Some server cleanup could not be confirmed.")
                    }
                    isSigningOut = false
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            AppBrandLockup()
                .padding(.bottom, Spacing.m)

            Button("Use a different account") { showSignOutConfirm = true }
                .font(AppFont.caption(.semibold))
                .frame(minHeight: AccessibilityLayout.minimumTouchTarget)
                .disabled(viewModel.isLoading || isSigningOut)

            Text("What do you love to play?")
                .font(AppFont.display())
                .accessibilityAddTraits(.isHeader)
                .foregroundStyle(AppColor.textPrimary(colorScheme))

            Text("Pick your favorites. We’ll help you find your next game on campus.")
                .font(AppFont.body())
                .foregroundStyle(AppColor.textSecondary(colorScheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sportsSection(vm: OnboardingViewModel) -> some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            sectionTitle("Your sports")
            Text("Pick one or more")
                .font(AppFont.caption())
                .foregroundStyle(AppColor.textSecondary(colorScheme))

            SportPickerGrid(
                selectedSports: vm.selectedSports,
                onToggle: { vm.toggleSport($0) }
            )
            .disabled(vm.isLoading || isSigningOut)
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
