import Foundation

enum SessionShareLink {
    static func url(for sessionId: UUID) -> URL {
        URL(string: "pickupucf://session/\(sessionId.uuidString)")!
    }

    static func message(for session: PickupSession) -> String {
        let when = SessionDateFormatter.cardLabel(for: session.startsAt)
        let link = url(for: session.id).absoluteString
        return """
        \(session.sportDisplayName) pickup at \(session.locationName)
        \(when) · \(session.skillLevel.displayName)
        \(session.playerCount)/\(session.capacity) players

        Open in PickUp UCF:
        \(link)
        """
    }
}
