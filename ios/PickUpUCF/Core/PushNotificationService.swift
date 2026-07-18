import UIKit
import UserNotifications

@MainActor
final class PushNotificationService: NSObject {
    static let shared = PushNotificationService()
    private let tokenRepository: DeviceTokenRepositoryProtocol

    init(tokenRepository: DeviceTokenRepositoryProtocol = DeviceTokenRepository()) {
        self.tokenRepository = tokenRepository
    }

    func requestAuthorizationAndRegister() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            guard granted else { return }
            UIApplication.shared.registerForRemoteNotifications()
        } catch {
            // Non-fatal; user can enable later in Settings
        }
    }

    func handleDeviceToken(_ deviceToken: Data) async {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        try? await tokenRepository.upsert(token: token)
    }
}
