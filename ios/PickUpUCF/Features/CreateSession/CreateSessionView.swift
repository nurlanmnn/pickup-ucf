import SwiftUI

struct CreateSessionView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: CreateSessionViewModel
    @State private var currentStep: CreateSessionStep = .sportAndTime
    @State private var showDiscardDialog = false
    @State private var showSuccessOverlay = false
    @State private var scrollToAnchor: CreateSessionScrollAnchor?

    var onCreated: ((PickupSession) -> Void)?

    enum FocusField: Hashable {
        case customSportName
        case duration
        case capacity
        case notes
    }

    @FocusState private var focusedField: FocusField?

    init(prefill: CreateSessionPrefill? = nil, onCreated: ((PickupSession) -> Void)? = nil) {
        let model = CreateSessionViewModel()
        if let prefill {
            model.applyPrefill(prefill)
        } else {
            model.applyLastUsedDefaults()
        }
        _viewModel = State(initialValue: model)
        self.onCreated = onCreated
    }

    var body: some View {
        @Bindable var vm = viewModel

        VStack(spacing: 0) {
            CreateFlowProgressBar(currentStep: currentStep)

            if let error = vm.errorMessage {
                ErrorBanner(message: error)
                    .padding(.horizontal, Spacing.l)
                    .padding(.top, Spacing.s)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    stepContent(vm: vm)
                        .padding(Spacing.l)
                }
                .scrollDismissesKeyboard(.interactively)
                .dismissKeyboardOnBackgroundTap()
                .onChange(of: scrollToAnchor) { _, anchor in
                    guard let anchor else { return }
                    performScroll(to: anchor, proxy: proxy)
                }
                .onChange(of: currentStep) { _, _ in
                    if let anchor = scrollToAnchor {
                        performScroll(to: anchor, proxy: proxy)
                    }
                }
                .onChange(of: viewModel.showsCustomLocationField) { _, shows in
                    guard shows else { return }
                    scrollToAnchor = .customLocationMap
                }
            }

            bottomBar(vm: vm)
        }
        .appScreenBackground()
        .navigationTitle("Create session")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    attemptDismiss()
                }
            }
            keyboardToolbar
        }
        .interactiveDismissDisabled(vm.isDirty && !vm.didCreate)
        .confirmationDialog(
            "Discard this game?",
            isPresented: $showDiscardDialog,
            titleVisibility: .visible
        ) {
            Button("Discard", role: .destructive) { dismiss() }
            Button("Keep editing", role: .cancel) {}
        } message: {
            Text("Your changes won't be saved.")
        }
        .overlay {
            if showSuccessOverlay {
                successOverlay
            }
        }
        .task {
            await viewModel.loadVenues()
            await viewModel.hydrateCustomLocationIfNeeded()
        }
        .onChange(of: focusedField) { _, newValue in
            if newValue != .duration { viewModel.commitDurationFromText() }
            if newValue != .capacity { viewModel.commitCapacityFromText() }
        }
    }

    @ViewBuilder
    private func stepContent(vm: CreateSessionViewModel) -> some View {
        switch currentStep {
        case .sportAndTime:
            CreateSessionSportTimeStep(
                viewModel: vm,
                focusedField: $focusedField
            )
            .transition(stepTransition)
        case .location:
            CreateSessionLocationStep(viewModel: vm)
                .transition(stepTransition)
        case .details:
            CreateSessionDetailsStep(
                viewModel: vm,
                focusedField: $focusedField
            )
            .transition(stepTransition)
        }
    }

    private var stepTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    private func bottomBar(vm: CreateSessionViewModel) -> some View {
        HStack(spacing: Spacing.m) {
            if currentStep != .sportAndTime {
                SecondaryButton(title: "Back") {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        goBack()
                    }
                }
            }

            if currentStep == .details {
                PrimaryButton(
                    title: "Create session",
                    isLoading: vm.isLoading,
                    isEnabled: vm.canSubmit && !vm.isLoading
                ) {
                    Task { await submit() }
                }
            } else {
                PrimaryButton(title: "Next") {
                    advanceStep()
                }
            }
        }
        .padding(Spacing.l)
        .background(.ultraThinMaterial)
    }

    @ToolbarContentBuilder
    private var keyboardToolbar: some ToolbarContent {
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

    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            VStack(spacing: Spacing.m) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(AppColor.gold)
                Text("Session created!")
                    .font(AppFont.headline(.semibold))
                    .foregroundStyle(.white)
            }
            .padding(Spacing.xl)
        }
    }

    private var activeFocusFields: [FocusField] {
        switch currentStep {
        case .sportAndTime:
            var fields: [FocusField] = []
            if viewModel.sport == .other { fields.append(.customSportName) }
            fields.append(.duration)
            return fields
        case .location:
            return []
        case .details:
            return [.capacity, .notes]
        }
    }

    private var canGoToPreviousField: Bool {
        guard let focused = focusedField else { return false }
        guard let index = activeFocusFields.firstIndex(of: focused) else { return false }
        return index > 0
    }

    private var canGoToNextField: Bool {
        guard let focused = focusedField else { return false }
        guard let index = activeFocusFields.firstIndex(of: focused) else { return false }
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
        if viewModel.isDirty && !viewModel.didCreate {
            showDiscardDialog = true
        } else {
            dismiss()
        }
    }

    private func goBack() {
        focusedField = nil
        currentStep = currentStep.previous ?? currentStep
    }

    private func advanceStep() {
        viewModel.revealFieldErrors()
        viewModel.commitDurationFromText()
        viewModel.commitCapacityFromText()
        focusedField = nil

        guard viewModel.canAdvance(from: currentStep),
              let next = currentStep.next else {
            scrollToFirstInvalid()
            return
        }

        withAnimation(.easeInOut(duration: 0.25)) {
            currentStep = next
        }
    }

    private func scrollToFirstInvalid() {
        guard let step = viewModel.firstInvalidStep(),
              let anchor = viewModel.firstInvalidScrollAnchor(for: step) else { return }

        if step != currentStep {
            withAnimation(.easeInOut(duration: 0.25)) {
                currentStep = step
            }
        }
        scrollToAnchor = anchor
    }

    private func performScroll(to anchor: CreateSessionScrollAnchor, proxy: ScrollViewProxy) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 150_000_000)
            withAnimation(.easeInOut(duration: 0.3)) {
                proxy.scrollTo(anchor, anchor: .top)
            }
            scrollToAnchor = nil
        }
    }

    @MainActor
    private func submit() async {
        viewModel.commitDurationFromText()
        viewModel.commitCapacityFromText()
        focusedField = nil

        if let session = await viewModel.create() {
            showSuccessOverlay = true
            try? await Task.sleep(nanoseconds: 500_000_000)
            onCreated?(session)
            dismiss()
        } else {
            scrollToFirstInvalid()
        }
    }
}

#Preview {
    NavigationStack {
        CreateSessionView()
    }
}
