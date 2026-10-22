import EventKit
import Foundation

enum CalendarExportError: LocalizedError {
    case accessDenied
    case alreadyAdded
    case saveFailed
    case accessRestricted
    case noWritableCalendar

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Allow adding events in Settings to save this game to Calendar."
        case .alreadyAdded:
            return "This game was previously added to Calendar."
        case .saveFailed:
            return "Could not save this game to your calendar."
        case .accessRestricted:
            return "Calendar access is restricted on this device. Check with your device administrator or parental controls."
        case .noWritableCalendar:
            return "Set up a writable calendar in Calendar, then try again."
        }
    }
}

@MainActor
protocol CalendarEventStoreProtocol: AnyObject {
    var authorizationStatus: EKAuthorizationStatus { get }
    var defaultCalendarForNewEvents: EKCalendar? { get }

    func makeEvent() -> EKEvent
    func save(_ event: EKEvent, span: EKSpan) throws
    func requestWriteOnlyAccessToEvents() async throws -> Bool
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

    func save(_ event: EKEvent, span: EKSpan) throws {
        try eventStore.save(event, span: span, commit: true)
    }

    func requestWriteOnlyAccessToEvents() async throws -> Bool {
        try await eventStore.requestWriteOnlyAccessToEvents()
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

    /// Local receipt only: write-only access cannot verify even our own events.
    /// Keep legacy identifiers opaque so upgrading does not create duplicates.
    func hasExportReceipt(sessionId: UUID) -> Bool {
        storage.eventIdentifier(for: sessionId) != nil
    }

    func addToCalendar(session: PickupSession, allowAnotherCopy: Bool = false) async throws {
        try Task.checkCancellation()
        if !allowAnotherCopy && hasExportReceipt(sessionId: session.id) {
            throw CalendarExportError.alreadyAdded
        }
        let granted = try await requestAccess()
        guard granted else { throw CalendarExportError.accessDenied }

        try Task.checkCancellation()
        if !allowAnotherCopy && hasExportReceipt(sessionId: session.id) {
            throw CalendarExportError.alreadyAdded
        }

        guard let calendar = eventStore.defaultCalendarForNewEvents else {
            throw CalendarExportError.noWritableCalendar
        }
        let event = eventStore.makeEvent()
        event.title = CalendarEventFormatting.title(for: session)
        event.notes = CalendarEventFormatting.notes(for: session)
        event.startDate = session.startsAt
        event.endDate = session.endsAt
        event.location = session.locationName
        event.calendar = calendar

        do {
            try eventStore.save(event, span: .thisEvent)
        } catch {
            throw CalendarExportError.saveFailed
        }

        // Saving can succeed without a readable identifier under write-only access.
        storage.setEventIdentifier(event.eventIdentifier ?? "saved", for: session.id)
    }

    private func requestAccess() async throws -> Bool {
        switch eventStore.authorizationStatus {
        case .fullAccess, .writeOnly:
            return true
        case .notDetermined:
            return try await eventStore.requestWriteOnlyAccessToEvents()
        case .restricted:
            throw CalendarExportError.accessRestricted
        case .denied:
            return false
        @unknown default:
            return false
        }
    }
}
