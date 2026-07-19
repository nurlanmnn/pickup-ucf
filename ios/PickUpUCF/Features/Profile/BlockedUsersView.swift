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
                } else {
                    List {
                        if let errorMessage = vm.errorMessage {
                            Section {
                                ErrorBanner(message: errorMessage)
                            }
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                        }

                        Section {
                            ForEach(users) { user in
                                HStack {
                                    VStack(alignment: .leading, spacing: Spacing.xs) {
                                        Text(user.displayName)
                                        Text(user.handle)
                                            .font(AppFont.caption())
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Button("Unblock") {
                                        Task { await viewModel.unblock(user: user) }
                                    }
                                    .disabled(vm.unblockingUserId == user.id)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Blocked users")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()
        }
        .refreshable {
            await viewModel.load()
        }
    }
}

#Preview {
    NavigationStack {
        BlockedUsersView()
    }
}
