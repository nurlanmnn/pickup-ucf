import Foundation

@Observable
final class NotificationSettingsViewModel {
    var sessionReminders = true
    var waitlistPromoted = true
    var sessionCancelled = true
    var hostPlayerJoined = true
    var hostSessionReminder = true
    var chatMessages = true
    var errorMessage: String?
    var isLoading = false
    var isSaving = false

    private var userId: UUID?
    private let repository: NotificationPreferencesRepositoryProtocol

    init(repository: NotificationPreferencesRepositoryProtocol = NotificationPreferencesRepository()) {
        self.repository = repository
    }

    @MainActor
    func load() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let preferences = try await repository.fetch()
            apply(preferences)
        } catch {
            errorMessage = AppErrorMapper.message(for: error)
        }
    }

    @MainActor
    func updateSessionReminders(_ value: Bool) async {
        sessionReminders = value
        await saveCurrentPreferences()
    }

    @MainActor
    func updateWaitlistPromoted(_ value: Bool) async {
        waitlistPromoted = value
        await saveCurrentPreferences()
    }

    @MainActor
    func updateSessionCancelled(_ value: Bool) async {
        sessionCancelled = value
        await saveCurrentPreferences()
    }

    @MainActor
    func updateHostPlayerJoined(_ value: Bool) async {
        hostPlayerJoined = value
        await saveCurrentPreferences()
    }

    @MainActor
    func updateHostSessionReminder(_ value: Bool) async {
        hostSessionReminder = value
        await saveCurrentPreferences()
    }

    @MainActor
    func updateChatMessages(_ value: Bool) async {
        chatMessages = value
        await saveCurrentPreferences()
    }

    private func apply(_ preferences: NotificationPreferences) {
        userId = preferences.userId
        sessionReminders = preferences.sessionReminders
        waitlistPromoted = preferences.waitlistPromoted
        sessionCancelled = preferences.sessionCancelled
        hostPlayerJoined = preferences.hostPlayerJoined
        hostSessionReminder = preferences.hostSessionReminder
        chatMessages = preferences.chatMessages
    }

    @MainActor
    private func saveCurrentPreferences() async {
        guard let userId else { return }

        errorMessage = nil
        isSaving = true
        defer { isSaving = false }

        let preferences = NotificationPreferences(
            userId: userId,
            sessionReminders: sessionReminders,
            waitlistPromoted: waitlistPromoted,
            sessionCancelled: sessionCancelled,
            hostPlayerJoined: hostPlayerJoined,
            hostSessionReminder: hostSessionReminder,
            chatMessages: chatMessages
        )

        do {
            try await repository.save(preferences)
        } catch {
            errorMessage = AppErrorMapper.message(for: error)
            await load()
        }
    }
}
