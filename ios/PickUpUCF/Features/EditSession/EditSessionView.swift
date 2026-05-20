import SwiftUI

struct EditSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: EditSessionViewModel
    var onSaved: ((PickupSession) -> Void)?

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

    init(session: PickupSession, onSaved: ((PickupSession) -> Void)? = nil) {
        _viewModel = State(initialValue: EditSessionViewModel(session: session))
        self.onSaved = onSaved
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
            } footer: {
                FormFieldHint(text: "15–300 minutes. Type a number or use the stepper.")
            }

            Section("Where") {
                Picker("Venue", selection: $vm.venuePickerOptionId) {
                    Text("Custom location").tag(EditSessionViewModel.customVenuePickerTag)
                    ForEach(vm.venues) { venue in
                        Text(venue.name).tag(venue.id.uuidString)
                    }
                }
                .pickerStyle(.menu)

                if vm.showsCustomLocationField {
                    TextField("Describe where you’re playing", text: $vm.customLocation)
                }
            }

            Section {
                StepperNumberFieldRow(
                    title: "Capacity",
                    prompt: "2–50 players",
                    text: $vm.capacityText,
                    value: $vm.capacity,
                    range: max(2, vm.minimumCapacity) ... 50,
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
                FormFieldHint(text: "Capacity must be at least \(vm.minimumCapacity) (current sign-ups).")
            }

            Section {
                PrimaryButton(
                    title: "Save changes",
                    isLoading: vm.isLoading,
                    isEnabled: vm.canSubmit && !vm.isLoading
                ) {
                    Task { await submit() }
                }
                .buttonStyle(.borderless)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Edit session")
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
        if let session = await viewModel.save() {
            onSaved?(session)
            dismiss()
        }
    }
}
