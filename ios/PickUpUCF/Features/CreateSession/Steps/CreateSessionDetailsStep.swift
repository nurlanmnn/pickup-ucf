import SwiftUI

struct CreateSessionDetailsStep: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var viewModel: CreateSessionViewModel

    @FocusState.Binding var focusedField: CreateSessionView.FocusField?
    @State private var showMoreOptions = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            sectionHeader("Details")

            StepperNumberFieldRow(
                title: "Capacity",
                prompt: "2–50 players",
                text: $viewModel.capacityText,
                value: $viewModel.capacity,
                range: 2 ... 50,
                step: 1,
                focus: $focusedField,
                focusValue: .capacity
            )
            .padding(Spacing.m)
            .background(AppColor.surface(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            FormFieldHint(text: "Tap to change defaults.")

            sectionHeader("Skill level")

            skillLevelPicker

            sectionHeader("Notes")

            TextField("Notes (optional)", text: $viewModel.notes, axis: .vertical)
                .lineLimit(2...4)
                .focused($focusedField, equals: .notes)
                .padding(Spacing.m)
                .background(AppColor.surface(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            DisclosureGroup(isExpanded: $showMoreOptions) {
                VStack(alignment: .leading, spacing: Spacing.m) {
                    Toggle("Repeat weekly", isOn: $viewModel.repeatWeekly)

                    if viewModel.repeatWeekly {
                        Stepper("Weeks (2–4): \(viewModel.recurrenceWeekCount)", value: $viewModel.recurrenceWeekCount, in: 2 ... 4)
                        FormFieldHint(text: "Creates \(viewModel.recurrenceWeekCount) sessions, one week apart.")
                    }
                }
                .padding(.top, Spacing.s)
            } label: {
                Text("More options")
                    .font(AppFont.body(.semibold))
                    .foregroundStyle(AppColor.textPrimary(colorScheme))
            }
            .padding(Spacing.m)
            .background(AppColor.surface(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: Spacing.s) {
                Text(viewModel.sessionSummaryLine)
                    .font(AppFont.caption())
                    .foregroundStyle(AppColor.textSecondary(colorScheme))
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.m)
            .background(AppColor.surface(colorScheme).opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(AppFont.headline(.semibold))
            .foregroundStyle(AppColor.textPrimary(colorScheme))
    }

    private var skillLevelPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.s) {
                ForEach(SkillLevel.allCases) { level in
                    skillPill(level)
                }
            }
        }
    }

    private func skillPill(_ level: SkillLevel) -> some View {
        let isSelected = viewModel.skillLevel == level

        return Button {
            viewModel.skillLevel = level
        } label: {
            Text(level.displayName)
                .font(AppFont.caption(.semibold))
                .foregroundStyle(isSelected ? Color.black : AppColor.textPrimary(colorScheme))
                .padding(.horizontal, Spacing.m)
                .padding(.vertical, Spacing.s)
                .background(isSelected ? AppColor.gold : AppColor.surface(colorScheme))
                .overlay {
                    Capsule()
                        .stroke(
                            isSelected ? AppColor.gold : AppColor.textSecondary(colorScheme).opacity(0.25),
                            lineWidth: isSelected ? 0 : 1
                        )
                }
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
