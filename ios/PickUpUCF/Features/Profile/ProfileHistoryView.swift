import SwiftUI

struct ProfileHistoryView: View {
    let profile: Profile
    var showsStreak = false
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel = ProfileHistoryViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.m) {
                summary
                Text("Recorded attendance")
                    .font(AppFont.headline(.bold))
                    .foregroundStyle(AppColor.textPrimary(colorScheme))

                if let error = viewModel.errorMessage {
                    ErrorBanner(message: error)
                    SecondaryButton(title: "Try again") {
                        Task { await viewModel.load(reset: viewModel.retryResetsHistory) }
                    }
                }

                ForEach(viewModel.records) { record in
                    if let session = record.session {
                        NavigationLink {
                            SessionDetailView(sessionId: record.sessionId)
                        } label: {
                            historyRow(session)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Open session details")
                    } else {
                        FormFieldHint(text: "Attendance recorded on \(record.markedAt.formatted(date: .abbreviated, time: .omitted)). Session details are unavailable.")
                    }
                }

                if viewModel.isLoading {
                    ProgressView("Loading history…")
                        .frame(maxWidth: .infinity)
                } else if viewModel.hasLoaded, viewModel.records.isEmpty, viewModel.errorMessage == nil {
                    EmptyStateView(
                        symbol: "trophy",
                        title: "No recorded games yet",
                        message: "Games appear here after the host marks your attendance."
                    )
                } else if viewModel.hasLoaded, viewModel.hasMore, viewModel.errorMessage == nil {
                    SecondaryButton(title: "Load more") {
                        Task { await viewModel.load(reset: false) }
                    }
                }
            }
            .padding(Spacing.m)
        }
        .appScreenBackground()
        .navigationTitle(showsStreak ? "Attendance streak" : "Games played")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load(reset: true) }
        .refreshable { await viewModel.load(reset: true) }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Label(
                showsStreak ? "\(profile.showUpStreak) game streak" : "\(profile.gamesPlayed) \(profile.gamesPlayed == 1 ? "game" : "games") played",
                systemImage: showsStreak ? "flame.fill" : "trophy.fill"
            )
            .font(AppFont.title(.bold))
            .foregroundStyle(AppColor.textPrimary(colorScheme))
            Text(showsStreak
                 ? "Your streak grows when a host marks you attended. A missed game resets it. Recent confirmed attendance is shown below."
                 : "Games count when a host marks you attended. History is ordered by when attendance was recorded.")
                .font(AppFont.body())
                .foregroundStyle(AppColor.textSecondary(colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.elevatedSurface(colorScheme))
        .appCardStyle(cornerRadius: 16)
    }

    private func historyRow(_ session: ProfileHistorySession) -> some View {
        HStack(spacing: Spacing.s) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Label(session.title, systemImage: session.sport.systemImage)
                    .font(AppFont.headline(.bold))
                    .foregroundStyle(AppColor.textPrimary(colorScheme))
                Text(session.startsAt.formatted(date: .abbreviated, time: .shortened))
                Text(session.location)
            }
            .font(AppFont.caption())
            .foregroundStyle(AppColor.textSecondary(colorScheme))
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .foregroundStyle(AppColor.textSecondary(colorScheme))
                .accessibilityHidden(true)
        }
        .padding(Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.elevatedSurface(colorScheme))
        .appCardStyle(cornerRadius: 16)
    }
}
