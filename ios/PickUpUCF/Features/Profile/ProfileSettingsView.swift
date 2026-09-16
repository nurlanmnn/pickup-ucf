import SwiftUI

struct ProfileSettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @State private var showSignOutConfirm = false
    @State private var errorMessage: String?

    private let repository: AuthRepositoryProtocol = AuthRepository()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.m) {
                if let errorMessage {
                    ErrorBanner(message: errorMessage)
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
                SettingsCardGroup(label: "Privacy") {
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
    }
}

#Preview {
    NavigationStack {
        ProfileSettingsView()
            .environment(AppState())
    }
}
