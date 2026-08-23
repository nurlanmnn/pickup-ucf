import SwiftUI

@Observable
final class BlockedUsersViewModel {
    var blockedUsers = Loadable<[BlockedUser]>.idle
    var unblockingUserId: UUID?
    var errorMessage: String?

    private let repository: BlockRepositoryProtocol

    init(repository: BlockRepositoryProtocol = BlockRepository()) {
        self.repository = repository
    }

    @MainActor
    func load() async {
        blockedUsers = .loading
        errorMessage = nil
        do {
            let users = try await repository.fetchBlockedUsers()
            blockedUsers = .loaded(users)
        } catch {
            blockedUsers = .failed(AppErrorMapper.message(for: error))
        }
    }

    @MainActor
    func unblock(user: BlockedUser) async {
        errorMessage = nil
        unblockingUserId = user.id
        defer { unblockingUserId = nil }
        do {
            try await repository.unblock(userId: user.id)
            await load()
        } catch {
            errorMessage = AppErrorMapper.message(for: error)
        }
    }
}

struct BlockedUsersView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel = BlockedUsersViewModel()

    var body: some View {
        @Bindable var vm = viewModel

        Group {
            switch vm.blockedUsers {
            case .idle, .loading:
                ProgressView("Loading blocked users…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let message):
                VStack(spacing: Spacing.m) {
                    ErrorBanner(message: message)
                    PrimaryButton(title: "Try again") {
                        Task { await viewModel.load() }
                    }
                    .padding(.horizontal, Spacing.m)
                }
            case .loaded(let users):
                if users.isEmpty {
                    EmptyStateView(
                        symbol: "hand.raised",
                        title: "No blocked users",
                        message: "People you block won't appear in Discover and you can't join their games."
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: Spacing.m) {
                            if let errorMessage = vm.errorMessage {
                                ErrorBanner(message: errorMessage)
                            }

                            SettingsCardGroup {
                                ForEach(Array(users.enumerated()), id: \.element.id) { index, user in
                                    if index > 0 { Divider().padding(.leading, Spacing.m) }

                                    HStack(spacing: Spacing.m) {
                                        Image(systemName: "person.fill")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(.white)
                                            .frame(width: 30, height: 30)
                                            .background(AppColor.textSecondary(colorScheme))
                                            .clipShape(Circle())

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(user.displayName)
                                                .font(AppFont.body(.semibold))
                                            Text(user.handle)
                                                .font(AppFont.caption())
                                                .foregroundStyle(AppColor.textSecondary(colorScheme))
                                        }

                                        Spacer()

                                        Button("Unblock") {
                                            Task { await viewModel.unblock(user: user) }
                                        }
                                        .font(AppFont.caption(.semibold))
                                        .foregroundStyle(AppColor.gold)
                                        .disabled(vm.unblockingUserId == user.id)
                                    }
                                    .padding(.vertical, Spacing.s + 2)
                                    .padding(.horizontal, Spacing.m)
                                }
                            }
                        }
                        .padding(Spacing.m)
                    }
                }
            }
        }
        .appScreenBackground()
        .navigationTitle("Blocked users")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }
}

#Preview {
    NavigationStack { BlockedUsersView() }
}
