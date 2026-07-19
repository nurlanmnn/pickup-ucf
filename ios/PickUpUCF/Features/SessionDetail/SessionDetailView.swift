import SwiftUI

struct SessionDetailView: View {
    let sessionId: UUID

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var viewModel: SessionDetailViewModel
    @State private var showEditSheet = false
    @State private var showAttendanceSheet = false
    @State private var showReportSheet = false
    @State private var showCancelConfirm = false
    @State private var showBlockConfirm = false
    @State private var showRunItBackSheet = false
    @State private var showChat = false
    @State private var isAddingToCalendar = false
    @State private var isSessionInCalendar = false

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
        .toolbar {
            if case .loaded(let session) = viewModel.session {
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(
                        item: SessionShareLink.message(for: session),
                        preview: SharePreview(
                            "\(session.sportDisplayName) at \(session.locationName)",
                            image: Image(systemName: session.sport.systemImage)
                        )
                    ) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Share session")
                }

                if !viewModel.isHost, appState.isAuthenticated {
                    ToolbarItem(placement: .secondaryAction) {
                        Menu {
                            Button {
                                showReportSheet = true
                            } label: {
                                Label("Report session", systemImage: "exclamationmark.bubble")
                            }
                            Button(role: .destructive) {
                                showBlockConfirm = true
                            } label: {
                                Label("Block host", systemImage: "hand.raised")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .accessibilityLabel("Session options")
                    }
                }
            }
        }
        .task(id: "\(sessionId.uuidString)-\(appState.session?.userId.uuidString ?? "anon")") {
            viewModel = SessionDetailViewModel(
                sessionId: sessionId,
                userId: appState.session?.userId
            )
            await viewModel.load()
            if appState.consumeSessionDetailOpenChat(for: sessionId), viewModel.canAccessChat {
                showChat = true
            }
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
        .sheet(isPresented: $showAttendanceSheet) {
            NavigationStack {
                AttendanceSheet(viewModel: viewModel)
            }
            .presentationDetents([.large])
        }
        .sheet(isPresented: $showReportSheet) {
            NavigationStack {
                ReportSheet(sessionId: sessionId)
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showRunItBackSheet) {
            if let session = viewModel.session.value {
                NavigationStack {
                    CreateSessionView(prefill: CreateSessionPrefill(from: session)) { created in
                        showRunItBackSheet = false
                        appState.presentSessionDetail(id: created.id, on: .myGames)
                        appState.touchSessionFeedRefresh()
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
        .confirmationDialog(
            "Block this host?",
            isPresented: $showBlockConfirm,
            titleVisibility: .visible
        ) {
            Button("Block host", role: .destructive) {
                Task {
                    if await viewModel.blockHost() {
                        appState.touchSessionFeedRefresh()
                        dismiss()
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Their sessions will be hidden from Discover and you won't be able to join their games.")
        }
    }

    @ViewBuilder
    private func sessionContent(_ session: PickupSession) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    SessionLocationMap(session: session)
                        .padding(.horizontal, Spacing.m)

                    VStack(alignment: .leading, spacing: Spacing.s) {
                        HStack {
                            Image(systemName: session.sport.systemImage)
                                .foregroundStyle(AppColor.sportAccent(session.sport))
                            Text(session.sportDisplayName)
                                .font(AppFont.title())
                        }

                        Label(SessionDateFormatter.cardLabel(for: session.startsAt), systemImage: "clock")
                        Label(session.locationName, systemImage: "mappin.and.ellipse")
                        if session.isOutdoorForWeather, let weather = session.weatherSnapshot {
                            Label(weather.displayLine, systemImage: "cloud.sun")
                                .font(AppFont.body())
                                .foregroundStyle(AppColor.textSecondary(colorScheme))
                        }
                        hostRow(session: session)
                        SkillPill(skill: session.skillLevel)

                        Text("\(session.playerCount) of \(session.capacity) players")
                            .font(AppFont.headline(.semibold))
                            .animation(nil, value: session.playerCount)

                        rosterSection()

                        if session.status == .cancelled {
                            FormFieldHint(text: "This session was cancelled.")
                        }

                        if let notes = session.notesForDisplay, !notes.isEmpty {
                            Text(notes)
                                .font(AppFont.body())
                                .foregroundStyle(AppColor.textSecondary(colorScheme))
                        }

                        chatEntry(session)

                        if viewModel.canRunItBack {
                            SecondaryButton(title: "Run it back") {
                                showRunItBackSheet = true
                            }
                            .padding(.top, Spacing.s)
                        }

                        if viewModel.canAddToCalendar {
                            SecondaryButton(title: calendarButtonTitle) {
                                Task { await addToCalendar(session) }
                            }
                            .disabled(isAddingToCalendar)
                            .padding(.top, Spacing.s)
                            .task(id: session.id) {
                                isSessionInCalendar = CalendarExportService.shared.isSessionInCalendar(
                                    sessionId: session.id
                                )
                            }
                        }
                    }
                    .foregroundStyle(AppColor.textPrimary(colorScheme))
                    .padding(.horizontal, Spacing.m)

                    if let actionError = viewModel.actionError {
                        ErrorBanner(message: actionError)
                            .padding(.horizontal, Spacing.m)
                    }
                }
                .padding(.bottom, Spacing.m)
            }

            sessionBottomBar(session)
        }
    }

    @ViewBuilder
    private func hostRow(session: PickupSession) -> some View {
        NavigationLink {
            HostProfileView(
                userId: session.hostId,
                currentUserId: appState.session?.userId,
                onBlocked: {
                    appState.touchSessionFeedRefresh()
                    dismiss()
                }
            )
        } label: {
            Label(session.host?.handle ?? "Host", systemImage: "person")
        }
    }

    @ViewBuilder
    private func rosterSection() -> some View {
        switch viewModel.roster {
        case .idle:
            EmptyView()
        case .loading:
            ProgressView("Loading players…")
                .font(AppFont.caption())
                .padding(.top, Spacing.s)
        case .failed(let message):
            FormFieldHint(text: message)
                .padding(.top, Spacing.s)
        case .loaded(let roster):
            VStack(alignment: .leading, spacing: Spacing.s) {
                Text("Players (\(roster.joined.count))")
                    .font(AppFont.headline(.semibold))

                ForEach(roster.joined) { member in
                    Label {
                        Text(member.displayName)
                    } icon: {
                        Image(systemName: member.role == .host ? "star.fill" : "person")
                    }
                    .font(AppFont.body())
                }

                if let waitlistLabel = roster.waitlistLabel(
                    participantStatus: viewModel.participantStatus
                ) {
                    FormFieldHint(text: waitlistLabel)
                }
            }
            .padding(.top, Spacing.s)
        }
    }

    @ViewBuilder
    private func chatEntry(_ session: PickupSession) -> some View {
        if viewModel.canAccessChat, let userId = appState.session?.userId {
            NavigationLink(isActive: $showChat) {
                ChatView(sessionId: session.id, currentUserId: userId)
            } label: {
                Label("Session chat", systemImage: "bubble.left.and.bubble.right")
                    .font(AppFont.headline(.semibold))
                    .foregroundStyle(AppColor.gold)
            }
            .padding(.top, Spacing.s)
        } else if appState.isAuthenticated {
            FormFieldHint(text: "Join this session to chat with other players.")
                .padding(.top, Spacing.s)
        }
    }

    @ViewBuilder
    private func sessionBottomBar(_ session: PickupSession) -> some View {
        let showsHostActions = viewModel.isHost
            && (viewModel.canHostEditSession || viewModel.canHostCancelSession || viewModel.canSubmitAttendance)
        let showsJoinActions = !viewModel.isHost
            && (session.status == .open || session.status == .full)

        if showsHostActions || showsJoinActions {
            VStack(spacing: Spacing.s) {
                if viewModel.isHost {
                    if viewModel.canHostEditSession {
                        SecondaryButton(title: "Edit session") {
                            showEditSheet = true
                        }
                    }
                    if viewModel.canSubmitAttendance {
                        SecondaryButton(title: "Mark attendance") {
                            showAttendanceSheet = true
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
                } else if showsJoinActions {
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
            .padding(Spacing.m)
            .frame(maxWidth: .infinity)
            .background(AppColor.background(colorScheme))
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(AppColor.textSecondary(colorScheme).opacity(0.2))
                    .frame(height: 1)
            }
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

    private var calendarButtonTitle: String {
        if isAddingToCalendar { return "Adding…" }
        if isSessionInCalendar { return "In Calendar" }
        return "Add to Calendar"
    }

    @MainActor
    private func addToCalendar(_ session: PickupSession) async {
        isAddingToCalendar = true
        defer { isAddingToCalendar = false }

        do {
            try await CalendarExportService.shared.addToCalendar(session: session)
            isSessionInCalendar = true
            appState.showSuccess("Added to Calendar")
        } catch CalendarExportError.alreadyAdded {
            isSessionInCalendar = true
            appState.showSuccess("Already in Calendar")
        } catch CalendarExportError.accessDenied {
            viewModel.actionError = "Calendar access is required to save this game."
        } catch {
            viewModel.actionError = AppErrorMapper.message(for: error)
        }
    }
}

#Preview {
    NavigationStack {
        SessionDetailView(sessionId: UUID())
            .environment(AppState())
    }
}
