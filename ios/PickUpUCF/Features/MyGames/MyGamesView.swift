import SwiftUI

struct MyGamesView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppState.self) private var appState
    @State private var viewModel: MyGamesViewModel?
    @State private var navigationPath = NavigationPath()

    var body: some View {
        Group {
            if let userId = appState.session?.userId {
                myGamesContent(userId: userId)
            } else {
                Text("Sign in to see your games.")
                    .font(AppFont.body())
                    .foregroundStyle(AppColor.textSecondary(colorScheme))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .appScreenBackground()
            }
        }
    }

    @ViewBuilder
    private func myGamesContent(userId: UUID) -> some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    if let error = viewModel?.actionError {
                        ErrorBanner(message: error)
                    }

                    if let vm = viewModel {
                        upcomingSection(vm, currentUserId: userId)
                        pastSection(vm, currentUserId: userId)
                    }
                }
                .padding(Spacing.m)
            }
            .appScreenBackground()
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationTitle("My Games")
            .refreshable {
                guard let vm = viewModel else { return }
                await vm.fetchUpcoming()
                if vm.isPastSectionExpanded {
                    await vm.fetchPast(reset: true)
                }
            }
            .task(id: userId) {
                let vm = MyGamesViewModel(userId: userId)
                viewModel = vm
                vm.loadUpcoming()
            }
            .navigationDestination(for: UUID.self) { sessionId in
                SessionDetailView(sessionId: sessionId)
            }
            .task(id: appState.sessionDetailDeepLink) {
                guard appState.sessionDetailDeepLinkTarget == .myGames,
                      let id = appState.sessionDetailDeepLink else { return }
                navigationPath = NavigationPath()
                navigationPath.append(id)
                appState.clearSessionDetailDeepLink()
            }
            .onChange(of: appState.sessionFeedRefreshNonce) { _, _ in
                guard let vm = viewModel else { return }
                vm.loadUpcoming()
                if vm.isPastSectionExpanded {
                    Task { await vm.fetchPast(reset: true) }
                }
            }
        }
    }

    // MARK: - Upcoming Section

    @ViewBuilder
    private func upcomingSection(_ vm: MyGamesViewModel, currentUserId: UUID) -> some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            sectionLabel("Upcoming", value: upcomingCount(vm))

            switch vm.upcomingSessions {
            case .idle, .loading:
                loadingPlaceholders
            case .failed(let message):
                ErrorBanner(message: message)
                PrimaryButton(title: "Try again") {
                    vm.loadUpcoming()
                }
            case .loaded(let items):
                if items.isEmpty {
                    EmptyStateView(
                        symbol: "calendar",
                        title: "No upcoming games",
                        message: "Join a session from Discover or host your own from the Create tab."
                    )
                } else {
                    sessionCards(items, vm: vm, currentUserId: currentUserId, showsLeave: true)
                }
            }
        }
    }

    private func upcomingCount(_ vm: MyGamesViewModel) -> String? {
        guard let items = vm.upcomingSessions.value, !items.isEmpty else { return nil }
        return "\(items.count)"
    }

    // MARK: - Past Section

    @ViewBuilder
    private func pastSection(_ vm: MyGamesViewModel, currentUserId: UUID) -> some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            // Tappable elevated card for the history entry point
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    vm.isPastSectionExpanded.toggle()
                }
                if vm.isPastSectionExpanded {
                    vm.loadPastIfNeeded()
                }
            } label: {
                HStack(spacing: Spacing.m) {
                    Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(AppColor.textSecondary(colorScheme).opacity(0.55))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Past games")
                            .font(AppFont.body(.semibold))
                            .foregroundStyle(AppColor.textPrimary(colorScheme))
                        Text(pastSectionSubtitle(vm))
                            .font(AppFont.caption())
                            .foregroundStyle(AppColor.textSecondary(colorScheme))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppColor.textSecondary(colorScheme).opacity(0.5))
                        .rotationEffect(.degrees(vm.isPastSectionExpanded ? 90 : 0))
                        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: vm.isPastSectionExpanded)
                }
                .padding(Spacing.m)
                .background(AppColor.elevatedSurface(colorScheme))
                .appCardStyle(cornerRadius: 16)
            }
            .buttonStyle(.plain)
            .accessibilityHint(vm.isPastSectionExpanded ? "Collapse section" : "Load game history")

            if vm.isPastSectionExpanded {
                if vm.pastSessions.isLoading, vm.pastSessions.value == nil {
                    loadingPlaceholders
                } else if let message = vm.pastSessions.errorMessage {
                    ErrorBanner(message: message)
                    PrimaryButton(title: "Try again") {
                        Task { await vm.fetchPast(reset: true) }
                    }
                } else if let items = vm.pastSessions.value {
                    if items.isEmpty {
                        FormFieldHint(text: "No past games yet.")
                    } else {
                        sessionCards(items, vm: vm, currentUserId: currentUserId, showsLeave: false)

                        if vm.hasMorePastSessions {
                            SecondaryButton(title: vm.isLoadingMorePast ? "Loading…" : "Load more") {
                                vm.loadMorePast()
                            }
                            .disabled(vm.isLoadingMorePast)
                        }
                    }
                }
            }
        }
    }

    private func pastSectionSubtitle(_ vm: MyGamesViewModel) -> String {
        if vm.isPastSectionExpanded, let count = vm.pastSessions.value?.count, count > 0 {
            return "\(count) shown · tap to collapse"
        }
        return "Tap to load history"
    }

    /// Styled section label with an optional count badge and a gold accent line.
    private func sectionLabel(_ title: String, value: String? = nil) -> some View {
        HStack(alignment: .center, spacing: Spacing.s) {
            Text(title)
                .font(AppFont.caption(.semibold))
                .foregroundStyle(AppColor.textSecondary(colorScheme))
                .textCase(.uppercase)
                .tracking(0.6)

            if let value {
                Text(value)
                    .font(AppFont.caption2(.bold))
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppColor.gold)
                    .clipShape(Capsule())
            }

            // Gold accent line
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [AppColor.gold.opacity(0.5), AppColor.gold.opacity(0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1.5)
        }
    }

    @ViewBuilder
    private func sessionCards(
        _ items: [PickupSession],
        vm: MyGamesViewModel,
        currentUserId: UUID,
        showsLeave: Bool
    ) -> some View {
        LazyVStack(spacing: Spacing.m) {
            ForEach(items) { session in
                NavigationLink(value: session.id) {
                    SessionCard(
                        session: session,
                        isJoining: showsLeave && vm.leavingSessionId == session.id,
                        actionTitle: showsLeave ? "Leave" : nil,
                        isDestructiveAction: showsLeave,
                        onJoin: showsLeave && session.hostId != currentUserId
                            ? { Task { await vm.leave(session: session) } }
                            : nil
                    )
                }
                .buttonStyle(GameCardButtonStyle(sport: session.sport))
            }
        }
    }

    private var loadingPlaceholders: some View {
        LazyVStack(spacing: Spacing.m) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppColor.surface(colorScheme))
                    .frame(height: 110)
                    .redacted(reason: .placeholder)
            }
        }
    }
}

#Preview {
    MyGamesView()
        .environment(AppState())
}
