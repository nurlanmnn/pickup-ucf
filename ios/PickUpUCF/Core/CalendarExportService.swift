import EventKit
import Foundation

enum CalendarExportError: LocalizedError {
    case accessDenied
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Calendar access is required to save this game."
        case .saveFailed:
            return "Could not save this game to your calendar."
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

    init(eventStore: EKEventStore = EKEventStore()) {
        self.eventStore = eventStore
    }

    func addToCalendar(session: PickupSession) async throws {
        let granted = try await requestAccess()
        guard granted else { throw CalendarExportError.accessDenied }

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
    }

    private func requestAccess() async throws -> Bool {
        try await eventStore.requestFullAccessToEvents()
    }
}
