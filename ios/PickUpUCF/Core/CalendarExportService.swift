import EventKit
import Foundation

enum CalendarExportError: LocalizedError {
    case accessDenied
    case alreadyAdded
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Calendar access is required to save this game."
        case .alreadyAdded:
            return "This game is already in your calendar."
        case .saveFailed:
            return "Could not save this game to your calendar."
        }
    }
}

protocol CalendarExportEventStorageProtocol {
    func eventIdentifier(for sessionId: UUID) -> String?
    func setEventIdentifier(_ identifier: String?, for sessionId: UUID)
}

struct UserDefaultsCalendarExportEventStorage: CalendarExportEventStorageProtocol {
    private let defaults: UserDefaults
    private let keyPrefix = "calendar_export_event_id_"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func eventIdentifier(for sessionId: UUID) -> String? {
        defaults.string(forKey: keyPrefix + sessionId.uuidString)
    }

    func setEventIdentifier(_ identifier: String?, for sessionId: UUID) {
        let key = keyPrefix + sessionId.uuidString
        if let identifier {
            defaults.set(identifier, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}

enum CalendarEventFormatting {
    static func title(for session: PickupSession) -> String {
        "\(session.sportDisplayName) · \(session.locationName)"
    }

    static func notes(for session: PickupSession) -> String {
        var lines: [String] = []
        if let host = session.host?.handle {
            lines.append("Host: \(host)")
        }
        lines.append(SessionShareLink.url(for: session.id).absoluteString)
        if let notes = session.notesForDisplay, !notes.isEmpty {
            lines.append(notes)
        }
        return lines.joined(separator: "\n")
    }
}

@MainActor
final class CalendarExportService {
    static let shared = CalendarExportService()

    private let eventStore: EKEventStore
    private let storage: CalendarExportEventStorageProtocol

    init(
        eventStore: EKEventStore = EKEventStore(),
        storage: CalendarExportEventStorageProtocol = UserDefaultsCalendarExportEventStorage()
    ) {
        self.eventStore = eventStore
        self.storage = storage
    }

    func isSessionInCalendar(sessionId: UUID) -> Bool {
        guard let storedEventId = storage.eventIdentifier(for: sessionId) else { return false }

        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess, .writeOnly:
            if eventStore.event(withIdentifier: storedEventId) != nil {
                return true
            }
            storage.setEventIdentifier(nil, for: sessionId)
            return false
        default:
            // Added before but calendar access is unavailable — assume still present.
            return true
        }
    }

    func addToCalendar(session: PickupSession) async throws {
        let granted = try await requestAccess()
        guard granted else { throw CalendarExportError.accessDenied }

        if isSessionInCalendar(sessionId: session.id) {
            throw CalendarExportError.alreadyAdded
        }

        let event = EKEvent(eventStore: eventStore)
        event.title = CalendarEventFormatting.title(for: session)
        event.notes = CalendarEventFormatting.notes(for: session)
        event.startDate = session.startsAt
        event.endDate = session.endsAt
        event.location = session.locationName
        event.calendar = eventStore.defaultCalendarForNewEvents

        do {
            try eventStore.save(event, span: .thisEvent)
        } catch {
            throw CalendarExportError.saveFailed
        }

        guard let eventIdentifier = event.eventIdentifier else {
            throw CalendarExportError.saveFailed
        }
        storage.setEventIdentifier(eventIdentifier, for: session.id)
    }

    private func requestAccess() async throws -> Bool {
        try await eventStore.requestFullAccessToEvents()
    }
}
