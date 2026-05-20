import SwiftUI

struct SessionDetailView: View {
    let sessionId: UUID

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var viewModel: SessionDetailViewModel
    @State private var showEditSheet = false
    @State private var showCancelConfirm = false

    init(sessionId: UUID) {
        self.sessionId = sessionId
        _viewModel = State(initialValue: SessionDetailViewModel(sessionId: sessionId, userId: nil))
    }

    var body: some View {
        Group {
            switch viewModel.session {
            case .idle, .loading:
                ProgressView("Loading session…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let message):
                VStack(spacing: Spacing.m) {
                    ErrorBanner(message: message)
                    PrimaryButton(title: "Try again") {
                        Task { await viewModel.load() }
                    }
                    .padding(.horizontal, Spacing.m)
                }
            case .loaded(let session):
                sessionContent(session)
            }
        }
        .background(AppColor.background(colorScheme))
        .navigationTitle("Session")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if case .loaded = viewModel.session {
                bottomBar
            }
        }
        .task(id: "\(sessionId.uuidString)-\(appState.session?.userId.uuidString ?? "anon")") {
            viewModel = SessionDetailViewModel(
                sessionId: sessionId,
                userId: appState.session?.userId
            )
            await viewModel.load()
            await withTaskCancellationHandler {
                await viewModel.startSessionRealtime()
            } onCancel: {
                Task { await viewModel.stopSessionRealtime() }
            }
        }
        .onDisappear {
            Task { await viewModel.stopSessionRealtime() }
        }
        .refreshable {
            await viewModel.load()
        }
        .sheet(isPresented: $showEditSheet) {
            if let session = viewModel.session.value {
                NavigationStack {
                    EditSessionView(session: session) { _ in
                        appState.touchSessionFeedRefresh()
                        Task { await viewModel.load() }
                    }
                }
                .presentationDetents([.large])
            }
        }
        .confirmationDialog(
            "Cancel this session for everyone?",
            isPresented: $showCancelConfirm,
            titleVisibility: .visible
        ) {
            Button("Cancel session", role: .destructive) {
                Task {
                    if await viewModel.cancelHostedSession() {
                        appState.touchSessionFeedRefresh()
                        dismiss()
                    }
                }
            }
            Button("Keep session", role: .cancel) {}
        } message: {
            Text("Players will no longer see this game.")
        }
    }

    @ViewBuilder
    private func sessionContent(_ session: PickupSession) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                mapPlaceholder(session)

                VStack(alignment: .leading, spacing: Spacing.s) {
                    HStack {
                        Image(systemName: session.sport.systemImage)
                            .foregroundStyle(AppColor.sportAccent(session.sport))
                        Text(session.sportDisplayName)
                            .font(AppFont.title())
                    }

                    Label(SessionDateFormatter.cardLabel(for: session.startsAt), systemImage: "clock")
                    Label(session.locationName, systemImage: "mappin.and.ellipse")
                    Label(session.host?.handle ?? "Host", systemImage: "person")
                    SkillPill(skill: session.skillLevel)

                    Text("\(session.playerCount) of \(session.capacity) players")
                        .font(AppFont.headline(.semibold))
                        .contentTransition(.numericText())
                        .animation(.spring(duration: 0.25), value: session.playerCount)

                    if session.status == .cancelled {
                        FormFieldHint(text: "This session was cancelled.")
                    }

                    if let notes = session.notesForDisplay, !notes.isEmpty {
                        Text(notes)
                            .font(AppFont.body())
                            .foregroundStyle(AppColor.textSecondary(colorScheme))
                    }
                }
                .foregroundStyle(AppColor.textPrimary(colorScheme))
                .padding(.horizontal, Spacing.m)

                if let actionError = viewModel.actionError {
                    ErrorBanner(message: actionError)
                        .padding(.horizontal, Spacing.m)
                }
            }
            .padding(.bottom, 100)
        }
    }

    private func mapPlaceholder(_ session: PickupSession) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColor.surface(colorScheme))
                .frame(height: 160)
            VStack(spacing: Spacing.s) {
                Image(systemName: "map")
                    .font(.largeTitle)
                    .foregroundStyle(AppColor.gold)
                Text(session.locationName)
                    .font(AppFont.caption())
                    .foregroundStyle(AppColor.textSecondary(colorScheme))
            }
        }
        .padding(.horizontal, Spacing.m)
    }

    @ViewBuilder
    private var bottomBar: some View {
        if case .loaded(let session) = viewModel.session {
            VStack(spacing: Spacing.s) {
                if viewModel.isHost {
                    if viewModel.canHostEditSession {
                        SecondaryButton(title: "Edit session") {
                            showEditSheet = true
                        }
                    }
                    if viewModel.canHostCancelSession {
                        Button(role: .destructive) {
                            showCancelConfirm = true
                        } label: {
                            Text("Cancel session")
                                .font(AppFont.headline(.semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.isSubmitting)
                    }
                } else {
                    if session.status == .open || session.status == .full {
                        if viewModel.isLeaveAction {
                            Button(role: .destructive) {
                                Task { await viewModel.joinOrLeave() }
                            } label: {
                                bottomButtonLabel(viewModel.primaryActionTitle)
                            }
                            .disabled(viewModel.isSubmitting)
                        } else {
                            PrimaryButton(
                                title: viewModel.primaryActionTitle,
                                isLoading: viewModel.isSubmitting,
                                isEnabled: !viewModel.isSubmitting
                            ) {
                                Task { await viewModel.joinOrLeave() }
                            }
                        }
                    }
                }
            }
            .padding(Spacing.m)
            .background(.ultraThinMaterial)
        }
    }

    private func bottomButtonLabel(_ title: String) -> some View {
        HStack {
            Spacer()
            if viewModel.isSubmitting {
                ProgressView()
            } else {
                Text(title)
                    .font(AppFont.headline(.semibold))
            }
            Spacer()
        }
        .frame(height: 50)
    }
}

#Preview {
    NavigationStack {
        SessionDetailView(sessionId: UUID())
            .environment(AppState())
    }
}
