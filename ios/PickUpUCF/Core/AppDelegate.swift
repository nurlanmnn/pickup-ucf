import UIKit
import UserNotifications

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
