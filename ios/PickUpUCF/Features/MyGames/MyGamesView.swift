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
                VStack(alignment: .leading, spacing: Spacing.m) {
                    if let error = viewModel?.actionError {
                        ErrorBanner(message: error)
                    }

                    if let vm = viewModel {
                        myGamesList(vm, currentUserId: userId)
                    }
                }
                .padding(Spacing.m)
            }
            .navigationTitle("My Games")
            .refreshable {
                await viewModel?.fetchSessions()
            }
            .task(id: userId) {
                let vm = MyGamesViewModel(userId: userId)
                viewModel = vm
                vm.load()
            }
            .navigationDestination(for: UUID.self) { sessionId in
                SessionDetailView(sessionId: sessionId)
            }
            .onChange(of: appState.sessionFeedRefreshNonce) { _, _ in
                viewModel?.load()
            }
        }
    }

    @ViewBuilder
    private func myGamesList(_ vm: MyGamesViewModel, currentUserId: UUID) -> some View {
        switch vm.sessions {
        case .idle, .loading:
            loadingPlaceholders
        case .failed(let message):
            ErrorBanner(message: message)
            PrimaryButton(title: "Try again") {
                vm.load()
            }
        case .loaded(let items):
            if items.isEmpty {
                EmptyStateView(
                    symbol: "calendar",
                    title: "No upcoming games",
                    message: "Join a session from Discover or host your own from the Create tab."
                )
            } else {
                LazyVStack(spacing: Spacing.m) {
                    ForEach(items) { session in
                        NavigationLink(value: session.id) {
                            SessionCard(
                                session: session,
                                isJoining: vm.leavingSessionId == session.id,
                                actionTitle: "Leave",
                                isDestructiveAction: true,
                                onJoin: session.hostId == currentUserId
                                    ? nil
                                    : {
                                        Task { await vm.leave(session: session) }
                                    }
                            )
                        }
                        .buttonStyle(.plain)
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
}

#Preview {
    MyGamesView()
        .environment(AppState())
}
