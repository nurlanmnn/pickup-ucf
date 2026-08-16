import ActivityKit
import Foundation

enum GameLiveActivityManager {
    @available(iOS 16.2, *)
    static func start(for session: PickupSession, now: Date = Date()) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        guard GameLiveActivitySelection.isEligible(session: session, now: now) else { return }

        Task {
            await endAll()
            await requestActivity(for: session)
        }
    }

    @available(iOS 16.2, *)
    static func refresh(upcomingSessions: [PickupSession], now: Date = Date()) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        Task {
            guard let session = GameLiveActivitySelection.nextSession(from: upcomingSessions, now: now) else {
                await endAll()
                return
            }

            let activities = Activity<GameLiveActivityAttributes>.activities
            if let current = activities.first,
               current.attributes.sessionId == session.id.uuidString,
               current.activityState != .ended,
               current.activityState != .dismissed {
                let endDate = GameLiveActivitySelection.activityEndDate(for: session)
                let content = ActivityContent(
                    state: GameLiveActivityAttributes.ContentState(startsAt: session.startsAt),
                    staleDate: endDate
                )
                await current.update(content)
                return
            }

            await endAll()
            await requestActivity(for: session)
        }
    }

    @available(iOS 16.2, *)
    static func end(forSessionId sessionId: UUID) async {
        for activity in Activity<GameLiveActivityAttributes>.activities
            where activity.attributes.sessionId == sessionId.uuidString {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    @available(iOS 16.2, *)
    private static func requestActivity(for session: PickupSession) async {
        let attributes = GameLiveActivityAttributes(
            sportName: session.sportDisplayName,
            locationName: session.locationName,
            sessionId: session.id.uuidString,
            sportSystemImage: session.sport.systemImage
        )
        let endDate = GameLiveActivitySelection.activityEndDate(for: session)
        let content = ActivityContent(
            state: GameLiveActivityAttributes.ContentState(startsAt: session.startsAt),
            staleDate: endDate
        )

        do {
            _ = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
        } catch {
            // Live Activities are optional; ignore request failures in v1.
        }
    }

    @available(iOS 16.2, *)
    private static func endAll() async {
        for activity in Activity<GameLiveActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}

enum GameLiveActivityCoordinator {
    static func start(for session: PickupSession, now: Date = Date()) {
        if #available(iOS 16.2, *) {
            GameLiveActivityManager.start(for: session, now: now)
        }
    }

    static func refresh(upcomingSessions: [PickupSession], now: Date = Date()) {
        if #available(iOS 16.2, *) {
            GameLiveActivityManager.refresh(upcomingSessions: upcomingSessions, now: now)
        }
    }

    static func end(forSessionId sessionId: UUID) {
        if #available(iOS 16.2, *) {
            Task {
                await GameLiveActivityManager.end(forSessionId: sessionId)
            }
        }
    }
}
