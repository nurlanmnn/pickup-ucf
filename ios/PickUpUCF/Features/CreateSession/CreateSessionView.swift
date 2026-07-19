import SwiftUI

struct CreateSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: CreateSessionViewModel
    var onCreated: ((PickupSession) -> Void)?

    init(prefill: CreateSessionPrefill? = nil, onCreated: ((PickupSession) -> Void)? = nil) {
        let model = CreateSessionViewModel()
        if let prefill {
            model.applyPrefill(prefill)
        }
        _viewModel = State(initialValue: model)
        self.onCreated = onCreated
    }

    private enum NumericField: Hashable {
        case duration
        case capacity
    }

    @FocusState private var focusedNumeric: NumericField?

    private var startsAtAllowedRange: ClosedRange<Date> {
        let start = Date()
        let end = Calendar.current.date(byAdding: .hour, value: 48, to: start)
            ?? start.addingTimeInterval(48 * 3600)
        return start...end
    }

    var body: some View {
        @Bindable var vm = viewModel
        Form {
            InlineFeedbackSection(error: vm.errorMessage)

            Section("Sport") {
                Picker("Sport", selection: $vm.sport) {
                    ForEach(SportType.allCases) { sport in
                        Text(sport.displayName).tag(sport)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: vm.sport) { _, newSport in
                    if newSport != .other {
                        vm.customSportName = ""
                    }
                }

                if vm.sport == .other {
                    TextField("Sport name", text: $vm.customSportName)
                        .textInputAutocapitalization(.words)
                        .onChange(of: vm.customSportName) { _, newValue in
                            if newValue.count > 40 {
                                vm.customSportName = String(newValue.prefix(40))
                            }
                        }
                }
            }

            Section {
                DatePicker("Starts", selection: $vm.startsAt, in: startsAtAllowedRange)

                StepperNumberFieldRow(
                    title: "Duration",
                    prompt: "15–300 min",
                    text: $vm.durationText,
                    value: $vm.durationMinutes,
                    range: 15 ... 300,
                    step: 5,
                    focus: $focusedNumeric,
                    focusValue: .duration
                )
            } header: {
                Text("When")
            }

            Section {
                Picker("Venue", selection: $vm.venuePickerOptionId) {
                    Text("Custom location").tag(CreateSessionViewModel.customVenuePickerTag)
                    ForEach(vm.venues) { venue in
                        Text(venue.name).tag(venue.id.uuidString)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: vm.venuePickerOptionId) { _, newValue in
                    if newValue != CreateSessionViewModel.customVenuePickerTag {
                        vm.customLocationSelection = nil
                    }
                }

                if vm.showsCustomLocationField {
                    CustomLocationPickerRow(selection: $vm.customLocationSelection)
                }
            } header: {
                Text("Where")
            } footer: {
                if vm.showsCustomLocationField {
                    FormFieldHint(text: "Search near campus or tap the map to drop a pin.")
                }
            }

            Section {
                Toggle("Repeat weekly", isOn: $vm.repeatWeekly)

                if vm.repeatWeekly {
                    Stepper("Weeks (2–4): \(vm.recurrenceWeekCount)", value: $vm.recurrenceWeekCount, in: 2 ... 4)
                }
            } header: {
                Text("Repeat")
            } footer: {
                if vm.repeatWeekly {
                    FormFieldHint(text: "Creates \(vm.recurrenceWeekCount) sessions, one week apart.")
                }
            }

            Section {
                StepperNumberFieldRow(
                    title: "Capacity",
                    prompt: "2–50 players",
                    text: $vm.capacityText,
                    value: $vm.capacity,
                    range: 2 ... 50,
                    step: 1,
                    focus: $focusedNumeric,
                    focusValue: .capacity
                )

                Picker("Skill level", selection: $vm.skillLevel) {
                    ForEach(SkillLevel.allCases) { level in
                        Text(level.displayName).tag(level)
                    }
                }
                .pickerStyle(.menu)

                TextField("Notes (optional)", text: $vm.notes, axis: .vertical)
                    .lineLimit(2...4)
            } header: {
                Text("Details")
            } footer: {
                FormFieldHint(text: "Defaults: 90 min · 10 players when the fields are empty.")
            }

            Section {
                PrimaryButton(
                    title: "Create session",
                    isLoading: vm.isLoading,
                    isEnabled: !vm.isLoading
                ) {
                    Task { await submit() }
                }
                .buttonStyle(.borderless)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Create session")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    viewModel.commitDurationFromText()
                    viewModel.commitCapacityFromText()
                    focusedNumeric = nil
                }
                .fontWeight(.semibold)
            }
        }
        .task {
            await viewModel.loadVenues()
            await viewModel.hydrateCustomLocationIfNeeded()
        }
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: focusedNumeric) { _, newValue in
            if newValue != .duration { viewModel.commitDurationFromText() }
            if newValue != .capacity { viewModel.commitCapacityFromText() }
        }
    }

    @MainActor
    private func submit() async {
        viewModel.commitDurationFromText()
        viewModel.commitCapacityFromText()
        focusedNumeric = nil
        if let session = await viewModel.create() {
            onCreated?(session)
            dismiss()
        }
    }
}

#Preview {
    NavigationStack {
        CreateSessionView()
    }
}
