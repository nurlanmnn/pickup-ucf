import EventKit
import Foundation

enum CalendarExportError: LocalizedError {
    case accessDenied
    case alreadyAdded
    case saveFailed
    case removeFailed

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Calendar access is required to save this game."
        case .alreadyAdded:
            return "This game is already in your calendar."
        case .saveFailed:
            return "Could not save this game to your calendar."
        case .removeFailed:
            return "Could not remove this cancelled game from your calendar."
        }
    }
}

@MainActor
protocol CalendarEventStoreProtocol: AnyObject {
    var authorizationStatus: EKAuthorizationStatus { get }
    var defaultCalendarForNewEvents: EKCalendar? { get }

    func makeEvent() -> EKEvent
    func event(withIdentifier identifier: String) -> EKEvent?
    func save(_ event: EKEvent, span: EKSpan) throws
    func remove(_ event: EKEvent, span: EKSpan) throws
    func requestFullAccessToEvents() async throws -> Bool
}

@MainActor
private final class EventKitCalendarEventStore: CalendarEventStoreProtocol {
    private let eventStore = EKEventStore()

    var authorizationStatus: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    var defaultCalendarForNewEvents: EKCalendar? {
        eventStore.defaultCalendarForNewEvents
    }

    func makeEvent() -> EKEvent {
        EKEvent(eventStore: eventStore)
    }

    func event(withIdentifier identifier: String) -> EKEvent? {
        eventStore.event(withIdentifier: identifier)
    }

    func save(_ event: EKEvent, span: EKSpan) throws {
        try eventStore.save(event, span: span, commit: true)
    }

    func remove(_ event: EKEvent, span: EKSpan) throws {
        // Apple documents commit: true as an immediate, rollback-safe removal.
        // https://developer.apple.com/documentation/eventkit/ekeventstore/remove(_:span:commit:)
        try eventStore.remove(event, span: span, commit: true)
    }

    func requestFullAccessToEvents() async throws -> Bool {
        try await eventStore.requestFullAccessToEvents()
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

    private let eventStore: CalendarEventStoreProtocol
    private let storage: CalendarExportEventStorageProtocol

    init(
        eventStore: CalendarEventStoreProtocol? = nil,
        storage: CalendarExportEventStorageProtocol = UserDefaultsCalendarExportEventStorage()
    ) {
        self.eventStore = eventStore ?? EventKitCalendarEventStore()
        self.storage = storage
    }

    func isSessionInCalendar(sessionId: UUID) -> Bool {
        guard let storedEventId = storage.eventIdentifier(for: sessionId) else { return false }

        switch eventStore.authorizationStatus {
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

        let event = eventStore.makeEvent()
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

    /// Removes an app-created event after its session is cancelled.
    /// Returns true when a stored export was removed or was already absent.
    func removeFromCalendar(sessionId: UUID) throws -> Bool {
        guard let storedEventId = storage.eventIdentifier(for: sessionId) else {
            return false
        }

        // Write-only access cannot reliably fetch a previously-created event by identifier.
        // Keep the identifier so cleanup can be retried if full access is restored.
        guard eventStore.authorizationStatus == .fullAccess else {
            return false
        }

        guard let event = eventStore.event(withIdentifier: storedEventId) else {
            storage.setEventIdentifier(nil, for: sessionId)
            return true
        }

        do {
            try eventStore.remove(event, span: .thisEvent)
        } catch {
            throw CalendarExportError.removeFailed
        }

        storage.setEventIdentifier(nil, for: sessionId)
        return true
    }

    private func requestAccess() async throws -> Bool {
        try await eventStore.requestFullAccessToEvents()
    }
}
