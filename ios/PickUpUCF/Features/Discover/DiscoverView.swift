import SwiftUI

struct DiscoverView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppState.self) private var appState
    @State private var viewModel = DiscoverViewModel()
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.m) {
                    sportChips
                    filterRow
                    venueChips
                    venueFilterHint

                    if let joinError = viewModel.joinErrorMessage {
                        ErrorBanner(message: joinError)
                    }

                    content
                }
                .padding(Spacing.m)
            }
            .background(AppColor.background(colorScheme))
            .navigationTitle("Discover")
            .searchable(text: $viewModel.searchText, prompt: "Search sessions")
            .refreshable {
                await viewModel.fetchSessions(currentUserId: appState.session?.userId)
            }
            .task(id: appState.session?.userId) {
                viewModel.load(currentUserId: appState.session?.userId)
            }
            .onChange(of: viewModel.selectedTimeWindow) { _, _ in
                viewModel.load(currentUserId: appState.session?.userId)
            }
            .onChange(of: viewModel.selectedSkillLevel) { _, _ in
                viewModel.load(currentUserId: appState.session?.userId)
            }
            .onChange(of: appState.sessionFeedRefreshNonce) { _, _ in
                viewModel.load(currentUserId: appState.session?.userId)
            }
            .navigationDestination(for: UUID.self) { sessionId in
                SessionDetailView(sessionId: sessionId)
            }
            .task(id: appState.sessionDetailDeepLink) {
                guard appState.sessionDetailDeepLinkTarget == .discover,
                      let id = appState.sessionDetailDeepLink else { return }
                navigationPath = NavigationPath()
                navigationPath.append(id)
                appState.clearSessionDetailDeepLink()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.sessions {
        case .idle, .loading:
            loadingPlaceholders
        case .failed(let message):
            ErrorBanner(message: message)
            PrimaryButton(title: "Try again") {
                viewModel.load(currentUserId: appState.session?.userId)
            }
        case .loaded(let items):
            TimelineView(.periodic(from: .now, by: 60)) { context in
                let rows = viewModel.discoverList(at: context.date)
                let uid = appState.session?.userId
                if rows.isEmpty {
                    let emptyState = viewModel.emptyStateContent(serverItemsAreEmpty: items.isEmpty)
                    EmptyStateView(
                        symbol: "sportscourt",
                        title: emptyState.title,
                        message: emptyState.message
                    )
                } else {
                    LazyVStack(spacing: Spacing.m) {
                        ForEach(rows) { session in
                            NavigationLink(value: session.id) {
                                SessionCard(
                                    session: session,
                                    isJoining: viewModel.joiningSessionId == session.id
                                        || viewModel.leavingSessionId == session.id,
                                    actionTitle: viewModel.cardActionTitle(for: session),
                                    isDestructiveAction: viewModel.isDestructiveCardAction(for: session),
                                    onJoin: uid == session.hostId
                                        ? nil
                                        : {
                                            Task {
                                                if viewModel.isParticipating(in: session.id) {
                                                    await viewModel.quickLeave(
                                                        session: session,
                                                        currentUserId: uid
                                                    )
                                                    appState.touchSessionFeedRefresh()
                                                } else {
                                                    await viewModel.quickJoin(
                                                        session: session,
                                                        currentUserId: uid
                                                    )
                                                    appState.touchSessionFeedRefresh()
                                                }
                                            }
                                        }
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var loadingPlaceholders: some View {
        LazyVStack(spacing: Spacing.m) {
            ForEach(0..<4, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppColor.surface(colorScheme))
                    .frame(height: 110)
                    .redacted(reason: .placeholder)
            }
        }
    }

    private var sportChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.s) {
                if viewModel.showMySportsChip {
                    SportChip(
                        title: "My sports",
                        isSelected: viewModel.filterMode == .mySports
                    ) {
                        viewModel.setFilterMode(.mySports, currentUserId: appState.session?.userId)
                    }
                }

                SportChip(
                    title: "All",
                    isSelected: viewModel.filterMode == .single(nil)
                ) {
                    viewModel.setFilterMode(.single(nil), currentUserId: appState.session?.userId)
                }

                ForEach(SportType.allCases) { sport in
                    SportChip(
                        title: sport.displayName,
                        isSelected: viewModel.filterMode == .single(sport)
                    ) {
                        viewModel.setFilterMode(.single(sport), currentUserId: appState.session?.userId)
                    }
                }
            }
        }
    }

    private var filterRow: some View {
        HStack(spacing: Spacing.s) {
            Picker("When", selection: $viewModel.selectedTimeWindow) {
                ForEach(DiscoverTimeWindow.allCases) { window in
                    Text(window.displayName).tag(window)
                }
            }
            .pickerStyle(.menu)
            .tint(AppColor.gold)

            Picker("Skill", selection: $viewModel.selectedSkillLevel) {
                ForEach(SkillLevel.allCases) { level in
                    Text(level.displayName).tag(level)
                }
            }
            .pickerStyle(.menu)
            .tint(AppColor.gold)

            Spacer(minLength: 0)
        }
        .font(AppFont.caption(.semibold))
    }

    private var venueChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.s) {
                SportChip(
                    title: "All venues",
                    isSelected: viewModel.selectedVenueId == nil
                ) {
                    viewModel.setVenueFilter(nil, currentUserId: appState.session?.userId)
                }

                ForEach(viewModel.officialVenues) { venue in
                    SportChip(
                        title: venue.name,
                        isSelected: viewModel.selectedVenueId == venue.id
                    ) {
                        viewModel.setVenueFilter(venue.id, currentUserId: appState.session?.userId)
                    }
                }
            }
        }
        .accessibilityLabel("Venue filters")
    }

    @ViewBuilder
    private var venueFilterHint: some View {
        if viewModel.selectedVenueId != nil {
            Label(
                "Custom-location sessions are hidden while a venue filter is active.",
                systemImage: "info.circle"
            )
            .font(AppFont.caption())
            .foregroundStyle(AppColor.textSecondary(colorScheme))
            .accessibilityElement(children: .combine)
        }
    }
}

private struct SportChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.caption(.semibold))
                .padding(.horizontal, Spacing.m)
                .padding(.vertical, Spacing.s)
                .background(isSelected ? AppColor.gold : Color.clear)
                .foregroundStyle(isSelected ? Color.black : AppColor.gold)
                .overlay {
                    Capsule().stroke(AppColor.gold, lineWidth: isSelected ? 0 : 1.5)
                }
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    DiscoverView()
        .environment(AppState())
}
