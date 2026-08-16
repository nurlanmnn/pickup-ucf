import SwiftUI
import UIKit

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
        .appScreenBackground()
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
                .appSheetChrome()
            }
        }
        .sheet(isPresented: $showAttendanceSheet) {
            NavigationStack {
                AttendanceSheet(viewModel: viewModel)
            }
            .appSheetChrome()
        }
        .sheet(isPresented: $showReportSheet) {
            NavigationStack {
                ReportSheet(sessionId: sessionId)
            }
            .appSheetChrome(detents: [.medium, .large])
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
                .appSheetChrome()
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
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                heroSection(session)
                    .padding(.horizontal, Spacing.m)
                    .padding(.top, Spacing.xs)

                VStack(alignment: .leading, spacing: Spacing.l) {
                    SessionLocationMap(session: session)
                    infoCard(session)
                    rosterCard(session)

                    if let notes = session.notesForDisplay, !notes.isEmpty {
                        notesCard(notes)
                    }
                    if session.status == .cancelled {
                        cancelledBanner()
                    }

                    chatCard(session)

                    if viewModel.canAddToCalendar {
                        calendarCard(session)
                    }
                }
                .padding(.horizontal, Spacing.m)
            }
            .padding(.bottom, Spacing.xl)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            stickyBottomChrome(session)
        }
    }

    // MARK: - Hero

    private func heroSection(_ session: PickupSession) -> some View {
        ZStack(alignment: .bottomLeading) {
            AppTheme.sportCardGradient(session.sport, scheme: colorScheme)

            Image(systemName: session.sport.systemImage)
                .font(.system(size: 110, weight: .black))
                .foregroundStyle(Color.white.opacity(0.12))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .padding(.trailing, Spacing.m)

            VStack(alignment: .leading, spacing: Spacing.s) {
                HStack {
                    if session.status == .cancelled {
                        heroPill("Cancelled", color: AppColor.destructive)
                    } else if session.status == .completed {
                        heroPill("Completed", color: Color.white.opacity(0.45))
                    } else if session.status == .full {
                        heroPill("Full", color: AppColor.gold)
                    }
                    Spacer()
                }

                Text(session.sportDisplayName)
                    .font(AppFont.display(.bold))
                    .foregroundStyle(.white)

                HStack(alignment: .center, spacing: Spacing.s) {
                    TimelineView(.periodic(from: .now, by: 60)) { ctx in
                        Label(
                            SessionDateFormatter.cardTimeLine(for: session.startsAt, relativeTo: ctx.date),
                            systemImage: "clock"
                        )
                        .font(AppFont.caption(.semibold))
                        .foregroundStyle(Color.white.opacity(0.85))
                    }

                    Spacer()

                    CapacityIndicator(
                        playerCount: session.playerCount,
                        capacity: session.capacity,
                        filledColor: .white,
                        dotSize: 7,
                        emptyColor: Color.white.opacity(0.25),
                        labelColor: Color.white.opacity(0.85)
                    )
                }
            }
            .padding(Spacing.m)
        }
        .frame(height: 148)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .appCardStyle(cornerRadius: 20)
    }

    private func heroPill(_ label: String, color: Color) -> some View {
        Text(label)
            .font(AppFont.caption2(.bold))
            .textCase(.uppercase)
            .tracking(0.6)
            .foregroundStyle(color == AppColor.gold ? Color.black : Color.white)
            .padding(.horizontal, Spacing.s)
            .padding(.vertical, 3)
            .background(color.opacity(color == AppColor.gold ? 1 : 0.55))
            .clipShape(Capsule())
    }

    // MARK: - Info Card

    @ViewBuilder
    private func infoCard(_ session: PickupSession) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            infoRow(icon: "clock.fill", color: AppColor.sportAccent(session.sport)) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(SessionDateFormatter.cardLabel(for: session.startsAt))
                        .font(AppFont.body(.semibold))
                        .foregroundStyle(AppColor.textPrimary(colorScheme))
                    Text(detailTimeRange(session))
                        .font(AppFont.caption())
                        .foregroundStyle(AppColor.textSecondary(colorScheme))
                }
            }

            Divider().padding(.leading, 52)

            Button { openLocationInMaps(session) } label: {
                infoRow(icon: "mappin.and.ellipse", color: AppColor.sportAccent(session.sport)) {
                    HStack {
                        Text(session.locationName)
                            .font(AppFont.body(.semibold))
                            .foregroundStyle(AppColor.textPrimary(colorScheme))
                            .multilineTextAlignment(.leading)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppColor.textSecondary(colorScheme).opacity(0.5))
                    }
                }
            }
            .buttonStyle(.plain)

            Divider().padding(.leading, 52)

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
                infoRow(icon: "person.fill", color: AppColor.sportAccent(session.sport)) {
                    HStack {
                        Text(session.host?.handle ?? "Host")
                            .font(AppFont.body(.semibold))
                            .foregroundStyle(AppColor.textPrimary(colorScheme))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AppColor.textSecondary(colorScheme).opacity(0.5))
                    }
                }
            }
            .buttonStyle(.plain)

            if session.isOutdoorForWeather, let weather = session.weatherSnapshot {
                Divider().padding(.leading, 52)
                infoRow(icon: "cloud.sun.fill", color: .orange) {
                    Text(weather.displayLine)
                        .font(AppFont.body(.semibold))
                        .foregroundStyle(AppColor.textPrimary(colorScheme))
                }
            }

            Divider().padding(.leading, 52)

            infoRow(icon: "chart.bar.fill", color: AppColor.sportAccent(session.sport)) {
                HStack {
                    Text("Skill level")
                        .font(AppFont.body())
                        .foregroundStyle(AppColor.textSecondary(colorScheme))
                    Spacer()
                    SkillPill(skill: session.skillLevel)
                }
            }
        }
        .background(AppColor.elevatedSurface(colorScheme))
        .appCardStyle(cornerRadius: 16)
    }

    @ViewBuilder
    private func infoRow<Content: View>(
        icon: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            content()
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func detailTimeRange(_ session: PickupSession) -> String {
        let f = DateFormatter()
        f.timeZone = TimeZone(identifier: "America/New_York")!
        f.timeStyle = .short
        f.dateStyle = .none
        return "\(f.string(from: session.startsAt)) – \(f.string(from: session.endsAt))"
    }

    private func openLocationInMaps(_ session: PickupSession) {
        let name = session.locationName
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let lat = session.customLat, let lng = session.customLng,
           let url = URL(string: "maps://?ll=\(lat),\(lng)&q=\(encoded)") {
            UIApplication.shared.open(url)
        } else if let url = URL(string: "maps://?q=\(encoded)") {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Roster Card

    @ViewBuilder
    private func rosterCard(_ session: PickupSession) -> some View {
        switch viewModel.roster {
        case .idle:
            EmptyView()
        case .loading:
            HStack(spacing: Spacing.s) {
                ProgressView()
                Text("Loading players…")
                    .font(AppFont.caption())
                    .foregroundStyle(AppColor.textSecondary(colorScheme))
            }
            .padding(Spacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.elevatedSurface(colorScheme))
            .appCardStyle(cornerRadius: 16)
        case .failed(let message):
            FormFieldHint(text: message)
        case .loaded(let roster):
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Players")
                        .font(AppFont.headline(.bold))
                        .foregroundStyle(AppColor.textPrimary(colorScheme))
                    Spacer()
                    CapacityIndicator(
                        playerCount: session.playerCount,
                        capacity: session.capacity,
                        filledColor: AppColor.sportAccent(session.sport)
                    )
                }
                .padding(Spacing.m)

                if !roster.joined.isEmpty {
                    Divider()
                    ForEach(Array(roster.joined.enumerated()), id: \.element.id) { idx, member in
                        playerRow(member)
                        if idx < roster.joined.count - 1 {
                            Divider().padding(.leading, 56)
                        }
                    }
                }

                if let waitlistLabel = roster.waitlistLabel(participantStatus: viewModel.participantStatus) {
                    Divider()
                    HStack(spacing: Spacing.s) {
                        Image(systemName: "clock")
                            .foregroundStyle(AppColor.gold)
                        Text(waitlistLabel)
                            .font(AppFont.caption(.semibold))
                            .foregroundStyle(AppColor.textSecondary(colorScheme))
                    }
                    .padding(Spacing.m)
                }
            }
            .background(AppColor.elevatedSurface(colorScheme))
            .appCardStyle(cornerRadius: 16)
        }
    }

    private func playerRow(_ member: SessionRosterMember) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppColor.mutedSurface(colorScheme))
                Text(String(member.displayName.prefix(1)).uppercased())
                    .font(AppFont.caption(.bold))
                    .foregroundStyle(AppColor.textSecondary(colorScheme))
            }
            .frame(width: 36, height: 36)
            .overlay {
                if member.role == .host {
                    Circle().stroke(AppColor.gold, lineWidth: 2)
                }
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(member.handle)
                    .font(AppFont.body(.semibold))
                    .foregroundStyle(AppColor.textPrimary(colorScheme))
                if member.role == .host {
                    Text("Host")
                        .font(AppFont.caption2(.semibold))
                        .foregroundStyle(AppColor.gold)
                }
            }

            Spacer()

            if member.role == .host {
                Image(systemName: "star.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColor.gold)
            }
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, 10)
    }

    // MARK: - Notes Card

    private func notesCard(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("Notes")
                .font(AppFont.caption(.semibold))
                .foregroundStyle(AppColor.textSecondary(colorScheme))
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.horizontal, Spacing.xs)

            Text(notes)
                .font(AppFont.body())
                .foregroundStyle(AppColor.textPrimary(colorScheme))
                .padding(Spacing.m)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColor.elevatedSurface(colorScheme))
                .appCardStyle(cornerRadius: 16)
        }
    }

    private func cancelledBanner() -> some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(AppColor.destructive)
            Text("This session was cancelled.")
                .font(AppFont.body(.semibold))
                .foregroundStyle(AppColor.destructive)
        }
        .padding(Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.destructive.opacity(0.10))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppColor.destructive.opacity(0.25), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Chat Card

    @ViewBuilder
    private func chatCard(_ session: PickupSession) -> some View {
        if viewModel.canAccessChat, let userId = appState.session?.userId {
            NavigationLink(isActive: $showChat) {
                ChatView(sessionId: session.id, currentUserId: userId)
            } label: {
                HStack(spacing: Spacing.m) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(width: 36, height: 36)
                        .background(AppColor.gold)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Session Chat")
                            .font(AppFont.body(.semibold))
                            .foregroundStyle(AppColor.textPrimary(colorScheme))
                        Text("Chat with players in this game")
                            .font(AppFont.caption())
                            .foregroundStyle(AppColor.textSecondary(colorScheme))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppColor.textSecondary(colorScheme).opacity(0.5))
                }
                .padding(Spacing.m)
                .background(AppColor.elevatedSurface(colorScheme))
                .appCardStyle(cornerRadius: 16)
            }
            .buttonStyle(.plain)
        } else if appState.isAuthenticated {
            HStack(spacing: Spacing.m) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColor.textSecondary(colorScheme))
                    .frame(width: 36, height: 36)
                    .background(AppColor.mutedSurface(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Text("Join this session to chat with other players.")
                    .font(AppFont.caption())
                    .foregroundStyle(AppColor.textSecondary(colorScheme))

                Spacer()
            }
            .padding(Spacing.m)
            .background(AppColor.mutedSurface(colorScheme))
            .appCardStyle(cornerRadius: 16)
        }
    }

    // MARK: - Calendar Card

    @ViewBuilder
    private func calendarCard(_ session: PickupSession) -> some View {
        Button {
            Task { await addToCalendar(session) }
        } label: {
            HStack(spacing: Spacing.m) {
                Image(systemName: isSessionInCalendar ? "checkmark.circle.fill" : "calendar.badge.plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isSessionInCalendar ? AppColor.success : .black)
                    .frame(width: 36, height: 36)
                    .background(isSessionInCalendar ? AppColor.success.opacity(0.15) : AppColor.gold)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Text(calendarButtonTitle)
                    .font(AppFont.body(.semibold))
                    .foregroundStyle(AppColor.textPrimary(colorScheme))

                Spacer()
            }
            .padding(Spacing.m)
            .background(AppColor.elevatedSurface(colorScheme))
            .appCardStyle(cornerRadius: 16)
        }
        .buttonStyle(.plain)
        .disabled(isAddingToCalendar)
        .task(id: session.id) {
            isSessionInCalendar = CalendarExportService.shared.isSessionInCalendar(sessionId: session.id)
        }
    }

    @ViewBuilder
    private func stickyBottomChrome(_ session: PickupSession) -> some View {
        let showsHostActions = viewModel.isHost
            && (viewModel.canHostEditSession || viewModel.canHostCancelSession || viewModel.canSubmitAttendance)
        let showsJoinActions = !viewModel.isHost
            && (session.status == .open || session.status == .full)
        let showsRunItBack = viewModel.canRunItBack

        if showsHostActions || showsJoinActions || showsRunItBack || viewModel.actionError != nil {
            VStack(spacing: Spacing.s) {
                if let actionError = viewModel.actionError {
                    ErrorBanner(message: actionError)
                }

                sessionBottomBar(session)
            }
            .padding(.horizontal, Spacing.m)
            .padding(.top, Spacing.s)
            .padding(.bottom, Spacing.m)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(AppColor.textSecondary(colorScheme).opacity(0.12))
                    .frame(height: 0.5)
            }
        }
    }

    @ViewBuilder
    private func sessionBottomBar(_ session: PickupSession) -> some View {
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
            } else if session.status == .open || session.status == .full {
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

            if viewModel.canRunItBack {
                PrimaryButton(title: "Run it back") {
                    showRunItBackSheet = true
                }
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
