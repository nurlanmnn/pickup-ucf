import Foundation

enum DeepLinkRouter {
    static let webHost = "pickup-ucf-privacy.vercel.app"
    static let passwordResetURL = URL(string: "https://\(webHost)/auth/reset-password")!

    enum Destination {
        case confirmEmail
        case resetPassword
        case session(UUID)
    }

    static func destination(from url: URL) -> Destination? {
        guard url.user == nil, url.password == nil, url.port == nil,
              url.fragment == nil else { return nil }
        let isWeb = url.scheme == "https" && url.host == webHost
        let isLegacySession = url.scheme == "pickupucf" && url.host == "session"
        guard isWeb || isLegacySession else { return nil }

        if isWeb && ["/auth/confirm", "/auth/reset-password"].contains(url.path) {
            guard let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
                  items.count == 1, items[0].name == "code",
                  let code = items[0].value, !code.isEmpty, code.utf8.count <= 2048,
                  code.unicodeScalars.allSatisfy({ !CharacterSet.whitespacesAndNewlines.contains($0) && !CharacterSet.controlCharacters.contains($0) }) else { return nil }
            return url.path == "/auth/reset-password" ? .resetPassword : .confirmEmail
        }

        guard url.query == nil else { return nil }
        let prefix = isLegacySession ? "/" : "/session/"
        guard url.path.hasPrefix(prefix) else { return nil }
        let value = String(url.path.dropFirst(prefix.count))
        guard let id = UUID(uuidString: value), value.count == 36 else { return nil }
        return .session(id)
    }
}
