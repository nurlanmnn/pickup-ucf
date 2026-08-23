import SwiftUI
import UIKit

struct DiscoverView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppState.self) private var appState
    @State private var viewModel = DiscoverViewModel()
    @State private var navigationPath = NavigationPath()
    @State private var presentation: DiscoverPresentation = .list

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                discoverBody
            }
            .refreshable {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                await viewModel.fetchSessions(currentUserId: appState.session?.userId)
            }
            .appScreenBackground()
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationTitle("Discover")
            .searchable(text: $viewModel.searchText, prompt: "Search sessions")
            .task(id: appState.session?.userId) {
                viewModel.load(currentUserId: appState.session?.userId)
            }
            .onChange(of: viewModel.selectedTimeWindow) { _, _ in
                UISelectionFeedbackGenerator().selectionChanged()
                viewModel.load(currentUserId: appState.session?.userId)
            }
            .onChange(of: viewModel.selectedSkillLevel) { _, _ in
                UISelectionFeedbackGenerator().selectionChanged()
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

    private var discoverBody: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            sportChips
                .padding(.horizontal, Spacing.m)
            filterBar

            if let joinError = viewModel.joinErrorMessage {
                ErrorBanner(message: joinError)
                    .padding(.horizontal, Spacing.m)
            }

            content
                .padding(.horizontal, Spacing.m)
        }
        .padding(.vertical, Spacing.m)
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
                    discoverEmptyState(serverItemsAreEmpty: items.isEmpty)
                } else {
                    switch presentation {
                    case .list:
                        LazyVStack(spacing: Spacing.m) {
                            ForEach(Array(rows.enumerated()), id: \.element.id) { index, session in
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
                                .buttonStyle(GameCardButtonStyle(sport: session.sport))
                                .staggeredAppear(index: index)
                            }
                        }
                    case .map:
                        DiscoverMapView(sessions: rows) { sessionId in
                            navigationPath.append(sessionId)
                        }
                        .frame(height: 480)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func discoverEmptyState(serverItemsAreEmpty: Bool) -> some View {
        let emptyState = viewModel.emptyStateContent(serverItemsAreEmpty: serverItemsAreEmpty)
        let presets = viewModel.quickCreatePresets()

        VStack(spacing: Spacing.m) {
            EmptyStateView(
                symbol: viewModel.emptyStateSymbol(),
                title: emptyState.title,
                message: emptyState.message,
                actionTitle: appState.isAuthenticated ? viewModel.hostNudgeCTATitle() : nil,
                action: appState.isAuthenticated
                    ? { appState.requestCreateSession(prefill: viewModel.hostNudgePrefill()) }
                    : nil
            )

            if appState.isAuthenticated, !presets.isEmpty {
                quickCreatePresetRow(presets)
            }
        }
    }

    private func quickCreatePresetRow(_ presets: [QuickCreatePreset]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("Or pick a sport")
                .font(AppFont.caption(.semibold))
                .foregroundStyle(AppColor.textSecondary(colorScheme))
                .textCase(.uppercase)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.s) {
                    ForEach(presets) { preset in
                        Button {
                            appState.requestCreateSession(
                                prefill: CreateSessionPrefill(
                                    sport: preset.sport,
                                    venueId: preset.venueId
                                )
                            )
                        } label: {
                            Label(preset.sport.displayName, systemImage: preset.sport.systemImage)
                                .font(AppFont.caption(.semibold))
                                .padding(.horizontal, Spacing.m)
                                .padding(.vertical, Spacing.s)
                                .foregroundStyle(AppColor.textPrimary(colorScheme))
                                .background(AppColor.surface(colorScheme))
                                .overlay {
                                    Capsule().stroke(
                                        AppColor.sportAccent(preset.sport).opacity(0.7),
                                        lineWidth: 1.5
                                    )
                                }
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Host \(preset.sport.displayName.lowercased()) in two hours")
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var loadingPlaceholders: some View {
        LazyVStack(spacing: Spacing.m) {
            ForEach(0..<4, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(AppColor.elevatedSurface(colorScheme))
                    .frame(height: 140)
                    .redacted(reason: .placeholder)
            }
        }
    }

    // MARK: - Sport Chips

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
                        icon: sport.systemImage,
                        title: sport.displayName,
                        isSelected: viewModel.filterMode == .single(sport)
                    ) {
                        viewModel.setFilterMode(.single(sport), currentUserId: appState.session?.userId)
                    }
                }
            }
        }
    }

    // MARK: - Unified Filter Bar

    /// Single row that consolidates time window, skill level, venue, and list/map toggle.
    private var filterBar: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.s) {
                    // Time window
                    Menu {
                        ForEach(DiscoverTimeWindow.allCases) { window in
                            Button {
                                viewModel.selectedTimeWindow = window
                            } label: {
                                if viewModel.selectedTimeWindow == window {
                                    Label(window.displayName, systemImage: "checkmark")
                                } else {
                                    Text(window.displayName)
                                }
                            }
                        }
                    } label: {
                        filterPill(
                            icon: "clock",
                            label: viewModel.selectedTimeWindow.chipLabel,
                            isActive: viewModel.selectedTimeWindow != .next48h
                        )
                    }
                    .accessibilityLabel("Time window: \(viewModel.selectedTimeWindow.displayName)")

                    // Skill level
                    Menu {
                        ForEach(SkillLevel.allCases) { level in
                            Button {
                                viewModel.selectedSkillLevel = level
                            } label: {
                                if viewModel.selectedSkillLevel == level {
                                    Label(level.displayName, systemImage: "checkmark")
                                } else {
                                    Text(level.displayName)
                                }
                            }
                        }
                    } label: {
                        filterPill(
                            icon: "chart.bar",
                            label: viewModel.selectedSkillLevel == .any ? "Level" : viewModel.selectedSkillLevel.displayName,
                            isActive: viewModel.selectedSkillLevel != .any
                        )
                    }
                    .accessibilityLabel("Skill level: \(viewModel.selectedSkillLevel.displayName)")

                    // Venue (only shown when venues are loaded)
                    if !viewModel.officialVenues.isEmpty {
                        Menu {
                            Button {
                                viewModel.setVenueFilter(nil, currentUserId: appState.session?.userId)
                            } label: {
                                if viewModel.selectedVenueId == nil {
                                    Label("All venues", systemImage: "checkmark")
                                } else {
                                    Text("All venues")
                                }
                            }
                            ForEach(viewModel.officialVenues) { venue in
                                Button {
                                    viewModel.setVenueFilter(venue.id, currentUserId: appState.session?.userId)
                                } label: {
                                    if viewModel.selectedVenueId == venue.id {
                                        Label(venue.name, systemImage: "checkmark")
                                    } else {
                                        Text(venue.name)
                                    }
                                }
                            }
                        } label: {
                            filterPill(
                                icon: "mappin.and.ellipse",
                                label: venueChipLabel,
                                isActive: viewModel.selectedVenueId != nil
                            )
                        }
                        .accessibilityLabel("Venue filter")
                    }
                }
                .padding(.horizontal, Spacing.m)
            }

            // Divider
            Rectangle()
                .fill(AppColor.textSecondary(colorScheme).opacity(0.18))
                .frame(width: 1, height: 22)

            // List / Map toggle
            HStack(spacing: 2) {
                ForEach(DiscoverPresentation.allCases) { p in
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                            presentation = p
                        }
                    } label: {
                        Image(systemName: p.icon)
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: 30, height: 30)
                            .background(presentation == p ? AppColor.gold : Color.clear)
                            .foregroundStyle(presentation == p ? Color.black : AppColor.textSecondary(colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(p.displayName)
                    .accessibilityAddTraits(presentation == p ? .isSelected : [])
                }
            }
            .padding(.horizontal, Spacing.s)
        }
    }

    private func filterPill(icon: String, label: String, isActive: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(label)
                .font(AppFont.caption(.semibold))
            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .bold))
                .opacity(0.7)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .foregroundStyle(isActive ? Color.black : AppColor.textPrimary(colorScheme))
        .background(isActive ? AppColor.gold : AppColor.elevatedSurface(colorScheme))
        .clipShape(Capsule())
        .overlay {
            if !isActive {
                Capsule()
                    .stroke(AppColor.textSecondary(colorScheme).opacity(0.20), lineWidth: 1)
            }
        }
    }

    private var venueChipLabel: String {
        guard let id = viewModel.selectedVenueId,
              let venue = viewModel.officialVenues.first(where: { $0.id == id }) else {
            return "Venue"
        }
        return venue.name
    }
}

private enum DiscoverPresentation: String, CaseIterable, Identifiable {
    case list
    case map

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }

    var icon: String {
        switch self {
        case .list: return "list.bullet"
        case .map: return "map"
        }
    }
}

private struct SportChip: View {
    var icon: String? = nil
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                }
                Text(title)
                    .font(AppFont.caption(.semibold))
            }
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.s)
            .background(isSelected ? AppColor.gold : Color.clear)
            .foregroundStyle(isSelected ? Color.black : AppColor.gold)
            .overlay {
                Capsule().stroke(AppColor.gold, lineWidth: isSelected ? 0 : 1.5)
            }
            .clipShape(Capsule())
            .scaleEffect(isSelected ? 1.04 : 1)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.32, dampingFraction: 0.68), value: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    DiscoverView()
        .environment(AppState())
}
