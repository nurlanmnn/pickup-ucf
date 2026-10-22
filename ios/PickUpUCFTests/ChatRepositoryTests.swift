import XCTest
import Supabase
@testable import PickUpUCF

final class ChatRepositoryTests: XCTestCase {
    func testAuthorResolutionIsOneSessionScopedMessageBatchWithMinimalProfiles() async throws {
        var requests = 0
        let ids = [UUID(), UUID()]
        ChatRequestStub.respond = { request in
            requests += 1
            XCTAssertEqual(request.url?.path, "/rest/v1/messages")
            let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!
            let value = { (name: String) in items.first { $0.name == name }?.value }
            XCTAssertEqual(value("session_id"), "eq.\(self.sessionId.uuidString)")
            XCTAssertEqual(value("limit"), "50")
            for id in ids { XCTAssertTrue(value("id")?.contains(id.uuidString) == true) }
            XCTAssertTrue(value("select")?.contains("id,display_name,username") == true)
            XCTAssertFalse(value("select")?.contains("email") == true)
            return Data("[]".utf8)
        }
        let repository = makeRepository()
        _ = try await repository.fetchMessageUpdates(sessionId: sessionId, ids: ids)
        _ = try await repository.fetchMessageUpdates(sessionId: sessionId, ids: [])
        XCTAssertEqual(requests, 1)
    }
    func testOpeningChatReturnsNewestFiftyInChronologicalOrder() async throws {
        let repository = makeRepository()
        ChatRequestStub.respond = { request in
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!
            let descending = query.first { $0.name == "order" }!.value!.contains("created_at.desc")
            let limit = Int(query.first { $0.name == "limit" }!.value!)!
            let indices = descending ? Array((1...51).reversed()) : Array(1...51)
            return try self.response(indices: Array(indices.prefix(limit)))
        }

        let page = try await repository.fetchMessages(sessionId: sessionId)

        XCTAssertEqual(page.messages.map(\.body), (2...51).map { "Message \($0)" })
        XCTAssertEqual(page.nextCursor?.timestamp, timestamp(index: 2))
    }

    func testEmptySingleAndExactPageDoNotOfferMoreHistory() async throws {
        for count in [0, 1, 50] {
            ChatRequestStub.respond = { _ in
                try self.response(indices: Array((0..<count).reversed()).map { $0 + 1 })
            }
            let page = try await makeRepository().fetchMessages(sessionId: sessionId)
            XCTAssertEqual(page.messages.count, count)
            XCTAssertNil(page.nextCursor)
        }
    }

    func testPagesThroughHundredsOfTimestampTiesWithoutGapsOrNewInsertDrift() async throws {
        let repository = makeRepository()
        var requestCount = 0
        ChatRequestStub.respond = { request in
            requestCount += 1
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!
            let value = { (name: String) in query.first { $0.name == name }?.value }
            XCTAssertEqual(value("order"), "created_at.desc.nullslast,id.desc.nullslast")
            XCTAssertEqual(value("session_id"), "eq.\(self.sessionId.uuidString)")
            let limit = Int(value("limit")!)!
            var upperBound = requestCount == 1 ? 301 : 302 // New message after page one.
            if let filter = value("or"), let range = filter.range(of: "id.lt.") {
                let id = String(filter[range.upperBound...].prefix(36))
                upperBound = Int(id.suffix(12))! - 1
                // All rows intentionally share a microsecond-precision timestamp.
                XCTAssertTrue(filter.contains("created_at.lt.2026-10-14T12:00:00.123456+00:00"))
                XCTAssertTrue(filter.contains("created_at.eq.2026-10-14T12:00:00.123456+00:00"))
            }
            let indices = upperBound > 0 ? Array((1...upperBound).reversed().prefix(limit)) : []
            return try self.response(indices: indices, sameTimestamp: true)
        }
        var cursor: ChatMessageCursor?
        var messages: [SessionMessage] = []
        repeat {
            let page = try await repository.fetchMessages(sessionId: sessionId, before: cursor)
            messages = page.messages + messages
            cursor = page.nextCursor
        } while cursor != nil && requestCount < 10

        XCTAssertEqual(messages.map(\.body), (1...301).map { "Message \($0)" })
        XCTAssertEqual(Set(messages.map(\.id)).count, 301)
        XCTAssertEqual(requestCount, 7)
    }

    private let sessionId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    private func makeRepository() -> ChatRepository {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ChatRequestStub.self]
        let client = SupabaseClient(
            supabaseURL: URL(string: "https://chat-tests.invalid")!,
            supabaseKey: "synthetic-test-key",
            options: .init(
                auth: .init(storageKey: UUID().uuidString, autoRefreshToken: false),
                global: .init(session: URLSession(configuration: configuration))
            )
        )
        return ChatRepository(client: client)
    }

    private func timestamp(index: Int) -> String {
        String(format: "2026-10-14T12:%02d:%02d.123456+00:00", index / 60, index % 60)
    }

    private func response(indices: [Int], sameTimestamp: Bool = false) throws -> Data {
        try JSONSerialization.data(withJSONObject: indices.map { index in
            [
                "id": String(format: "00000000-0000-0000-0000-%012d", index),
                "session_id": sessionId.uuidString,
                "user_id": "00000000-0000-0000-0000-000000000002",
                "body": "Message \(index)",
                "created_at": timestamp(index: sameTimestamp ? 0 : index),
            ]
        })
    }
}

private final class ChatRequestStub: URLProtocol {
    static var respond: ((URLRequest) throws -> Data)?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            let data = try Self.respond!(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil,
                                           headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
