import Foundation

struct NotificationPreferences: Codable, Equatable {
    var userId: UUID
    var sessionReminders: Bool
    var waitlistPromoted: Bool
    var sessionCancelled: Bool
    var hostPlayerJoined: Bool
    var hostSessionReminder: Bool
    var chatMessages: Bool
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case sessionReminders = "session_reminders"
        case waitlistPromoted = "waitlist_promoted"
        case sessionCancelled = "session_cancelled"
        case hostPlayerJoined = "host_player_joined"
        case hostSessionReminder = "host_session_reminder"
        case chatMessages = "chat_messages"
        case updatedAt = "updated_at"
    }

    init(
        userId: UUID,
        sessionReminders: Bool = true,
        waitlistPromoted: Bool = true,
        sessionCancelled: Bool = true,
        hostPlayerJoined: Bool = true,
        hostSessionReminder: Bool = true,
        chatMessages: Bool = true,
        updatedAt: Date? = nil
    ) {
        self.userId = userId
        self.sessionReminders = sessionReminders
        self.waitlistPromoted = waitlistPromoted
        self.sessionCancelled = sessionCancelled
        self.hostPlayerJoined = hostPlayerJoined
        self.hostSessionReminder = hostSessionReminder
        self.chatMessages = chatMessages
        self.updatedAt = updatedAt
    }

    static func defaults(userId: UUID) -> NotificationPreferences {
        NotificationPreferences(userId: userId)
    }
}
