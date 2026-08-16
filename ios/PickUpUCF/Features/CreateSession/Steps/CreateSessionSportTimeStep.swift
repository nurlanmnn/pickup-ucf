import SwiftUI

struct CreateSessionSportTimeStep: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var viewModel: CreateSessionViewModel

    @FocusState.Binding var focusedField: CreateSessionView.FocusField?
    @State private var selectedQuickTime: QuickTimePreset?

    private enum QuickTimePreset: String, CaseIterable {
        case inTwoHours
        case tonightSixPM
        case tomorrowNineAM

        var label: String {
            switch self {
            case .inTwoHours: return "In 2 hours"
            case .tonightSixPM: return "Tonight 6 PM"
            case .tomorrowNineAM: return "Tomorrow 9 AM"
            }
        }
    }

    private var startsAtAllowedRange: ClosedRange<Date> {
        let start = Date()
        let end = Calendar.current.date(byAdding: .hour, value: 48, to: start)
            ?? start.addingTimeInterval(48 * 3600)
        return start...end
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            sectionHeader("What are you playing?")
                .id(CreateSessionScrollAnchor.sport)

            SportPickerSingleSelect(selectedSport: $viewModel.sport) {
                viewModel.markDirty()
                if viewModel.sport != .other {
                    viewModel.customSportName = ""
                }
            }

            if viewModel.sport == .other {
                TextField("Sport name", text: $viewModel.customSportName)
                    .textInputAutocapitalization(.words)
                    .focused($focusedField, equals: .customSportName)
                    .padding(Spacing.m)
                    .background(AppColor.surface(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .onChange(of: viewModel.customSportName) { _, newValue in
                        if newValue.count > 40 {
                            viewModel.customSportName = String(newValue.prefix(40))
                        }
                    }

                if let error = viewModel.sportNameError {
                    FieldErrorLabel(message: error)
                }
            }

            sectionHeader("When")
                .id(CreateSessionScrollAnchor.schedule)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.s) {
                    ForEach(QuickTimePreset.allCases, id: \.self) { preset in
                        QuickTimeChip(
                            label: preset.label,
                            isSelected: selectedQuickTime == preset
                        ) {
                            applyQuickTime(preset)
                        }
                    }
                }
            }

            DatePicker(
                "Starts",
                selection: $viewModel.startsAt,
                in: startsAtAllowedRange
            )
            .datePickerStyle(.compact)
            .onChange(of: viewModel.startsAt) { _, _ in
                selectedQuickTime = nil
            }

            if let error = viewModel.scheduleError {
                FieldErrorLabel(message: error)
            }

            StepperNumberFieldRow(
                title: "Duration",
                prompt: "15–300 min",
                text: $viewModel.durationText,
                value: $viewModel.durationMinutes,
                range: 15 ... 300,
                step: 5,
                focus: $focusedField,
                focusValue: .duration
            )
            .padding(Spacing.m)
            .background(AppColor.surface(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            FormFieldHint(text: "Tap to change defaults.")
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(AppFont.headline(.semibold))
            .foregroundStyle(AppColor.textPrimary(colorScheme))
    }

    private func applyQuickTime(_ preset: QuickTimePreset) {
        selectedQuickTime = preset
        switch preset {
        case .inTwoHours:
            viewModel.startsAt = CreateSessionViewModel.inTwoHours()
        case .tonightSixPM:
            viewModel.startsAt = CreateSessionViewModel.tonightAtSixPM()
        case .tomorrowNineAM:
            viewModel.startsAt = CreateSessionViewModel.tomorrowAtNineAM()
        }
    }
}
