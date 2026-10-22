import EventKit
import XCTest
@testable import PickUpUCF

final class CalendarExportServiceTests: XCTestCase {
    func testDeliveredSessionNotificationExpiresExactlyAtEnd() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let payload: [AnyHashable: Any] = [
            "session_id": UUID().uuidString,
            "session_ends_at": "2023-11-14T22:13:20.000Z"
        ]
        XCTAssertFalse(PushNotificationPayload.isExpired(payload, now: now.addingTimeInterval(-1)))
        XCTAssertTrue(PushNotificationPayload.isExpired(payload, now: now))
        XCTAssertTrue(PushNotificationPayload.isExpired(payload, now: now.addingTimeInterval(1)))
        XCTAssertFalse(PushNotificationPayload.isExpired(["session_ends_at": "bad-date"], now: now))
    }

    func testFinishedSessionCleanupPayloadHasSessionId() {
        let id = UUID()
        XCTAssertEqual(PushNotificationPayload.cleanupSessionId(from: [
            "notification_type": "session_finished", "session_id": id.uuidString
        ]), id)
        XCTAssertNil(PushNotificationPayload.cleanupSessionId(from: [
            "notification_type": "chat_message", "session_id": id.uuidString
        ]))
    }

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
    func testWriteOnlyRetainsReceiptWithoutReadingEvent() {
        let sessionId = UUID()
        let storage = CalendarExportEventStorageSpy()
        storage.setEventIdentifier("legacy-export", for: sessionId)
        let store = CalendarEventStoreSpy()
        store.authorizationStatus = .writeOnly
        let service = CalendarExportService(eventStore: store, storage: storage)
        XCTAssertTrue(service.hasExportReceipt(sessionId: sessionId))
        XCTAssertEqual(storage.eventIdentifier(for: sessionId), "legacy-export")
    }

    @MainActor
    func testDeniedDoesNotRequestPermissionAgain() async {
        let store = CalendarEventStoreSpy()
        store.authorizationStatus = .denied
        let service = CalendarExportService(eventStore: store, storage: CalendarExportEventStorageSpy())
        do {
            try await service.addToCalendar(session: makeSession())
            XCTFail("Expected denial")
        } catch {}
        XCTAssertEqual(store.permissionRequestCount, 0)
        XCTAssertEqual(store.saveCount, 0)
    }

    @MainActor
    func testSuccessfulSaveWithoutReadableIdentifierPreventsDuplicate() async throws {
        let store = CalendarEventStoreSpy()
        store.authorizationStatus = .writeOnly
        let service = CalendarExportService(eventStore: store, storage: CalendarExportEventStorageSpy())
        let session = makeSession()
        try await service.addToCalendar(session: session)
        do {
            try await service.addToCalendar(session: session)
            XCTFail("Expected duplicate rejection")
        } catch CalendarExportError.alreadyAdded {} catch { XCTFail("Wrong failure") }
        XCTAssertEqual(store.saveCount, 1)
        XCTAssertEqual(store.permissionRequestCount, 0)
    }

    @MainActor
    func testInitialAllowRequestsWriteOnlyAndSavesExpectedFields() async throws {
        let store = CalendarEventStoreSpy()
        store.authorizationStatus = .notDetermined
        let service = CalendarExportService(eventStore: store, storage: CalendarExportEventStorageSpy())
        let session = makeSession()
        try await service.addToCalendar(session: session)
        XCTAssertEqual(store.permissionRequestCount, 1)
        XCTAssertEqual(store.authorizationStatus, .writeOnly)
        XCTAssertEqual(store.savedEvent?.title, "Basketball · Campus court")
        XCTAssertEqual(store.savedEvent?.startDate, session.startsAt)
        XCTAssertEqual(store.savedEvent?.endDate, session.endsAt)
        XCTAssertEqual(store.savedEvent?.location, session.locationName)
        XCTAssertTrue(store.savedEvent?.notes?.contains("Bring water") == true)
        XCTAssertTrue(store.savedEvent?.notes?.contains(SessionShareLink.url(for: session.id).absoluteString) == true)
    }

    @MainActor
    func testInitialDenialAndSettingsRecovery() async throws {
        let store = CalendarEventStoreSpy()
        store.authorizationStatus = .notDetermined
        store.permissionGranted = false
        let service = CalendarExportService(eventStore: store, storage: CalendarExportEventStorageSpy())
        let session = makeSession()
        do {
            try await service.addToCalendar(session: session)
            XCTFail("Expected denial")
        } catch CalendarExportError.accessDenied {} catch { XCTFail("Wrong failure") }
        XCTAssertFalse(service.hasExportReceipt(sessionId: session.id))
        XCTAssertEqual(store.saveCount, 0)
        store.authorizationStatus = .writeOnly // User enables access in Settings.
        try await service.addToCalendar(session: session)
        XCTAssertEqual(store.permissionRequestCount, 1)
        XCTAssertEqual(store.saveCount, 1)
    }

    @MainActor
    func testRestrictedDoesNotPromptOrSave() async {
        let store = CalendarEventStoreSpy()
        store.authorizationStatus = .restricted
        let service = CalendarExportService(eventStore: store, storage: CalendarExportEventStorageSpy())
        do {
            try await service.addToCalendar(session: makeSession())
            XCTFail("Expected restriction")
        } catch CalendarExportError.accessRestricted {} catch { XCTFail("Wrong failure") }
        XCTAssertEqual(store.permissionRequestCount, 0)
        XCTAssertEqual(store.saveCount, 0)
    }

    @MainActor
    func testMissingCalendarDoesNotRecordExportAndCanRetry() async throws {
        let store = CalendarEventStoreSpy()
        store.hasCalendar = false
        let service = CalendarExportService(eventStore: store, storage: CalendarExportEventStorageSpy())
        let session = makeSession()
        do {
            try await service.addToCalendar(session: session)
            XCTFail("Expected no writable destination")
        } catch CalendarExportError.noWritableCalendar {} catch { XCTFail("Wrong failure") }
        XCTAssertFalse(service.hasExportReceipt(sessionId: session.id))
        store.hasCalendar = true
        try await service.addToCalendar(session: session)
        XCTAssertEqual(store.saveCount, 1)
    }

    @MainActor
    func testExplicitReplacementAfterExternalDeletionAndFailedSaveKeepsReceipt() async throws {
        let session = makeSession()
        let storage = CalendarExportEventStorageSpy()
        storage.setEventIdentifier("legacy-export", for: session.id)
        let store = CalendarEventStoreSpy() // External Calendar event is absent.
        let service = CalendarExportService(eventStore: store, storage: storage)
        store.saveError = CalendarEventStoreSpy.TestError.saveFailed
        do {
            try await service.addToCalendar(session: session, allowAnotherCopy: true)
            XCTFail("Expected save failure")
        } catch CalendarExportError.saveFailed {} catch { XCTFail("Wrong failure") }
        XCTAssertEqual(storage.eventIdentifier(for: session.id), "legacy-export")
        store.saveError = nil
        try await service.addToCalendar(session: session, allowAnotherCopy: true)
        XCTAssertTrue(service.hasExportReceipt(sessionId: session.id))
        XCTAssertEqual(store.saveCount, 1)
    }

    @MainActor
    func testRevokedPermissionKeepsPriorExportReceipt() {
        let session = makeSession()
        let storage = CalendarExportEventStorageSpy()
        storage.setEventIdentifier("legacy-export", for: session.id)
        let store = CalendarEventStoreSpy()
        store.authorizationStatus = .denied
        let service = CalendarExportService(eventStore: store, storage: storage)
        XCTAssertTrue(service.hasExportReceipt(sessionId: session.id))
    }

    @MainActor
    func testCancelledTaskDoesNotSaveOrRecordExport() async {
        let store = CalendarEventStoreSpy()
        store.authorizationStatus = .notDetermined
        let service = CalendarExportService(eventStore: store, storage: CalendarExportEventStorageSpy())
        let session = makeSession()
        let task = Task { @MainActor in
            withUnsafeCurrentTask { $0?.cancel() }
            do {
                try await service.addToCalendar(session: session)
                XCTFail("Expected cancellation")
            } catch is CancellationError {} catch { XCTFail("Wrong failure") }
        }
        await task.value
        XCTAssertEqual(store.saveCount, 0)
        XCTAssertFalse(service.hasExportReceipt(sessionId: session.id))
        XCTAssertEqual(store.permissionRequestCount, 0)
    }

    private func makeSession() -> PickupSession {
        PickupSession(id: UUID(), hostId: UUID(), sport: .basketball,
                      customLocation: "Campus court", startsAt: Date(timeIntervalSince1970: 1_800_000_000),
                      endsAt: Date(timeIntervalSince1970: 1_800_003_600), capacity: 10,
                      playerCount: 1, skillLevel: .any, notes: "Bring water", status: .open)
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
        case saveFailed
    }

    var authorizationStatus: EKAuthorizationStatus = .fullAccess
    var permissionRequestCount = 0
    var saveCount = 0
    var permissionGranted = true
    var saveError: Error?
    var hasCalendar = true
    var savedEvent: EKEvent?

    private let backingStore = EKEventStore()

    var defaultCalendarForNewEvents: EKCalendar? {
        hasCalendar ? EKCalendar(for: .event, eventStore: backingStore) : nil
    }

    func makeEvent() -> EKEvent {
        EKEvent(eventStore: backingStore)
    }

    func save(_ event: EKEvent, span: EKSpan) throws {
        if let saveError { throw saveError }
        savedEvent = event
        saveCount += 1
    }

    func requestWriteOnlyAccessToEvents() async throws -> Bool {
        permissionRequestCount += 1
        authorizationStatus = permissionGranted ? .writeOnly : .denied
        return permissionGranted
    }
}
