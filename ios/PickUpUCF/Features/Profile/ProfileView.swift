import SwiftUI

struct ProfileView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @State private var profile: Profile?
    @State private var profileLoadError: String?

    private let profileRepository: ProfileRepositoryProtocol = ProfileRepository()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    heroHeader
                    mainContent
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .scrollContentBackground(.hidden)
        }
        .appScreenBackground()
        .task(id: appState.session?.userId) { await loadProfile() }
        .onChange(of: appState.profileRefreshNonce) { _, _ in Task { await loadProfile() } }
    }

    // MARK: - Hero

    private var heroHeader: some View {
        ZStack(alignment: .bottom) {
            // Warm gold gradient band
            LinearGradient(
                colors: [
                    AppColor.gold.opacity(colorScheme == .dark ? 0.24 : 0.18),
                    AppColor.gold.opacity(0.06),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(maxWidth: .infinity)
            .frame(height: 230)
            .ignoresSafeArea(edges: .top)

            VStack(spacing: Spacing.s) {
                avatarView
                    .padding(.top, Spacing.xl)

                VStack(spacing: 4) {
                    Text(profile?.displayName ?? appState.session?.email ?? "Student")
                        .font(AppFont.title(.bold))
                        .foregroundStyle(AppColor.textPrimary(colorScheme))

                    Group {
                        if let username = profile?.username, !username.isEmpty {
                            Text("@\(username)")
                                .foregroundStyle(AppColor.textSecondary(colorScheme))
                        } else {
                            Text("Set a username in Settings")
                                .foregroundStyle(AppColor.textSecondary(colorScheme))
                        }
                    }
                    .font(AppFont.caption(.regular))
                }

                if let profileLoadError {
                    Text(profileLoadError)
                        .font(AppFont.caption())
                        .foregroundStyle(AppColor.destructive)
                        .padding(.top, 2)
                }
            }
            .padding(.bottom, Spacing.l)
        }
    }

    private var avatarView: some View {
        ZStack {
            // Soft glow halo
            Circle()
                .fill(AppColor.gold.opacity(0.15))
                .frame(width: 108, height: 108)

            // Avatar fill
            Circle()
                .fill(
                    LinearGradient(
                        colors: [AppColor.gold, AppColor.goldDark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 88, height: 88)

            Image(systemName: "person.fill")
                .font(.system(size: 40, weight: .medium))
                .foregroundStyle(Color.black.opacity(0.60))
        }
        .overlay(
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [AppColor.gold, AppColor.gold.opacity(0.3)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 2.5
                )
                .frame(width: 94, height: 94)
        )
    }

    // MARK: - Main content

    private var mainContent: some View {
        VStack(spacing: Spacing.m) {
            statTiles
            if let p = profile, !p.preferredSports.isEmpty {
                sportChipsCard(p.preferredSports)
            }
            settingsEntryCard
        }
        .padding(Spacing.m)
        .padding(.top, Spacing.m)
    }

    // MARK: - Stat tiles

    private var statTiles: some View {
        HStack(spacing: Spacing.s) {
            statTile(
                value: profile.map { "\($0.gamesPlayed)" } ?? "–",
                label: "Games",
                systemImage: "trophy.fill",
                color: AppColor.gold
            )
            statTile(
                value: profile.map { "\($0.showUpStreak)" } ?? "–",
                label: "Streak",
                systemImage: "flame.fill",
                color: .orange
            )
            statTile(
                value: profile.map { "\($0.preferredSports.count)" } ?? "–",
                label: "Sports",
                systemImage: "sportscourt.fill",
                color: Color(red: 0.22, green: 0.72, blue: 0.33)
            )
        }
    }

    private func statTile(
        value: String,
        label: String,
        systemImage: String,
        color: Color
    ) -> some View {
        VStack(spacing: Spacing.s) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text(value)
                .font(AppFont.title(.bold))
                .foregroundStyle(AppColor.textPrimary(colorScheme))
                .contentTransition(.numericText())

            Text(label)
                .font(AppFont.caption2(.semibold))
                .foregroundStyle(AppColor.textSecondary(colorScheme))
                .textCase(.uppercase)
                .tracking(0.6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.m)
        .background(AppColor.elevatedSurface(colorScheme))
        .appCardStyle(cornerRadius: 16)
    }

    // MARK: - Sport chips

    private func sportChipsCard(_ sports: [SportType]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Label("Preferred sports", systemImage: "star.fill")
                .font(AppFont.caption(.semibold))
                .foregroundStyle(AppColor.textSecondary(colorScheme))
                .textCase(.uppercase)
                .tracking(0.5)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.s) {
                    ForEach(sports) { sport in
                        HStack(spacing: 5) {
                            Image(systemName: sport.systemImage)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppColor.sportAccent(sport))
                            Text(sport.displayName)
                                .font(AppFont.caption(.semibold))
                                .foregroundStyle(AppColor.textPrimary(colorScheme))
                        }
                        .padding(.horizontal, Spacing.s + 2)
                        .padding(.vertical, Spacing.xs + 2)
                        .background(AppColor.sportAccent(sport).opacity(0.10))
                        .overlay {
                            Capsule()
                                .stroke(AppColor.sportAccent(sport).opacity(0.30), lineWidth: 1)
                        }
                        .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(Spacing.m)
        .background(AppColor.elevatedSurface(colorScheme))
        .appCardStyle(cornerRadius: 16)
    }

    // MARK: - Settings entry

    private var settingsEntryCard: some View {
        NavigationLink {
            ProfileSettingsView()
        } label: {
            HStack(spacing: Spacing.m) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Color(red: 0.42, green: 0.42, blue: 0.46))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Text("Settings")
                    .font(AppFont.body(.semibold))
                    .foregroundStyle(AppColor.textPrimary(colorScheme))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppColor.textSecondary(colorScheme).opacity(0.7))
            }
            .padding(Spacing.m)
            .background(AppColor.elevatedSurface(colorScheme))
            .appCardStyle(cornerRadius: 16)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Load

    @MainActor
    private func loadProfile() async {
        profileLoadError = nil
        guard appState.isAuthenticated else {
            profile = nil
            return
        }
        do {
            profile = try await profileRepository.fetchCurrentProfile()
        } catch {
            profileLoadError = AppErrorMapper.message(for: error)
        }
    }
}

#Preview {
    ProfileView()
        .environment(AppState())
}
