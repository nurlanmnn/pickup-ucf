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
            case .failed(let message):
                VStack(spacing: Spacing.m) {
                    ErrorBanner(message: message)
                    PrimaryButton(title: "Try again") {
                        Task { await viewModel.load() }
                    }
                    .padding(.horizontal, Spacing.m)
                }
            case .loaded(let profile):
                profileContent(profile)
            }
        }
        .background(AppColor.background(colorScheme))
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

    @ViewBuilder
    private func profileContent(_ profile: Profile) -> some View {
        ScrollView {
            VStack(spacing: Spacing.l) {
                VStack(spacing: Spacing.s) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(AppColor.gold)

                    Text(profile.displayName)
                        .font(AppFont.headline())

                    if let username = profile.username, !username.isEmpty {
                        Text("@\(username)")
                            .font(AppFont.caption())
                            .foregroundStyle(AppColor.textSecondary(colorScheme))
                    }

                    Text("\(profile.gamesPlayed) games played")
                        .font(AppFont.caption())
                        .foregroundStyle(AppColor.textSecondary(colorScheme))

                    Text("\(profile.showUpStreak) show-up streak")
                        .font(AppFont.caption())
                        .foregroundStyle(AppColor.textSecondary(colorScheme))

                    if !profile.preferredSports.isEmpty {
                        Text(profile.preferredSports.map(\.displayName).joined(separator: ", "))
                            .font(AppFont.caption())
                            .foregroundStyle(AppColor.textSecondary(colorScheme))
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, Spacing.l)

                if let errorMessage = viewModel.errorMessage {
                    ErrorBanner(message: errorMessage)
                        .padding(.horizontal, Spacing.m)
                }

                if canShowBlock {
                    Button(role: .destructive) {
                        showBlockConfirm = true
                    } label: {
                        Text("Block user")
                            .font(AppFont.headline(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isBlocking)
                    .padding(.horizontal, Spacing.m)
                }
            }
            .padding(.bottom, Spacing.l)
        }
    }
}

#Preview {
    NavigationStack {
        HostProfileView(userId: UUID(), currentUserId: UUID())
    }
}
