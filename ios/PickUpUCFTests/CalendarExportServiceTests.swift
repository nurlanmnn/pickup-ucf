import EventKit
import XCTest
@testable import PickUpUCF

final class CalendarExportServiceTests: XCTestCase {
    func testStorageRoundTrip() {
        let defaults = UserDefaults(suiteName: #function)!
        defer { defaults.removePersistentDomain(forName: #function) }

        let storage = UserDefaultsCalendarExportEventStorage(defaults: defaults)
        let sessionId = UUID()

        XCTAssertNil(storage.eventIdentifier(for: sessionId))

        storage.setEventIdentifier("event-123", for: sessionId)
        XCTAssertEqual(storage.eventIdentifier(for: sessionId), "event-123")

        storage.setEventIdentifier(nil, for: sessionId)
        XCTAssertNil(storage.eventIdentifier(for: sessionId))
    }

    @MainActor
    func testRemoveFromCalendarDeletesStoredEventAndIdentifier() throws {
        let sessionId = UUID()
        let storage = CalendarExportEventStorageSpy()
        storage.setEventIdentifier("event-123", for: sessionId)
        let eventStore = CalendarEventStoreSpy()
        eventStore.eventsByIdentifier["event-123"] = eventStore.makeEvent()
        let service = CalendarExportService(eventStore: eventStore, storage: storage)

        let removed = try service.removeFromCalendar(sessionId: sessionId)

        XCTAssertTrue(removed)
        XCTAssertEqual(eventStore.removedEventCount, 1)
        XCTAssertNil(storage.eventIdentifier(for: sessionId))
    }

    @MainActor
    func testRemoveFromCalendarClearsIdentifierWhenEventNoLongerExists() throws {
        let sessionId = UUID()
        let storage = CalendarExportEventStorageSpy()
        storage.setEventIdentifier("missing-event", for: sessionId)
        let eventStore = CalendarEventStoreSpy()
        let service = CalendarExportService(eventStore: eventStore, storage: storage)

        let removed = try service.removeFromCalendar(sessionId: sessionId)

        XCTAssertTrue(removed)
        XCTAssertEqual(eventStore.removedEventCount, 0)
        XCTAssertNil(storage.eventIdentifier(for: sessionId))
    }

    @MainActor
    func testRemoveFromCalendarKeepsIdentifierWhenDeletionFails() {
        let sessionId = UUID()
        let storage = CalendarExportEventStorageSpy()
        storage.setEventIdentifier("event-123", for: sessionId)
        let eventStore = CalendarEventStoreSpy()
        eventStore.eventsByIdentifier["event-123"] = eventStore.makeEvent()
        eventStore.removeError = CalendarEventStoreSpy.TestError.removeFailed
        let service = CalendarExportService(eventStore: eventStore, storage: storage)

        XCTAssertThrowsError(try service.removeFromCalendar(sessionId: sessionId))
        XCTAssertEqual(storage.eventIdentifier(for: sessionId), "event-123")
    }

    func testCancellationSessionIdRequiresCancellationTypeAndValidSessionId() {
        let sessionId = UUID()

        XCTAssertEqual(
            PushNotificationPayload.cancellationSessionId(from: [
                "notification_type": "session_cancelled",
                "session_id": sessionId.uuidString,
            ]),
            sessionId
        )
        XCTAssertNil(PushNotificationPayload.cancellationSessionId(from: [
            "notification_type": "chat_message",
            "session_id": sessionId.uuidString,
        ]))
        XCTAssertNil(PushNotificationPayload.cancellationSessionId(from: [
            "notification_type": "session_cancelled",
            "session_id": "not-a-uuid",
        ]))
    }
}

private final class CalendarExportEventStorageSpy: CalendarExportEventStorageProtocol {
    private var identifiers: [UUID: String] = [:]

    func eventIdentifier(for sessionId: UUID) -> String? {
        identifiers[sessionId]
    }

    func setEventIdentifier(_ identifier: String?, for sessionId: UUID) {
        identifiers[sessionId] = identifier
    }
}

@MainActor
private final class CalendarEventStoreSpy: CalendarEventStoreProtocol {
    enum TestError: Error {
        case removeFailed
    }

    var authorizationStatus: EKAuthorizationStatus = .fullAccess
    var eventsByIdentifier: [String: EKEvent] = [:]
    var removedEventCount = 0
    var removeError: Error?

    private let backingStore = EKEventStore()

    var defaultCalendarForNewEvents: EKCalendar? { nil }

    func makeEvent() -> EKEvent {
        EKEvent(eventStore: backingStore)
    }

    func event(withIdentifier identifier: String) -> EKEvent? {
        eventsByIdentifier[identifier]
    }

    func save(_ event: EKEvent, span: EKSpan) throws {}

    func remove(_ event: EKEvent, span: EKSpan) throws {
        if let removeError { throw removeError }
        removedEventCount += 1
    }

    func requestFullAccessToEvents() async throws -> Bool {
        true
    }
}
