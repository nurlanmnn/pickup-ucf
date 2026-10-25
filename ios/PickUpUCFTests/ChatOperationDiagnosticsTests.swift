import XCTest
import Supabase
@testable import PickUpUCF

final class ChatOperationDiagnosticsTests: XCTestCase {
    private var records: [ChatOperationDiagnostics.Record] = []
    private var requests: [URLRequest] = []
    private let sessionID = UUID()
    private let messageID = UUID()
    private let userID = UUID()
    private let timestamp = "2026-10-24T12:00:00.123456+00:00"

    override func tearDown() {
        ChatDiagnosticRequest.respond = nil
        super.tearDown()
    }

    func testPageKindsPreserveLookaheadChronologyAndExactCursor() async throws {
        let otherID = UUID()
        let repo = makeRepository { _ in
            (200, try JSONSerialization.data(withJSONObject: [self.row(), self.row(id: otherID)]))
        }
        let first = try await repo.fetchMessages(sessionId: sessionID, limit: 1)
        XCTAssertEqual(first.messages.map(\.id), [messageID])
        XCTAssertEqual(first.nextCursor, ChatMessageCursor(timestamp: timestamp, id: messageID))
        let older = try await repo.fetchMessages(sessionId: sessionID, before: first.nextCursor, limit: 1)
        XCTAssertEqual(older.messages.map(\.id), [messageID])
        XCTAssertEqual(query(requests[0], "limit"), "2")
        XCTAssertEqual(query(requests[0], "order"), "created_at.desc.nullslast,id.desc.nullslast")
        XCTAssertNil(query(requests[0], "or"))
        XCTAssertEqual(query(requests[1], "or"), "(created_at.lt.\(timestamp),and(created_at.eq.\(timestamp),id.lt.\(messageID.uuidString)))")
        XCTAssertEqual(records.map(\.operation), [.fetchFirst, .fetchOlder])
        XCTAssertTrue(records.allSatisfy { $0.result == .succeeded && $0.failure == .none })
        for record in records { try assertPrivate(record) }
    }

    func testTargetedUpdatesPreserveSessionFilterIDsAndAuthorSelectionAndEmptyNoOp() async throws {
        let repo = makeRepository { _ in (200, try JSONSerialization.data(withJSONObject: [self.row()])) }
        let rows = try await repo.fetchMessageUpdates(sessionId: sessionID, ids: [messageID])
        let empty = try await repo.fetchMessageUpdates(sessionId: sessionID, ids: [])
        XCTAssertEqual(rows.map(\.id), [messageID])
        XCTAssertTrue(empty.isEmpty)
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(query(requests[0], "session_id"), "eq.\(sessionID.uuidString)")
        XCTAssertEqual(query(requests[0], "id"), "in.(\(messageID.uuidString))")
        XCTAssertEqual(query(requests[0], "limit"), "50")
        XCTAssertTrue(query(requests[0], "select")!.contains("id,display_name,username"))
        XCTAssertEqual(records.map(\.operation), [.fetchUpdates])
        try assertPrivate(records[0])
    }

    func testSendRetainsNormalizedPayloadReturnedRowAndOneBoundary() async throws {
        let (repo, client) = makeClient { request in
            if request.url!.path.hasSuffix("/token") { return (200, try self.authSession()) }
            return (201, try JSONSerialization.data(withJSONObject: self.row()))
        }
        _ = try await client.auth.signIn(email: "private@ucf.edu", password: "private-password")
        requests.removeAll()
        let sent = try await repo.sendMessage(sessionId: sessionID, body: "  private-body  ")
        XCTAssertEqual(sent.id, messageID)
        XCTAssertEqual(sent.body, "private-body")
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests[0].httpMethod, "POST")
        let payload = try body(requests[0])
        XCTAssertEqual(Set(payload.keys), Set(["session_id", "user_id", "body"]))
        XCTAssertEqual(payload["body"] as? String, "private-body")
        XCTAssertEqual(payload["session_id"] as? String, sessionID.uuidString)
        XCTAssertEqual(payload["user_id"] as? String, userID.uuidString)
        XCTAssertEqual(records.map(\.operation), [.send])
        XCTAssertEqual(records[0].result, .succeeded)
        try assertPrivate(records[0])
    }

    func testSendBackendFailureRetainsErrorAndNeverEmitsSuccess() async throws {
        let (repo, client) = makeClient { request in
            if request.url!.path.hasSuffix("/token") { return (200, try self.authSession()) }
            return (403, Data(#"{"code":"42501","message":"private-body private-token"}"#.utf8))
        }
        _ = try await client.auth.signIn(email: "private@ucf.edu", password: "private-password")
        requests.removeAll()
        do { _ = try await repo.sendMessage(sessionId: sessionID, body: "private-body"); XCTFail() }
        catch let error as PostgrestError { XCTAssertEqual(error.code, "42501"); XCTAssertEqual(error.message, "private-body private-token") }
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests[0].httpMethod, "POST")
        XCTAssertEqual(records.map(\.operation), [.send])
        XCTAssertEqual(records.map(\.failure), [.backend])
        XCTAssertEqual(records.map(\.result), [.failed])
        try assertPrivate(records[0])
    }

    func testInvalidSendPreservesValidationAndMakesNoAttempt() async throws {
        let repo = makeRepository { _ in XCTFail("No backend request expected"); return (200, Data()) }
        do { _ = try await repo.sendMessage(sessionId: sessionID, body: " \n "); XCTFail() }
        catch let error as ChatRepositoryError { guard case .emptyMessage = error else { return XCTFail() } }
        do { _ = try await repo.sendMessage(sessionId: sessionID, body: String(repeating: "x", count: 2001)); XCTFail() }
        catch { XCTAssertTrue(error is UserContentPolicyError) }
        XCTAssertTrue(requests.isEmpty)
        XCTAssertTrue(records.isEmpty)
    }

    func testSendMissingSessionRetainsAuthErrorAndEmitsFailedSend() async throws {
        let repo = makeRepository { _ in XCTFail("No message write expected"); return (200, Data()) }
        do { _ = try await repo.sendMessage(sessionId: sessionID, body: "private-body"); XCTFail() }
        catch { XCTAssertTrue(error is AuthError) }
        XCTAssertTrue(requests.isEmpty)
        XCTAssertEqual(records.map(\.operation), [.send])
        XCTAssertEqual(records.map(\.failure), [.backend])
        try assertPrivate(records[0])
    }

    func testBackendFailuresPreserveOriginalErrorAndFreshRetryIDs() async throws {
        let repo = makeRepository { _ in
            (403, Data(#"{"code":"42501","message":"private-body private-token","details":"private-author","hint":"private-url"}"#.utf8))
        }
        for _ in 0..<2 {
            do { _ = try await repo.fetchMessageUpdates(sessionId: sessionID, ids: [messageID]); XCTFail() }
            catch let error as PostgrestError { XCTAssertEqual(error.code, "42501"); XCTAssertEqual(error.message, "private-body private-token") }
        }
        XCTAssertEqual(records.map(\.failure), [.backend, .backend])
        XCTAssertEqual(records.map(\.result), [.failed, .failed])
        XCTAssertEqual(Set(records.map(\.attemptID)).count, 2)
        for record in records { try assertPrivate(record) }
    }

    func testMalformedPagePreservesDecodingFailure() async throws {
        let repo = makeRepository { _ in (200, Data(#"[{"body":"private-body"}]"#.utf8)) }
        do { _ = try await repo.fetchMessages(sessionId: sessionID); XCTFail() }
        catch { XCTAssertTrue(error is DecodingError) }
        XCTAssertEqual(records.map(\.operation), [.fetchFirst])
        XCTAssertEqual(records.map(\.failure), [.decoding])
        try assertPrivate(records[0])
    }

    func testTransportAndCancellationAtActualSDKReadBoundary() async throws {
        for code in [URLError.notConnectedToInternet, .cancelled] {
            records.removeAll()
            let repo = makeRepository { _ in throw URLError(code, userInfo: [NSLocalizedDescriptionKey: "private-token"]) }
            do { _ = try await repo.fetchMessages(sessionId: sessionID, before: .init(timestamp: timestamp, id: messageID)); XCTFail() }
            catch let error as URLError { XCTAssertEqual(error.code, code) }
            XCTAssertEqual(records.map(\.operation), [.fetchOlder])
            XCTAssertEqual(records.map(\.failure), [code == .cancelled ? .cancelled : .transport])
            XCTAssertEqual(records.map(\.result), [code == .cancelled ? .cancelled : .failed])
            try assertPrivate(records[0])
        }
    }

    func testUnknownAndTaskCancellationRethrowOriginalError() async throws {
        final class PrivateError: Error {}
        let original = PrivateError()
        let diagnostics = ChatOperationDiagnostics { self.records.append($0) }
        do { try await diagnostics.record(.send) { throw original }; XCTFail() }
        catch { XCTAssertTrue((error as AnyObject) === original) }
        do { try await diagnostics.record(.fetchUpdates) { throw CancellationError() }; XCTFail() }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(records.map(\.failure), [.unknown, .cancelled])
        XCTAssertEqual(records.map(\.result), [.failed, .cancelled])
        for record in records { try assertPrivate(record) }
    }

    func testDefaultLoggerEmitsSyntheticSDKFailure() async throws {
        let repo = makeClient(capture: false) { _ in throw URLError(.notConnectedToInternet) }.0
        do { _ = try await repo.fetchMessages(sessionId: sessionID); XCTFail() }
        catch { XCTAssertTrue(error is URLError) }
    }

    private func assertPrivate(_ record: ChatOperationDiagnostics.Record) throws {
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(record.json.utf8)) as? [String: Any])
        XCTAssertEqual(Set(json.keys), Set(["event", "operation", "result", "failure", "attempt_id", "duration_ms", "version", "build", "configuration", "environment"]))
        XCTAssertEqual(json["event"] as? String, "chat_operation")
        XCTAssertEqual(json["environment"] as? String, "unit_test")
        XCTAssertNotNil(UUID(uuidString: record.attemptID))
        XCTAssertFalse([sessionID, userID, messageID].map(\.uuidString).contains(record.attemptID))
        XCTAssertGreaterThanOrEqual(record.durationMS, 0)
        for secret in ["private", sessionID.uuidString, messageID.uuidString, userID.uuidString, timestamp, "42501", "https:"] {
            XCTAssertFalse(record.json.contains(secret))
        }
    }

    private func makeRepository(_ responder: @escaping (URLRequest) throws -> (Int, Data)) -> ChatRepository {
        makeClient(responder).0
    }

    private func makeClient(capture: Bool = true, _ responder: @escaping (URLRequest) throws -> (Int, Data)) -> (ChatRepository, SupabaseClient) {
        ChatDiagnosticRequest.respond = { request in
            XCTAssertEqual(request.url?.host, "chat-diagnostics.invalid")
            self.requests.append(request)
            return try responder(request)
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ChatDiagnosticRequest.self]
        let client = SupabaseClient(supabaseURL: URL(string: "https://chat-diagnostics.invalid")!, supabaseKey: "synthetic-key",
            options: .init(auth: .init(storage: ChatDiagnosticStorage(), autoRefreshToken: false),
                           global: .init(session: URLSession(configuration: config), logger: nil)))
        return (ChatRepository(client: client, diagnostics: capture ? .init { self.records.append($0) } : .init()), client)
    }

    private func row(id: UUID? = nil) -> [String: Any] {
        ["id": (id ?? messageID).uuidString, "session_id": sessionID.uuidString,
         "user_id": userID.uuidString, "body": "private-body", "created_at": timestamp]
    }

    private func authSession() throws -> Data {
        try JSONSerialization.data(withJSONObject: ["access_token": "private-token", "refresh_token": "private-refresh",
            "token_type": "bearer", "expires_in": 3600, "expires_at": Date().timeIntervalSince1970 + 3600,
            "user": ["id": userID.uuidString, "aud": "authenticated", "role": "authenticated", "email": "private@ucf.edu",
                     "app_metadata": [:], "user_metadata": [:], "created_at": "2026-01-01T00:00:00Z", "updated_at": "2026-01-01T00:00:00Z", "is_anonymous": false]])
    }

    private func query(_ request: URLRequest, _ name: String) -> String? {
        URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == name }?.value
    }

    private func body(_ request: URLRequest) throws -> [String: Any] {
        var data = request.httpBody ?? Data()
        if let stream = request.httpBodyStream {
            stream.open(); defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 2048)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                data.append(contentsOf: buffer.prefix(count))
            }
        }
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}

private final class ChatDiagnosticStorage: AuthLocalStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Data] = [:]
    func store(key: String, value: Data) throws { lock.lock(); defer { lock.unlock() }; values[key] = value }
    func retrieve(key: String) throws -> Data? { lock.lock(); defer { lock.unlock() }; return values[key] }
    func remove(key: String) throws { lock.lock(); defer { lock.unlock() }; values.removeValue(forKey: key) }
}

private final class ChatDiagnosticRequest: URLProtocol {
    static var respond: ((URLRequest) throws -> (Int, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (status, data) = try XCTUnwrap(Self.respond)(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil,
                headerFields: ["Content-Type": "application/json", "X-Supabase-Api-Version": "2024-01-01"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}
