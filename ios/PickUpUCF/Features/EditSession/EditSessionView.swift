import SwiftUI

struct EditSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: EditSessionViewModel
    @State private var showDiscardDialog = false
    @State private var scrollToAnchor: EditSessionScrollAnchor?
    var onSaved: ((PickupSession) -> Void)?

    private enum FocusField: Hashable {
        case customSportName
        case duration
        case capacity
        case notes
    }

    @FocusState private var focusedField: FocusField?

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
        ScrollViewReader { proxy in
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
                        vm.markDirty()
                        if newSport != .other {
                            vm.customSportName = ""
                        }
                    }

                    if vm.sport == .other {
                        TextField("Sport name", text: $vm.customSportName)
                            .textInputAutocapitalization(.words)
                            .focused($focusedField, equals: .customSportName)
                            .onChange(of: vm.customSportName) { _, newValue in
                                vm.markDirty()
                                if newValue.count > 40 {
                                    vm.customSportName = String(newValue.prefix(40))
                                }
                            }

                        if let error = vm.sportNameError {
                            FieldErrorLabel(message: error)
                        }
                    }
                }
                .id(EditSessionScrollAnchor.sport)

                Section {
                    DatePicker("Starts", selection: $vm.startsAt, in: startsAtAllowedRange)
                        .onChange(of: vm.startsAt) { _, _ in vm.markDirty() }

                    StepperNumberFieldRow(
                        title: "Duration",
                        prompt: "15–300 min",
                        text: $vm.durationText,
                        value: $vm.durationMinutes,
                        range: 15 ... 300,
                        step: 5,
                        focus: $focusedField,
                        focusValue: .duration
                    )

                    if let error = vm.scheduleError {
                        FieldErrorLabel(message: error)
                    }
                } header: {
                    Text("When")
                } footer: {
                    FormFieldHint(text: "15–300 minutes. Type a number or use the stepper.")
                }
                .id(EditSessionScrollAnchor.schedule)

                Section {
                    if vm.venues.isEmpty {
                        HStack(spacing: Spacing.s) {
                            ProgressView()
                            Text("Loading venues…")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Picker("Venue", selection: $vm.venuePickerOptionId) {
                            Text("Custom location").tag(EditSessionViewModel.customVenuePickerTag)
                            ForEach(vm.venues) { venue in
                                Text(venue.name).tag(venue.id.uuidString)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: vm.venuePickerOptionId) { _, newValue in
                            vm.markDirty()
                            if newValue != EditSessionViewModel.customVenuePickerTag {
                                vm.customLocationSelection = nil
                            }
                        }
                    }

                    if vm.showsCustomLocationField {
                        CustomLocationPickerRow(selection: $vm.customLocationSelection)
                            .onChange(of: vm.customLocationSelection) { _, _ in vm.markDirty() }
                    }

                    if let error = vm.locationError {
                        FieldErrorLabel(message: error)
                    }
                } header: {
                    Text("Where")
                } footer: {
                    if vm.showsCustomLocationField {
                        FormFieldHint(text: "Search near campus or tap the map to drop a pin.")
                    }
                }
                .id(EditSessionScrollAnchor.location)

                Section {
                    StepperNumberFieldRow(
                        title: "Capacity",
                        prompt: "2–50 players",
                        text: $vm.capacityText,
                        value: $vm.capacity,
                        range: max(2, vm.minimumCapacity) ... 50,
                        step: 1,
                        focus: $focusedField,
                        focusValue: .capacity
                    )

                    Picker("Skill level", selection: $vm.skillLevel) {
                        ForEach(SkillLevel.allCases) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: vm.skillLevel) { _, _ in vm.markDirty() }

                    TextField("Notes (optional)", text: $vm.notes, axis: .vertical)
                        .lineLimit(2...4)
                        .focused($focusedField, equals: .notes)
                        .onChange(of: vm.notes) { _, _ in vm.markDirty() }
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
                        Task { await submit(proxy: proxy) }
                    }
                    .buttonStyle(.borderless)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
            .onChange(of: scrollToAnchor) { _, anchor in
                guard let anchor else { return }
                performScroll(to: anchor, proxy: proxy)
            }
        }
        .navigationTitle("Edit session")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    attemptDismiss()
                }
            }
            FormKeyboardToolbar(
                canGoPrevious: canGoToPreviousField,
                canGoNext: canGoToNextField,
                onPrevious: focusPreviousField,
                onNext: focusNextField,
                onDone: {
                    viewModel.commitDurationFromText()
                    viewModel.commitCapacityFromText()
                    focusedField = nil
                }
            )
        }
        .interactiveDismissDisabled(vm.isDirty)
        .confirmationDialog(
            "Discard changes?",
            isPresented: $showDiscardDialog,
            titleVisibility: .visible
        ) {
            Button("Discard", role: .destructive) { dismiss() }
            Button("Keep editing", role: .cancel) {}
        } message: {
            Text("Your changes won't be saved.")
        }
        .task {
            await viewModel.loadVenues()
            await viewModel.hydrateCustomLocationIfNeeded()
        }
        .scrollDismissesKeyboard(.interactively)
        .dismissKeyboardOnBackgroundTap()
        .onChange(of: focusedField) { _, newValue in
            if newValue != .duration { viewModel.commitDurationFromText() }
            if newValue != .capacity { viewModel.commitCapacityFromText() }
        }
        .onChange(of: viewModel.durationMinutes) { _, _ in viewModel.markDirty() }
        .onChange(of: viewModel.capacity) { _, _ in viewModel.markDirty() }
    }

    private var activeFocusFields: [FocusField] {
        var fields: [FocusField] = []
        if viewModel.sport == .other { fields.append(.customSportName) }
        fields.append(contentsOf: [.duration, .capacity, .notes])
        return fields
    }

    private var canGoToPreviousField: Bool {
        guard let focused = focusedField,
              let index = activeFocusFields.firstIndex(of: focused) else { return false }
        return index > 0
    }

    private var canGoToNextField: Bool {
        guard let focused = focusedField,
              let index = activeFocusFields.firstIndex(of: focused) else { return false }
        return index < activeFocusFields.count - 1
    }

    private func focusPreviousField() {
        guard let focused = focusedField,
              let index = activeFocusFields.firstIndex(of: focused),
              index > 0 else { return }
        focusedField = activeFocusFields[index - 1]
    }

    private func focusNextField() {
        guard let focused = focusedField,
              let index = activeFocusFields.firstIndex(of: focused),
              index < activeFocusFields.count - 1 else { return }
        focusedField = activeFocusFields[index + 1]
    }

    private func attemptDismiss() {
        if viewModel.isDirty {
            showDiscardDialog = true
        } else {
            dismiss()
        }
    }

    @MainActor
    private func submit(proxy: ScrollViewProxy) async {
        viewModel.revealFieldErrors()
        viewModel.commitDurationFromText()
        viewModel.commitCapacityFromText()
        focusedField = nil
        if let session = await viewModel.save() {
            onSaved?(session)
            dismiss()
        } else if let anchor = viewModel.firstInvalidScrollAnchor() {
            scrollToAnchor = anchor
            performScroll(to: anchor, proxy: proxy)
        }
    }

    private func performScroll(to anchor: EditSessionScrollAnchor, proxy: ScrollViewProxy) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 150_000_000)
            withAnimation(.easeInOut(duration: 0.3)) {
                proxy.scrollTo(anchor, anchor: .top)
            }
            scrollToAnchor = nil
        }
    }
}
