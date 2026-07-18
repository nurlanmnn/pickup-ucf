import SwiftUI

struct ProfileSettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var showSignOutConfirm = false
    @State private var errorMessage: String?

    private let repository: AuthRepositoryProtocol = AuthRepository()

    var body: some View {
        List {
            if let errorMessage {
                Section {
                    ErrorBanner(message: errorMessage)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section("Account") {
                NavigationLink("Edit sports") {
                    EditPreferredSportsView()
                }
                NavigationLink("Edit username") {
                    EditUsernameView()
                }
                NavigationLink("Change password") {
                    ChangePasswordView()
                }
            }

            Section {
                NavigationLink("Delete account") {
                    DeleteAccountView()
                }
                .foregroundStyle(AppColor.destructive)
            }

            Section {
                Button("Sign out", role: .destructive) {
                    showSignOutConfirm = true
                }
            }
        }
        .navigationTitle("Settings")
        .confirmationDialog("Sign out?", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) {
                Task {
                    errorMessage = nil
                    do {
                        try await repository.signOut()
                        appState.session = nil
                    } catch {
                        errorMessage = AppErrorMapper.message(for: error)
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
