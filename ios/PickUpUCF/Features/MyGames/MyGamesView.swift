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
            }
        }
        .background(AppColor.background(colorScheme))
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

    @ViewBuilder
    private func upcomingSection(_ vm: MyGamesViewModel, currentUserId: UUID) -> some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text("Upcoming")
                .font(AppFont.caption(.semibold))
                .foregroundStyle(AppColor.textSecondary(colorScheme))
                .textCase(.uppercase)

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

    @ViewBuilder
    private func pastSection(_ vm: MyGamesViewModel, currentUserId: UUID) -> some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    vm.isPastSectionExpanded.toggle()
                }
                if vm.isPastSectionExpanded {
                    vm.loadPastIfNeeded()
                }
            } label: {
                CollapsibleSectionHeader(
                    title: "Past games",
                    subtitle: pastSectionSubtitle(vm),
                    isExpanded: vm.isPastSectionExpanded
                )
            }
            .buttonStyle(.plain)

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
        .padding(.top, Spacing.s)
    }

    private func pastSectionSubtitle(_ vm: MyGamesViewModel) -> String {
        if vm.isPastSectionExpanded, let count = vm.pastSessions.value?.count, count > 0 {
            return "\(count) shown · tap to collapse"
        }
        return "Tap to load history"
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
                .buttonStyle(.plain)
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
