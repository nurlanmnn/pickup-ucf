import Foundation

enum DeepLinkRouter {
    enum Destination {
        case confirmEmail
        case resetPassword
        case session(UUID)
    }

    static func destination(from url: URL) -> Destination? {
        guard url.scheme == "pickupucf" else { return nil }
        switch url.host {
        case "auth":
            let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if path == "confirm" { return .confirmEmail }
            if path == "reset-password" { return .resetPassword }
            return nil
        case "session":
            let idString = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard let id = UUID(uuidString: idString) else { return nil }
            return .session(id)
        default:
            return nil
        }
    }
}
