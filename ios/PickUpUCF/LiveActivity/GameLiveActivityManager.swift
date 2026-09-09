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
                let content = ActivityContent(
                    state: GameLiveActivityAttributes.ContentState(startsAt: session.startsAt),
                    staleDate: GameLiveActivitySelection.contentStaleDate(for: session)
                )
                await current.update(content)
                if let token = current.pushToken {
                    await registerPushToken(token, sessionId: session.id)
                }
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
        let content = ActivityContent(
            state: GameLiveActivityAttributes.ContentState(startsAt: session.startsAt),
            staleDate: GameLiveActivitySelection.contentStaleDate(for: session)
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: .token
            )
            observePushTokens(for: activity, sessionId: session.id)
        } catch {
            // Live Activities are optional; ignore request failures in v1.
        }
    }

    @available(iOS 16.2, *)
    private static func observePushTokens(
        for activity: Activity<GameLiveActivityAttributes>,
        sessionId: UUID
    ) {
        Task {
            if let token = activity.pushToken {
                await registerPushToken(token, sessionId: sessionId)
            }

            for await token in activity.pushTokenUpdates {
                await registerPushToken(token, sessionId: sessionId)
            }
        }
    }

    private static func registerPushToken(_ token: Data, sessionId: UUID) async {
        try? await LiveActivityTokenRepository().register(
            sessionId: sessionId,
            token: token.hexEncodedString
        )
    }

    @available(iOS 16.2, *)
    private static func endAll() async {
        for activity in Activity<GameLiveActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}

private extension Data {
    var hexEncodedString: String {
        map { String(format: "%02x", $0) }.joined()
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
