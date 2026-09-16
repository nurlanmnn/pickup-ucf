import Foundation

enum BlockedMessageFilter {
    static func visibleMessages(
        _ messages: [SessionMessage],
        currentUserId: UUID,
        blockedUserIds: Set<UUID>
    ) -> [SessionMessage] {
        messages.filter { message in
            message.userId == currentUserId || !blockedUserIds.contains(message.userId)
        }
    }
}
