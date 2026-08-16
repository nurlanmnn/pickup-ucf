import SwiftUI

struct NotificationSettingsView: View {
    @State private var viewModel = NotificationSettingsViewModel()

    var body: some View {
        @Bindable var vm = viewModel

        ScrollView {
            VStack(spacing: Spacing.m) {
                if let error = vm.errorMessage {
                    ErrorBanner(message: error)
                }

                SettingsCardGroup(label: "Notifications") {
                    notificationRow(
                        title: "Session reminders",
                        description: "1 hour and 15 minutes before games you're in.",
                        systemImage: "clock.fill",
                        iconColor: Color(red: 0.24, green: 0.55, blue: 0.94),
                        isOn: vm.sessionReminders,
                        isDisabled: vm.isLoading || vm.isSaving,
                        onChange: { v in Task { await vm.updateSessionReminders(v) } }
                    )

                    Divider().padding(.leading, 46)

                    notificationRow(
                        title: "Waitlist promotions",
                        description: "When a spot opens up for you.",
                        systemImage: "arrow.up.circle.fill",
                        iconColor: AppColor.gold,
                        isOn: vm.waitlistPromoted,
                        isDisabled: vm.isLoading || vm.isSaving,
                        onChange: { v in Task { await vm.updateWaitlistPromoted(v) } }
                    )

                    Divider().padding(.leading, 46)

                    notificationRow(
                        title: "Cancelled games",
                        description: "When a host cancels a game you're in.",
                        systemImage: "xmark.circle.fill",
                        iconColor: AppColor.destructive,
                        isOn: vm.sessionCancelled,
                        isDisabled: vm.isLoading || vm.isSaving,
                        onChange: { v in Task { await vm.updateSessionCancelled(v) } }
                    )

                    Divider().padding(.leading, 46)

                    notificationRow(
                        title: "Player joined",
                        description: "When someone joins a game you're hosting.",
                        systemImage: "person.badge.plus",
                        iconColor: Color(red: 0.22, green: 0.72, blue: 0.33),
                        isOn: vm.hostPlayerJoined,
                        isDisabled: vm.isLoading || vm.isSaving,
                        onChange: { v in Task { await vm.updateHostPlayerJoined(v) } }
                    )

                    Divider().padding(.leading, 46)

                    notificationRow(
                        title: "Host reminders",
                        description: "1 hour before games you're hosting.",
                        systemImage: "megaphone.fill",
                        iconColor: Color(red: 0.96, green: 0.50, blue: 0.14),
                        isOn: vm.hostSessionReminder,
                        isDisabled: vm.isLoading || vm.isSaving,
                        onChange: { v in Task { await vm.updateHostSessionReminder(v) } }
                    )

                    Divider().padding(.leading, 46)

                    notificationRow(
                        title: "Chat messages",
                        description: "New messages in session chats.",
                        systemImage: "bubble.left.fill",
                        iconColor: Color(red: 0.24, green: 0.55, blue: 0.94),
                        isOn: vm.chatMessages,
                        isDisabled: vm.isLoading || vm.isSaving,
                        onChange: { v in Task { await vm.updateChatMessages(v) } }
                    )
                }

                Text("Changes save automatically.")
                    .font(AppFont.caption())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Spacing.xs)
            }
            .padding(Spacing.m)
        }
        .appScreenBackground()
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if vm.isLoading { ProgressView() }
        }
        .task { await viewModel.load() }
    }

    private func notificationRow(
        title: String,
        description: String,
        systemImage: String,
        iconColor: Color,
        isOn: Bool,
        isDisabled: Bool,
        onChange: @escaping (_ newValue: Bool) -> Void
    ) -> some View {
        Toggle(isOn: Binding(get: { isOn }, set: { onChange($0) })) {
            HStack(spacing: Spacing.m) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(iconColor)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppFont.body())
                    Text(description)
                        .font(AppFont.caption())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .tint(AppColor.gold)
        .disabled(isDisabled)
        .padding(.vertical, Spacing.s + 2)
        .padding(.horizontal, Spacing.m)
    }
}

#Preview {
    NavigationStack { NotificationSettingsView() }
}
