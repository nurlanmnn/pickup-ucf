import ActivityKit
import Foundation

@MainActor
enum GameLiveActivityManager {
    private static var operationTask: Task<Void, Never>?

    @discardableResult
    private static func enqueue(_ operation: @escaping @MainActor () async -> Void) -> Task<Void, Never> {
        let previous = operationTask
        let task = Task {
            await previous?.value
            await operation()
        }
        operationTask = task
        return task
    }

    @available(iOS 16.2, *)
    static func start(for session: PickupSession, now: Date = Date()) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        guard GameLiveActivitySelection.isEligible(session: session, now: now) else { return }

        enqueue {
            await finishExpired(now: now)
            // Opening another session must not replace an earlier active game.
            if let current = Activity<GameLiveActivityAttributes>.activities.first,
               current.attributes.sessionId != session.id.uuidString,
               current.content.state.startsAt <= session.startsAt,
               current.content.state.endsAt > now {
                return
            }
            await reconcile(session: session)
        }
    }

    @available(iOS 16.2, *)
    static func refresh(upcomingSessions: [PickupSession], now: Date = Date()) {
        enqueue {
            await finishExpired(now: now)
            guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
            guard let session = GameLiveActivitySelection.nextSession(from: upcomingSessions, now: now) else {
                await finishAll()
                return
            }
            await reconcile(session: session)
        }
    }

    @available(iOS 16.2, *)
    private static func reconcile(session: PickupSession) async {
        let activities = Activity<GameLiveActivityAttributes>.activities
        if let current = activities.first,
           current.attributes.sessionId == session.id.uuidString,
           current.attributes.sportName == session.sportDisplayName,
           current.attributes.locationName == session.locationName,
           current.activityState != .ended,
           current.activityState != .dismissed {
            for duplicate in activities.dropFirst() { await end(duplicate) }
            let content = ActivityContent(
                state: contentState(for: session),
                staleDate: GameLiveActivitySelection.contentStaleDate(for: session)
            )
            await current.update(content)
            if let token = current.pushToken {
                Task { await registerPushToken(token, sessionId: session.id) }
            }
            return
        }
        await finishAll()
        await requestActivity(for: session)
    }

    @available(iOS 16.2, *)
    static func end(forSessionId sessionId: UUID) async {
        await enqueue {
            for activity in Activity<GameLiveActivityAttributes>.activities
                where activity.attributes.sessionId == sessionId.uuidString {
                await end(activity)
            }
            await SessionNotificationCleanup.removeDelivered(sessionId: sessionId)
        }.value
    }

    @available(iOS 16.2, *)
    static func nextExpirationDate() -> Date? {
        Activity<GameLiveActivityAttributes>.activities.map { $0.content.state.endsAt }.min()
    }

    @available(iOS 16.2, *)
    static func endExpired(now: Date = Date()) async {
        await enqueue { await finishExpired(now: now) }.value
    }

    @available(iOS 16.2, *)
    private static func finishExpired(now: Date) async {
        for activity in Activity<GameLiveActivityAttributes>.activities
            where activity.content.state.endsAt <= now
                || activity.content.state.startsAt.timeIntervalSince(now) > GameLiveActivitySelection.preStartWindow {
            await end(activity)
        }
    }

    @available(iOS 16.2, *)
    private static func requestActivity(for session: PickupSession) async {
        guard GameLiveActivitySelection.isEligible(session: session, now: Date()) else { return }
        let attributes = GameLiveActivityAttributes(
            sportName: session.sportDisplayName,
            locationName: session.locationName,
            sessionId: session.id.uuidString,
            sportSystemImage: session.sport.systemImage
        )
        let content = ActivityContent(
            state: contentState(for: session),
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
    fileprivate static func endAll() async {
        await enqueue { await finishAll() }.value
    }

    @available(iOS 16.2, *)
    private static func finishAll() async {
        for activity in Activity<GameLiveActivityAttributes>.activities {
            await end(activity)
        }
    }

    private static func contentState(for session: PickupSession) -> GameLiveActivityAttributes.ContentState {
        GameLiveActivityAttributes.ContentState(
            startsAt: session.startsAt,
            endsAt: session.endsAt
        )
    }

    @available(iOS 16.2, *)
    private static func end(_ activity: Activity<GameLiveActivityAttributes>) async {
        let finalContent = ActivityContent(
            state: activity.content.state,
            staleDate: nil
        )
        await activity.end(finalContent, dismissalPolicy: .immediate)
    }
}

private extension Data {
    var hexEncodedString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}

enum GameLiveActivityCoordinator {
    static func refreshForCurrentUser(userId: UUID) async {
        let repository = SessionRepository()
        do {
            let sessions = try await repository.fetchMySessions(userId: userId)
            let statuses = try await repository.fetchParticipantStatuses(
                userId: userId, sessionIds: sessions.map(\.id)
            )
            guard await AuthRepository().currentSession()?.userId == userId else { return }
            refresh(upcomingSessions: sessions.filter {
                $0.hostId == userId || statuses[$0.id] == .joined
            })
        } catch {
            // Preserve the current activity if the network is unavailable.
        }
    }

    static func start(for session: PickupSession, now: Date = Date()) {
        if #available(iOS 16.2, *) {
            Task { @MainActor in GameLiveActivityManager.start(for: session, now: now) }
        }
    }

    static func refresh(upcomingSessions: [PickupSession], now: Date = Date()) {
        if #available(iOS 16.2, *) {
            Task { @MainActor in GameLiveActivityManager.refresh(upcomingSessions: upcomingSessions, now: now) }
        }
    }

    static func end(forSessionId sessionId: UUID) {
        if #available(iOS 16.2, *) {
            Task {
                await GameLiveActivityManager.end(forSessionId: sessionId)
            }
        }
    }

    static func nextCleanupDelay(now: Date = Date()) async -> TimeInterval {
        if #available(iOS 16.2, *), let end = await GameLiveActivityManager.nextExpirationDate() {
            return max(0.1, min(30, end.timeIntervalSince(now)))
        }
        return 30
    }

    static func endExpired(now: Date = Date()) async {
        if #available(iOS 16.2, *) {
            await GameLiveActivityManager.endExpired(now: now)
        }
    }

    static func endAllForAccountTransition() async {
        if #available(iOS 16.2, *) {
            await GameLiveActivityManager.endAll()
        }
    }
}
