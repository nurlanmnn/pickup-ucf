import SwiftUI
import UIKit

@Observable
final class HostProfileViewModel {
    let userId: UUID

    var profile = Loadable<Profile>.idle
    var isBlocking = false
    var errorMessage: String?

    private let profileRepository: ProfileRepositoryProtocol
    private let blockRepository: BlockRepositoryProtocol

    init(
        userId: UUID,
        profileRepository: ProfileRepositoryProtocol = ProfileRepository(),
        blockRepository: BlockRepositoryProtocol = BlockRepository()
    ) {
        self.userId = userId
        self.profileRepository = profileRepository
        self.blockRepository = blockRepository
    }

    @MainActor
    func load() async {
        profile = .loading
        errorMessage = nil
        do {
            let item = try await profileRepository.fetchProfile(userId: userId)
            profile = .loaded(item)
        } catch {
            profile = .failed(AppErrorMapper.message(for: error))
        }
    }

    @MainActor
    func blockUser() async -> Bool {
        errorMessage = nil
        isBlocking = true
        defer { isBlocking = false }

        do {
            try await blockRepository.block(userId: userId)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            return true
        } catch {
            errorMessage = AppErrorMapper.message(for: error)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return false
        }
    }
}

struct HostProfileView: View {
    let userId: UUID
    let currentUserId: UUID?
    var onBlocked: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: HostProfileViewModel
    @State private var showBlockConfirm = false

    init(
        userId: UUID,
        currentUserId: UUID?,
        onBlocked: (() -> Void)? = nil
    ) {
        self.userId = userId
        self.currentUserId = currentUserId
        self.onBlocked = onBlocked
        _viewModel = State(initialValue: HostProfileViewModel(userId: userId))
    }

    private var canShowBlock: Bool {
        guard let currentUserId else { return false }
        return currentUserId != userId
    }

    var body: some View {
        Group {
            switch viewModel.profile {
            case .idle, .loading:
                ProgressView("Loading profile…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .appScreenBackground()
            case .failed(let message):
                VStack(spacing: Spacing.m) {
                    ErrorBanner(message: message)
                    PrimaryButton(title: "Try again") {
                        Task { await viewModel.load() }
                    }
                    .padding(.horizontal, Spacing.m)
                }
                .appScreenBackground()
            case .loaded(let profile):
                profileContent(profile)
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: userId) {
            await viewModel.load()
        }
        .confirmationDialog(
            "Block this user?",
            isPresented: $showBlockConfirm,
            titleVisibility: .visible
        ) {
            Button("Block user", role: .destructive) {
                Task {
                    if await viewModel.blockUser() {
                        onBlocked?()
                        dismiss()
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Their sessions will be hidden from Discover and you won't be able to join their games.")
        }
    }

    // MARK: - Profile Content

    @ViewBuilder
    private func profileContent(_ profile: Profile) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                heroHeader(profile)

                VStack(spacing: Spacing.m) {
                    statTiles(profile)

                    if !profile.preferredSports.isEmpty {
                        sportChipsCard(profile.preferredSports)
                    }

                    if let errorMessage = viewModel.errorMessage {
                        ErrorBanner(message: errorMessage)
                    }

                    if canShowBlock {
                        blockCard
                    }
                }
                .padding(Spacing.m)
                .padding(.top, Spacing.m)
                .padding(.bottom, Spacing.xl)
            }
        }
        .appScreenBackground()
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    // MARK: - Hero

    private func heroHeader(_ profile: Profile) -> some View {
        VStack(spacing: Spacing.s) {
            avatarView
                .padding(.top, Spacing.l)

            VStack(spacing: 4) {
                Text(profile.displayName)
                    .font(AppFont.title(.bold))
                    .foregroundStyle(AppColor.textPrimary(colorScheme))

                if let username = profile.username, !username.isEmpty {
                    Text("@\(username)")
                        .font(AppFont.caption(.regular))
                        .foregroundStyle(AppColor.textSecondary(colorScheme))
                }
            }
        }
        .padding(.bottom, Spacing.l)
    }

    private var avatarView: some View {
        ZStack {
            Circle()
                .fill(AppColor.gold.opacity(0.15))
                .frame(width: 108, height: 108)

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

    // MARK: - Stat Tiles

    private func statTiles(_ profile: Profile) -> some View {
        HStack(spacing: Spacing.s) {
            statTile(
                value: "\(profile.gamesPlayed)",
                label: "Games",
                systemImage: "trophy.fill",
                color: AppColor.gold
            )
            statTile(
                value: "\(profile.showUpStreak)",
                label: "Streak",
                systemImage: "flame.fill",
                color: .orange
            )
            if !profile.preferredSports.isEmpty {
                statTile(
                    value: "\(profile.preferredSports.count)",
                    label: "Sports",
                    systemImage: "sportscourt.fill",
                    color: Color(red: 0.22, green: 0.72, blue: 0.33)
                )
            }
        }
    }

    private func statTile(value: String, label: String, systemImage: String, color: Color) -> some View {
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

    // MARK: - Sport Chips

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

    // MARK: - Block Card

    private var blockCard: some View {
        Button {
            showBlockConfirm = true
        } label: {
            HStack(spacing: Spacing.m) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(AppColor.destructive)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Text("Block user")
                    .font(AppFont.body(.semibold))
                    .foregroundStyle(AppColor.destructive)

                Spacer()
            }
            .padding(Spacing.m)
            .background(AppColor.destructive.opacity(0.06))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppColor.destructive.opacity(0.20), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isBlocking)
    }
}

#Preview {
    NavigationStack {
        HostProfileView(userId: UUID(), currentUserId: UUID())
    }
}
