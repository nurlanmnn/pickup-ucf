import UIKit
import UserNotifications

enum PushNotificationPayload {
    static func cleanupSessionId(from userInfo: [AnyHashable: Any]) -> UUID? {
        guard let type = userInfo["notification_type"] as? String,
              ["session_cancelled", "session_finished"].contains(type),
              let rawId = userInfo["session_id"] as? String else { return nil }
        return UUID(uuidString: rawId)
    }

    static func isExpired(_ userInfo: [AnyHashable: Any], now: Date) -> Bool {
        guard let rawEnd = userInfo["session_ends_at"] as? String else { return false }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let end = formatter.date(from: rawEnd) ?? ISO8601DateFormatter().date(from: rawEnd)
        return end.map { $0 <= now } ?? false
    }

    static func cancellationSessionId(from userInfo: [AnyHashable: Any]) -> UUID? {
        guard userInfo["notification_type"] as? String == "session_cancelled",
              let rawSessionId = userInfo["session_id"] as? String else {
            return nil
        }
        return UUID(uuidString: rawSessionId)
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        configureNavigationAppearance()
        return true
    }

    /// Applies SF Rounded to all navigation bar titles app-wide.
    private func configureNavigationAppearance() {
        func roundedFont(textStyle: UIFont.TextStyle, traits: UIFontDescriptor.SymbolicTraits = []) -> UIFont {
            let base = UIFontDescriptor.preferredFontDescriptor(withTextStyle: textStyle)
            let rounded = base.withDesign(.rounded) ?? base
            let styled = rounded.withSymbolicTraits(traits) ?? rounded
            return UIFont(descriptor: styled, size: 0)
        }

        UINavigationBar.appearance().largeTitleTextAttributes = [
            .font: roundedFont(textStyle: .largeTitle, traits: .traitBold),
        ]
        UINavigationBar.appearance().titleTextAttributes = [
            .font: roundedFont(textStyle: .headline, traits: .traitBold),
        ]
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { await PushNotificationService.shared.handleDeviceToken(deviceToken) }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }
        let userInfo = response.notification.request.content.userInfo
        removeCalendarEventIfCancelled(userInfo)
        guard let urlString = userInfo["url"] as? String,
              let url = URL(string: urlString),
              case .session(let id) = DeepLinkRouter.destination(from: url) else { return }
        let openChat = (userInfo["open_chat"] as? Bool) == true
        NotificationCenter.default.post(
            name: .pushDeepLink,
            object: PushNavigationTarget(sessionId: id, openChat: openChat)
        )
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        removeCalendarEventIfCancelled(notification.request.content.userInfo)
        // Preserve the existing behavior of suppressing banners while foregrounded.
        completionHandler([])
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        guard let sessionId = PushNotificationPayload.cleanupSessionId(from: userInfo) else {
            completionHandler(.noData)
            return
        }

        GameLiveActivityCoordinator.end(forSessionId: sessionId)
        Task { @MainActor in
            await SessionNotificationCleanup.removeDelivered(sessionId: sessionId)
            if PushNotificationPayload.cancellationSessionId(from: userInfo) != nil {
                _ = try? CalendarExportService.shared.removeFromCalendar(sessionId: sessionId)
            }
            completionHandler(.newData)
        }
    }

    private func removeCalendarEventIfCancelled(_ userInfo: [AnyHashable: Any]) {
        guard let sessionId = PushNotificationPayload.cancellationSessionId(from: userInfo) else {
            return
        }

        GameLiveActivityCoordinator.end(forSessionId: sessionId)
        Task { @MainActor in
            await SessionNotificationCleanup.removeDelivered(sessionId: sessionId)
            _ = try? CalendarExportService.shared.removeFromCalendar(sessionId: sessionId)
        }
    }
}

extension Notification.Name {
    static let pushDeepLink = Notification.Name("pushDeepLink")
}


/// Cleanup ordinary Notification Center alerts as well as the separate Live Activity.
@MainActor
enum SessionNotificationCleanup {
    private static var canonicalEndDates: [UUID: Date] = [:]
    static func removeDelivered(sessionId: UUID? = nil, now: Date = Date(), resolveSessions: Bool = false) async {
        let center = UNUserNotificationCenter.current()
        let notifications = await center.deliveredNotifications()
        var identifiers: [String] = []
        if resolveSessions {
            let sessionIds = Set(notifications.compactMap { notification -> UUID? in
                let info = notification.request.content.userInfo
                guard let rawId = info["session_id"] as? String else { return nil }
                return UUID(uuidString: rawId)
            })
            let repository = SessionRepository()
            for id in sessionIds {
                if let session = try? await repository.fetchSession(id: id) {
                    let end = (session.status == .cancelled || session.status == .completed) ? now : session.endsAt
                    canonicalEndDates[id] = end
                }
            }
        }
        for notification in notifications {
            let info = notification.request.content.userInfo
            let id = (info["session_id"] as? String).flatMap(UUID.init(uuidString:))
            let isExpired = id.flatMap { canonicalEndDates[$0] }.map { $0 <= now }
                ?? PushNotificationPayload.isExpired(info, now: now)
            if (sessionId != nil && id == sessionId)
                || isExpired {
                identifiers.append(notification.request.identifier)
            }
        }
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
        // Bound the cache to notifications still present on this device.
        let remainingIds = Set(notifications.filter {
            !identifiers.contains($0.request.identifier)
        }.compactMap { ($0.request.content.userInfo["session_id"] as? String).flatMap(UUID.init(uuidString:)) })
        canonicalEndDates = canonicalEndDates.filter { remainingIds.contains($0.key) }
    }
}
