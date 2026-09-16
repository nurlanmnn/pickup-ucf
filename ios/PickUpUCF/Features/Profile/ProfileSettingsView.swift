import SwiftUI

struct ProfileSettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @State private var showSignOutConfirm = false
    @State private var errorMessage: String?
    @State private var isModerator = false
    @State private var moderationNotices: [ModerationNotice] = []

    private let repository: AuthRepositoryProtocol = AuthRepository()
    private let moderationRepository: ModerationRepositoryProtocol = ModerationRepository()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.m) {
                if let errorMessage {
                    ErrorBanner(message: errorMessage)
                }

                ForEach(moderationNotices) { notice in
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        Label(
                            notice.kind == .suspendUser ? "Account suspended" : "Community warning",
                            systemImage: "exclamationmark.shield.fill"
                        )
                        .font(AppFont.body(.semibold))
                        .foregroundStyle(AppColor.destructive)
                        Text(notice.message)
                            .font(AppFont.body())
                            .foregroundStyle(AppColor.textPrimary(colorScheme))
                        Button("Acknowledge") {
                            Task { await acknowledge(notice) }
                        }
                        .font(AppFont.body(.semibold))
                    }
                    .padding(Spacing.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColor.destructive.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                // Account
                SettingsCardGroup(label: "Account") {
                    NavigationLink {
                        EditPreferredSportsView()
                    } label: {
                        SettingsRow(
                            systemImage: "sportscourt.fill",
                            iconColor: Color(red: 0.24, green: 0.55, blue: 0.94),
                            title: "Edit sports"
                        )
                    }
                    .buttonStyle(.plain)

                    Divider().padding(.leading, 46)

                    NavigationLink {
                        EditUsernameView()
                    } label: {
                        SettingsRow(
                            systemImage: "at",
                            iconColor: Color(red: 0.24, green: 0.55, blue: 0.94),
                            title: "Edit username"
                        )
                    }
                    .buttonStyle(.plain)

                    Divider().padding(.leading, 46)

                    NavigationLink {
                        ChangePasswordView()
                    } label: {
                        SettingsRow(
                            systemImage: "lock.fill",
                            iconColor: Color(red: 0.96, green: 0.50, blue: 0.14),
                            title: "Change password"
                        )
                    }
                    .buttonStyle(.plain)
                }

                // Notifications
                SettingsCardGroup(label: "Notifications") {
                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        SettingsRow(
                            systemImage: "bell.fill",
                            iconColor: Color(red: 0.96, green: 0.50, blue: 0.14),
                            title: "Notification settings"
                        )
                    }
                    .buttonStyle(.plain)
                }

                // Privacy
                SettingsCardGroup(label: "Safety & Privacy") {
                    NavigationLink {
                        CommunityRulesView()
                    } label: {
                        SettingsRow(
                            systemImage: "checkmark.shield.fill",
                            iconColor: AppColor.gold,
                            title: "Community rules"
                        )
                    }
                    .buttonStyle(.plain)

                    Divider().padding(.leading, 46)

                    NavigationLink {
                        BlockedUsersView()
                    } label: {
                        SettingsRow(
                            systemImage: "hand.raised.fill",
                            iconColor: Color(red: 0.64, green: 0.24, blue: 0.88),
                            title: "Blocked users"
                        )
                    }
                    .buttonStyle(.plain)

                    Divider().padding(.leading, 46)

                    Link(destination: URL(string: "https://pickup-ucf-privacy.vercel.app")!) {
                        SettingsRow(
                            systemImage: "hand.raised.square.fill",
                            iconColor: Color(red: 0.64, green: 0.24, blue: 0.88),
                            title: "Privacy Policy"
                        )
                    }
                    .buttonStyle(.plain)

                    Divider().padding(.leading, 46)

                    Link(destination: URL(string: "mailto:support.roomateapp@gmail.com?subject=PickUp%20UCF%20Support")!) {
                        SettingsRow(
                            systemImage: "envelope.fill",
                            iconColor: Color(red: 0.24, green: 0.55, blue: 0.94),
                            title: "Contact support"
                        )
                    }
                    .buttonStyle(.plain)
                }

                if isModerator {
                    SettingsCardGroup(label: "Moderation") {
                        NavigationLink {
                            ModerationQueueView()
                        } label: {
                            SettingsRow(
                                systemImage: "shield.lefthalf.filled",
                                iconColor: AppColor.destructive,
                                title: "Review reports"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Danger zone
                SettingsCardGroup {
                    NavigationLink {
                        DeleteAccountView()
                    } label: {
                        SettingsRow(
                            systemImage: "trash.fill",
                            iconColor: AppColor.destructive,
                            title: "Delete account",
                            isDestructive: true
                        )
                    }
                    .buttonStyle(.plain)
                }

                // Sign out — standalone button, not a card row
                Button {
                    showSignOutConfirm = true
                } label: {
                    Text("Sign out")
                        .font(AppFont.body(.semibold))
                        .foregroundStyle(AppColor.destructive)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.m)
                        .background(AppColor.destructive.opacity(0.08))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(AppColor.destructive.opacity(0.20), lineWidth: 1)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(Spacing.m)
        }
        .scrollContentBackground(.hidden)
        .appScreenBackground()
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .confirmationDialog("Sign out?", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) {
                Task {
                    errorMessage = nil
                    let outcome = await AccountTransitionCoordinator.signOut(
                        appState: appState,
                        unregisterToken: {
                            try await PushNotificationService.shared.unregisterForAccountTransition()
                        },
                        signOut: { try await repository.signOut() }
                    )
                    if outcome == .completedWithWarning {
                        appState.showError(
                            "You’re signed out. Some server cleanup could not be confirmed."
                        )
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .task {
            async let moderator = moderationRepository.isCurrentUserModerator()
            async let notices = moderationRepository.fetchNotices()
            isModerator = (try? await moderator) ?? false
            moderationNotices = (try? await notices) ?? []
        }
    }

    @MainActor
    private func acknowledge(_ notice: ModerationNotice) async {
        do {
            try await moderationRepository.acknowledgeNotice(id: notice.id)
            moderationNotices.removeAll { $0.id == notice.id }
        } catch {
            errorMessage = AppErrorMapper.message(for: error)
        }
    }
}

#Preview {
    NavigationStack {
        ProfileSettingsView()
            .environment(AppState())
    }
}
