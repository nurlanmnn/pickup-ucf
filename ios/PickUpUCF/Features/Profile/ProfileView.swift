import SwiftUI

struct ProfileView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @State private var profile: Profile?
    @State private var profileLoadError: String?

    private let profileRepository: ProfileRepositoryProtocol = ProfileRepository()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: Spacing.s) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 72))
                            .foregroundStyle(AppColor.gold)

                        Text(profile?.displayName ?? appState.session?.email ?? "Student")
                            .font(AppFont.headline())

                        if let username = profile?.username, !username.isEmpty {
                            Text("@\(username)")
                                .font(AppFont.caption())
                                .foregroundStyle(AppColor.textSecondary(colorScheme))
                        } else {
                            Text("Add a @username in Settings (optional)")
                                .font(AppFont.caption())
                                .foregroundStyle(AppColor.textSecondary(colorScheme))
                        }

                        if let profile {
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

                        if let profileLoadError {
                            Text(profileLoadError)
                                .font(AppFont.caption())
                                .foregroundStyle(AppColor.destructive)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }

                Section {
                    NavigationLink("Settings") {
                        ProfileSettingsView()
                    }
                }
            }
            .navigationTitle("Profile")
            .task(id: appState.session?.userId) {
                await loadProfile()
            }
            .onChange(of: appState.profileRefreshNonce) { _, _ in
                Task { await loadProfile() }
            }
        }
    }

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
