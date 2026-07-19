import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
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
        guard let urlString = userInfo["url"] as? String,
              let url = URL(string: urlString),
              case .session(let id) = DeepLinkRouter.destination(from: url) else { return }
        let openChat = (userInfo["open_chat"] as? Bool) == true
        NotificationCenter.default.post(
            name: .pushDeepLink,
            object: PushNavigationTarget(sessionId: id, openChat: openChat)
        )
    }
}

extension Notification.Name {
    static let pushDeepLink = Notification.Name("pushDeepLink")
}
