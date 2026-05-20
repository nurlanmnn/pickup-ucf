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
                await viewModel.fetchSessions()
            }
            .task {
                viewModel.load()
            }
            .onChange(of: viewModel.selectedSport) { _, _ in
                viewModel.load()
            }
            .onChange(of: appState.sessionFeedRefreshNonce) { _, _ in
                viewModel.load()
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
                viewModel.load()
            }
        case .loaded(let items):
            TimelineView(.periodic(from: .now, by: 60)) { context in
                let rows = viewModel.discoverList(at: context.date)
                let uid = appState.session?.userId
                if items.isEmpty {
                    EmptyStateView(
                        symbol: "sportscourt",
                        title: "No games yet",
                        message: "Be the first to host a pickup session on campus."
                    )
                } else if rows.isEmpty {
                    EmptyStateView(
                        symbol: "sportscourt",
                        title: "No upcoming games",
                        message: viewModel.searchText.isEmpty
                            ? "Check back soon for new sessions."
                            : "Try another sport or search term."
                    )
                } else {
                    LazyVStack(spacing: Spacing.m) {
                        ForEach(rows) { session in
                            NavigationLink(value: session.id) {
                                SessionCard(
                                    session: session,
                                    isJoining: viewModel.joiningSessionId == session.id,
                                    onJoin: uid == session.hostId
                                        ? nil
                                        : {
                                            Task { await viewModel.quickJoin(session: session) }
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
                SportChip(title: "All", isSelected: viewModel.selectedSport == nil) {
                    viewModel.selectedSport = nil
                }
                ForEach(SportType.allCases) { sport in
                    SportChip(title: sport.displayName, isSelected: viewModel.selectedSport == sport) {
                        viewModel.selectedSport = sport
                    }
                }
            }
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
