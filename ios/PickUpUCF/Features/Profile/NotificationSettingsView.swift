import SwiftUI

struct NotificationSettingsView: View {
    @State private var viewModel = NotificationSettingsViewModel()

    var body: some View {
        @Bindable var vm = viewModel

        Form {
            InlineFeedbackSection(error: vm.errorMessage)

            Section {
                notificationToggle(
                    title: "Session reminders",
                    description: "1 hour and 15 minutes before games you're in.",
                    isOn: vm.sessionReminders,
                    isDisabled: vm.isLoading || vm.isSaving
                ) { newValue in
                    Task { await vm.updateSessionReminders(newValue) }
                }

                notificationToggle(
                    title: "Waitlist promotions",
                    description: "When a spot opens up for you.",
                    isOn: vm.waitlistPromoted,
                    isDisabled: vm.isLoading || vm.isSaving
                ) { newValue in
                    Task { await vm.updateWaitlistPromoted(newValue) }
                }

                notificationToggle(
                    title: "Cancelled games",
                    description: "When a host cancels a game you're in.",
                    isOn: vm.sessionCancelled,
                    isDisabled: vm.isLoading || vm.isSaving
                ) { newValue in
                    Task { await vm.updateSessionCancelled(newValue) }
                }

                notificationToggle(
                    title: "Player joined",
                    description: "When someone joins a game you're hosting.",
                    isOn: vm.hostPlayerJoined,
                    isDisabled: vm.isLoading || vm.isSaving
                ) { newValue in
                    Task { await vm.updateHostPlayerJoined(newValue) }
                }

                notificationToggle(
                    title: "Host reminders",
                    description: "1 hour before games you're hosting.",
                    isOn: vm.hostSessionReminder,
                    isDisabled: vm.isLoading || vm.isSaving
                ) { newValue in
                    Task { await vm.updateHostSessionReminder(newValue) }
                }

                notificationToggle(
                    title: "Chat messages",
                    description: "New messages in session chats.",
                    isOn: vm.chatMessages,
                    isDisabled: vm.isLoading || vm.isSaving
                ) { newValue in
                    Task { await vm.updateChatMessages(newValue) }
                }
            } footer: {
                Text("Changes save automatically.")
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if vm.isLoading {
                ProgressView()
            }
        }
        .task {
            await viewModel.load()
        }
    }

    private func notificationToggle(
        title: String,
        description: String,
        isOn: Bool,
        isDisabled: Bool,
        onChange: @escaping (Bool) -> Void
    ) -> some View {
        Toggle(isOn: Binding(
            get: { isOn },
            set: { onChange($0) }
        )) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title)
                Text(description)
                    .font(AppFont.caption())
                    .foregroundStyle(.secondary)
            }
        }
        .disabled(isDisabled)
    }
}

#Preview {
    NavigationStack {
        NotificationSettingsView()
    }
}
