import Foundation

enum GameLiveActivitySelection {
    static let preStartWindow: TimeInterval = 24 * 3600

    static func isEligible(session: PickupSession, now: Date) -> Bool {
        guard now < activityEndDate(for: session) else { return false }
        return session.startsAt.timeIntervalSince(now) <= preStartWindow
    }

    static func nextSession(from sessions: [PickupSession], now: Date) -> PickupSession? {
        sessions
            .filter { isEligible(session: $0, now: now) }
            .sorted { $0.startsAt < $1.startsAt }
            .first
    }

    static func activityEndDate(for session: PickupSession) -> Date {
        session.endsAt
    }

    static func contentStaleDate(for session: PickupSession) -> Date {
        session.startsAt
    }
}
