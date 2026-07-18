import SwiftUI

struct OnboardingView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppState.self) private var appState
    @State private var viewModel = OnboardingViewModel()

    private let sportColumns = [
        GridItem(.adaptive(minimum: 104), spacing: Spacing.s),
    ]

    var body: some View {
        @Bindable var vm = viewModel

        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                header

                if let error = vm.errorMessage {
                    ErrorBanner(message: error)
                }

                sportsSection(vm: vm)
                skillSection(skillLevel: $vm.skillLevel)

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
        .background(AppColor.background(colorScheme))
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

            LazyVGrid(columns: sportColumns, spacing: Spacing.s) {
                ForEach(SportType.allCases) { sport in
                    OnboardingSportChip(
                        sport: sport,
                        isSelected: vm.isSelected(sport)
                    ) {
                        vm.toggleSport(sport)
                    }
                }
            }
        }
    }

    private func skillSection(skillLevel: Binding<SkillLevel>) -> some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            sectionTitle("Your skill level")
            Text("We'll use this as your default when browsing games.")
                .font(AppFont.caption())
                .foregroundStyle(AppColor.textSecondary(colorScheme))

            Picker("Skill level", selection: skillLevel) {
                ForEach(OnboardingViewModel.onboardingSkillLevels) { level in
                    Text(level.displayName).tag(level)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(AppFont.headline(.semibold))
            .foregroundStyle(AppColor.textPrimary(colorScheme))
    }
}

private struct OnboardingSportChip: View {
    @Environment(\.colorScheme) private var colorScheme

    let sport: SportType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.s) {
                Image(systemName: sport.systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.black : AppColor.sportAccent(sport))

                Text(sport.displayName)
                    .font(AppFont.caption(.semibold))
                    .foregroundStyle(isSelected ? Color.black : AppColor.textPrimary(colorScheme))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.m)
            .padding(.horizontal, Spacing.s)
            .background(isSelected ? AppColor.gold : AppColor.surface(colorScheme))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isSelected ? AppColor.gold : AppColor.textSecondary(colorScheme).opacity(0.25),
                        lineWidth: isSelected ? 0 : 1
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityLabel(sport.displayName)
    }
}

#Preview {
    OnboardingView()
        .environment(AppState())
}
