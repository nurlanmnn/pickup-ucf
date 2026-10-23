import XCTest
import Supabase
@testable import PickUpUCF

final class SessionCreationTests: XCTestCase {
    private let createdId = UUID()

    func testRetainedSessionDecodesAfterHostAccountDeletion() throws {
        var row = try XCTUnwrap(JSONSerialization.jsonObject(with: sessionData()) as? [String: Any])
        row["host_id"] = NSNull()
        row["host"] = NSNull()
        row["status"] = "cancelled"
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let session = try decoder.decode(PickupSession.self, from: JSONSerialization.data(withJSONObject: row))
        XCTAssertNil(session.hostId)
        XCTAssertNil(session.host)
        XCTAssertEqual(session.status, .cancelled)
        XCTAssertEqual(SessionRepository.filterBlockedHosts([session], blockedHostIds: [UUID()]).count, 1)
    }

    func testCreationUsesOneRPCWithoutCallerControlledHostOrCount() async throws {
        var requests: [URLRequest] = []
        let input = makeInput()
        AtomicCreationRequest.respond = { request in
            requests.append(request)
            if request.url!.path.hasSuffix("/rpc/create_session") {
                XCTAssertEqual(request.httpMethod, "POST")
                let body = try XCTUnwrap(try JSONSerialization.jsonObject(with: self.body(request)) as? [String: Any])
                XCTAssertEqual((body["p_request_id"] as? String)?.lowercased(), input.requestId.uuidString.lowercased())
                let fields = try XCTUnwrap(body["p_input"] as? [String: Any])
                XCTAssertNil(fields["host_id"])
                XCTAssertNil(fields["player_count"])
                XCTAssertEqual(fields["capacity"] as? Int, 10)
                return (200, Data("\"\(self.createdId.uuidString)\"".utf8))
            }
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertTrue(request.url!.absoluteString.contains(self.createdId.uuidString))
            return (200, try self.sessionData())
        }
        let session = try await makeRepository().createSession(input)
        XCTAssertEqual(session.id, createdId)
        XCTAssertEqual(requests.count, 2)
        XCTAssertFalse(requests.contains { $0.url!.path.contains("session_participants") })
    }

    func testLostReadResponseCanRetryTheSameCreationReceipt() async throws {
        var requestIDs: [String] = []
        var payloads: [Data] = []
        var failReads = true
        let input = makeInput()
        AtomicCreationRequest.respond = { request in
            if request.url!.path.hasSuffix("/rpc/create_session") {
                let fields = try JSONSerialization.jsonObject(with: self.body(request)) as! [String: Any]
                requestIDs.append(fields["p_request_id"] as! String)
                payloads.append(try JSONSerialization.data(withJSONObject: fields["p_input"]!, options: .sortedKeys))
                return (200, Data("\"\(self.createdId.uuidString)\"".utf8))
            }
            if failReads { throw URLError(.networkConnectionLost) }
            return (200, try self.sessionData())
        }
        let repository = makeRepository()
        do { _ = try await repository.createSession(input); XCTFail("Expected a lost response") }
        catch { XCTAssertTrue(error is URLError) }
        failReads = false
        let recovered = try await repository.createSession(input)
        XCTAssertEqual(recovered.id, createdId)
        XCTAssertEqual(requestIDs.count, 2)
        XCTAssertEqual(Set(requestIDs).count, 1)
        XCTAssertEqual(Set(payloads).count, 1, "Recurring settings must serialize identically on retry")
    }

    func testLostRPCResponseRetriesTheSameCommittedRequest() async throws {
        let input = makeInput()
        var failResponse = true
        var receipts: [String: UUID] = [:]
        AtomicCreationRequest.respond = { request in
            if request.url!.path.hasSuffix("/rpc/create_session") {
                let fields = try JSONSerialization.jsonObject(with: self.body(request)) as! [String: Any]
                let key = fields["p_request_id"] as! String
                receipts[key] = receipts[key] ?? self.createdId
                if failResponse { throw URLError(.networkConnectionLost) }
                return (200, Data("\"\(receipts[key]!.uuidString)\"".utf8))
            }
            return (200, try self.sessionData())
        }
        let repository = makeRepository()
        do { _ = try await repository.createSession(input); XCTFail("Expected a lost RPC response") }
        catch { XCTAssertTrue(error is URLError) }
        failResponse = false
        let session = try await repository.createSession(input)
        XCTAssertEqual(session.id, createdId)
        XCTAssertEqual(receipts.count, 1)
    }

    func testMissingRPCFailsWithoutLegacyInsertFallback() async {
        var paths: [String] = []
        AtomicCreationRequest.respond = { request in
            paths.append(request.url!.path)
            return (404, Data(#"{"code":"PGRST202","message":"Could not find public.create_session","details":null,"hint":null}"#.utf8))
        }
        do { _ = try await makeRepository().createSession(makeInput()); XCTFail("Expected missing RPC") }
        catch { XCTAssertEqual(AppErrorMapper.message(for: error), "Game creation is being updated. Please try again later.") }
        XCTAssertEqual(paths, ["/rest/v1/rpc/create_session"])
    }

    func testStructuredConflictAndInvalidInputHaveSafeRecoveryMessages() throws {
        let decoder = JSONDecoder()
        for (code, message, expected) in [
            ("PT409", "creation_request_conflict", "A previous attempt may already have created this game. Check My Games before starting a new one."),
            ("PT400", "invalid_session_input", "Check the sport, time, capacity, and location, then try again."),
            ("PT410", "creation_no_longer_available", "The game from this request is no longer available. Start a new session to create another.")
        ] {
            let data = try JSONSerialization.data(withJSONObject: ["code":code,"message":message])
            let error = try decoder.decode(PostgrestError.self, from: data)
            XCTAssertEqual(AppErrorMapper.message(for: error), expected)
        }
    }

    func testEditRenamesExistingOtherSport() async throws {
        let updated = try await applyEdit(
            existing: ["sport": "other", "custom_sport_name": "Old sport", "notes": "Other sport: Old sport"],
            sport: .other, customSportName: "  Badminton  "
        )
        XCTAssertEqual(updated.customSportName, "Badminton")
        XCTAssertEqual(updated.sportDisplayName, "Badminton")
    }

    func testEditClearsCustomSportWhenChoosingStandardSport() async throws {
        let updated = try await applyEdit(existing: ["sport": "other", "custom_sport_name": "Old sport"])
        XCTAssertEqual(updated.sport, .basketball)
        XCTAssertNil(updated.customSportName)
    }

    func testEditClearsBlankNotes() async throws {
        let updated = try await applyEdit(existing: ["notes": "Old notes"], notes: " \n ")
        XCTAssertNil(updated.notes)
    }

    func testEditSwitchesNamedVenueToCustomPin() async throws {
        let custom = CustomLocationSelection(label: "Synthetic field", latitude: 28.6, longitude: -81.2)
        let updated = try await applyEdit(existing: ["venue_id": UUID().uuidString], customLocation: custom)
        XCTAssertNil(updated.venueId)
        XCTAssertEqual(updated.customLocation, custom.label)
        XCTAssertEqual(updated.customLat, custom.latitude)
        XCTAssertEqual(updated.customLng, custom.longitude)
    }

    func testEditSwitchesCustomPinToNamedVenue() async throws {
        let venueId = UUID()
        let updated = try await applyEdit(
            existing: ["custom_location": "Old field", "custom_lat": 28.6, "custom_lng": -81.2],
            venueId: venueId
        )
        XCTAssertEqual(updated.venueId, venueId)
        XCTAssertNil(updated.customLocation)
        XCTAssertNil(updated.customLat)
        XCTAssertNil(updated.customLng)
    }

    func testCancellationRemainsAStatusOnlyPatch() async throws {
        var requestCount = 0
        AtomicCreationRequest.respond = { request in
            requestCount += 1
            XCTAssertEqual(request.httpMethod, "PATCH")
            let fields = try XCTUnwrap(try JSONSerialization.jsonObject(with: self.body(request)) as? [String: Any])
            XCTAssertEqual(Set(fields.keys), ["status"])
            XCTAssertEqual(fields["status"] as? String, "cancelled")
            return (204, Data())
        }
        try await makeRepository().cancelSession(id: createdId)
        XCTAssertEqual(requestCount, 1)
    }

    /// Model PostgREST PATCH: absent keys retain stored values; explicit null clears them.
    private func applyEdit(
        existing: [String: Any], sport: SportType = .basketball,
        customSportName: String? = nil, venueId: UUID? = nil,
        customLocation: CustomLocationSelection? = nil, notes: String? = nil
    ) async throws -> PickupSession {
        var stored = try XCTUnwrap(JSONSerialization.jsonObject(with: sessionData()) as? [String: Any])
        stored.merge(existing) { _, new in new }
        var requestCount = 0
        AtomicCreationRequest.respond = { request in
            requestCount += 1
            XCTAssertEqual(request.url?.host, "creation-tests.invalid")
            XCTAssertEqual(request.url?.path, "/rest/v1/sessions")
            XCTAssertEqual(request.httpMethod, "PATCH")
            XCTAssertTrue(request.url!.absoluteString.lowercased().contains(self.createdId.uuidString.lowercased()))
            let fields = try XCTUnwrap(try JSONSerialization.jsonObject(with: self.body(request)) as? [String: Any])
            XCTAssertNil(fields["host_id"])
            XCTAssertNil(fields["player_count"])
            XCTAssertNil(fields["status"])
            stored.merge(fields) { _, new in new }
            return (200, try JSONSerialization.data(withJSONObject: stored))
        }
        defer { AtomicCreationRequest.respond = nil }
        let updated = try await makeRepository().updateSession(id: createdId, input: UpdateSessionInput(
            sport: sport, customSportName: customSportName,
            venueId: customLocation == nil ? (venueId ?? UUID()) : nil,
            customLocation: customLocation, startsAt: .now.addingTimeInterval(7200),
            durationMinutes: 90, capacity: 10, skillLevel: .any, notes: notes
        ))
        XCTAssertEqual(requestCount, 1)
        return updated
    }

    private func makeInput() -> CreateSessionInput {
        CreateSessionInput(sport: .basketball, customSportName: nil, venueId: UUID(), customLocation: nil,
                           startsAt: .now.addingTimeInterval(7200), durationMinutes: 90, capacity: 10,
                           skillLevel: .any, notes: nil, recurrenceRule: .weekly(count: 4))
    }

    private func sessionData() throws -> Data {
        let session = PickupSession(id: createdId, hostId: UUID(), sport: .basketball,
                                    customLocation: "Synthetic court", startsAt: .now.addingTimeInterval(7200),
                                    endsAt: .now.addingTimeInterval(10800), capacity: 10, playerCount: 1,
                                    skillLevel: .any, status: .open)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(session)
    }

    private func makeRepository() -> SessionRepository {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AtomicCreationRequest.self]
        return SessionRepository(client: SupabaseClient(supabaseURL: URL(string: "https://creation-tests.invalid")!,
            supabaseKey: "synthetic-test-key", options: .init(
                auth: .init(storageKey: UUID().uuidString, autoRefreshToken: false),
                global: .init(session: URLSession(configuration: configuration)))))
    }

    private func body(_ request: URLRequest) throws -> Data {
        if let body = request.httpBody { return body }
        let stream = try XCTUnwrap(request.httpBodyStream)
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 2048)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(contentsOf: buffer.prefix(count))
        }
        return data
    }
}

private final class AtomicCreationRequest: URLProtocol {
    static var respond: ((URLRequest) throws -> (Int, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (status, data) = try Self.respond!(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil,
                                           headerFields: ["Content-Type":"application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}
