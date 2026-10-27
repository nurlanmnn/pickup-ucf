import Foundation
import Supabase

/// Reject all HTTP from the shared isolated test client; explicit repository fixtures
/// supply their own URLSession and synthetic host.
private final class IsolatedBackendBlocker: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
    }
    override func stopLoading() {}
}

/// Discards isolated auth state rather than touching Keychain (including SDK startup).
private struct IsolatedAuthStorage: AuthLocalStorage {
    func store(key: String, value: Data) throws {}
    func retrieve(key: String) throws -> Data? { nil }
    func remove(key: String) throws {}
}

enum SupabaseManager {
    static let isUnitTestMode = AppTestMode.current == .unit

    static let shared = makeClient(testMode: AppTestMode.current)

    static func makeClient(testMode: AppTestMode) -> SupabaseClient {
        #if DEBUG && targetEnvironment(simulator)
        if testMode == .uiSmokeAuthenticated { return AuthenticatedUISmokeFixture.makeClient() }
        #endif
        let session: URLSession
        if testMode.isIsolated {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [IsolatedBackendBlocker.self]
            session = URLSession(configuration: configuration)
        } else {
            session = .shared
        }
        return SupabaseClient(
            supabaseURL: testMode.isIsolated ? URL(string: "https://unit-tests.invalid")! : AppConfig.supabaseURL,
            supabaseKey: testMode.isIsolated ? "synthetic-unit-test-key" : AppConfig.supabaseAnonKey,
            options: SupabaseClientOptions(
                auth: testMode.isIsolated
                    ? SupabaseClientOptions.AuthOptions(storage: IsolatedAuthStorage(), autoRefreshToken: false,
                                                        emitLocalSessionAsInitialSession: true)
                    : SupabaseClientOptions.AuthOptions(emitLocalSessionAsInitialSession: true),
                // SDK HTTP descriptions include user content. Keep raw payload logging disabled.
                global: SupabaseClientOptions.GlobalOptions(session: session, logger: nil)
            )
        )
    }
}

#if DEBUG && targetEnvironment(simulator)
/// A read-only synthetic backend for the bounded tab/detail-navigation UI lane.
/// Never used by Release/device builds or the ordinary unit-test shared client.
enum AuthenticatedUISmokeFixture {
    static let userID = UUID(uuidString: "00000000-0000-0000-0000-000000000011")!
    static let gameID = UUID(uuidString: "00000000-0000-0000-0000-000000000021")!
    static let pastGameID = UUID(uuidString: "00000000-0000-0000-0000-000000000022")!
    static let origin = URL(string: "https://ui-smoke.invalid")!
    static let storageKey = "pickup-ui-smoke-session"
    static let accessToken = "synthetic-ui-smoke-access-token"
    static let appSession = AppSession(userId: userID, email: "ui-smoke@ucf.edu", isEmailConfirmed: true)
    private static let launchDate = Date()

    static func makeClient() -> SupabaseClient {
        let now = Date()
        let user = User(id: userID, appMetadata: [:], userMetadata: [:], aud: "authenticated",
                        email: appSession.email, createdAt: now, emailConfirmedAt: now, updatedAt: now)
        let authSession = Session(accessToken: accessToken, tokenType: "bearer", expiresIn: 86_400,
                                  expiresAt: now.addingTimeInterval(86_400).timeIntervalSince1970,
                                  refreshToken: "synthetic-ui-smoke-refresh-token", user: user)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AuthenticatedUISmokeTransport.self]
        return SupabaseClient(supabaseURL: origin, supabaseKey: "synthetic-ui-smoke-key", options: .init(
            auth: .init(storage: UISmokeAuthStorage(session: authSession), storageKey: storageKey,
                        autoRefreshToken: false, emitLocalSessionAsInitialSession: true),
            global: .init(session: URLSession(configuration: configuration), logger: nil)))
    }

    /// Unrecognized origins, paths, methods and identities fail closed in URLProtocol.
    static func response(for request: URLRequest) throws -> Data {
        guard let url = request.url, url.scheme == origin.scheme, url.host == origin.host,
              url.port == nil, url.user == nil, url.password == nil,
              request.value(forHTTPHeaderField: "Authorization") == "Bearer \(accessToken)"
        else { throw URLError(.unsupportedURL) }
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ key: String) -> String? { query.first { $0.name == key }?.value }
        func gameIDs(_ key: String) throws -> [UUID]? {
            let items = query.filter { $0.name == key }
            guard !items.isEmpty else { return nil }
            guard items.count == 1, let raw = items[0].value else { throw URLError(.unsupportedURL) }
            let values: [String]
            if raw.hasPrefix("eq.") {
                values = [String(raw.dropFirst(3))]
            } else if raw.hasPrefix("in.("), raw.hasSuffix(")") {
                values = String(raw.dropFirst(4).dropLast()).components(separatedBy: ",")
            } else { throw URLError(.unsupportedURL) }
            let ids = values.compactMap(UUID.init(uuidString:))
            guard ids.count == values.count, !ids.isEmpty, Set(ids).count == ids.count,
                  ids.allSatisfy({ $0 == gameID || $0 == pastGameID })
            else { throw URLError(.unsupportedURL) }
            return ids
        }
        let ownUser = "eq.\(userID.uuidString)"
        let json: Any
        switch (request.httpMethod, url.path) {
        case ("GET", "/rest/v1/profiles") where value("id")?.lowercased() == ownUser.lowercased():
            json = ["id": userID.uuidString, "display_name": "UI Smoke Student", "username": "ui_smoke",
                    "games_played": 7, "show_up_streak": 3, "preferred_sports": ["basketball"],
                    "onboarding_completed_at": launchDate.ISO8601Format()]
        case ("GET", "/rest/v1/venues"):
            json = []
        case ("POST", "/rest/v1/rpc/list_blocked_users"):
            json = []
        case ("POST", "/rest/v1/rpc/get_session_roster"):
            let data = try requestBody(request)
            // Only the SDK's one literal key/UUID member is supported. Validate
            // before JSON decoding, which would collapse duplicate keys.
            let singleMember = #"\A[ \t\r\n]*\{[ \t\r\n]*"p_session_id"[ \t\r\n]*:[ \t\r\n]*"[0-9A-Fa-f-]{36}"[ \t\r\n]*\}[ \t\r\n]*\z"#
            guard query.isEmpty,
                  let rawBody = String(data: data, encoding: .utf8),
                  rawBody.range(of: singleMember, options: .regularExpression) != nil,
                  let body = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  Set(body.keys) == ["p_session_id"], let rawID = body["p_session_id"] as? String,
                  let id = UUID(uuidString: rawID), id == gameID || id == pastGameID
            else { throw URLError(.unsupportedURL) }
            json = ["joined": [
                ["user_id": userID.uuidString, "display_name": "UI Smoke Student", "role": "host"],
                ["user_id": "00000000-0000-0000-0000-000000000012", "display_name": "UI Smoke Teammate One", "role": "player"],
                ["user_id": "00000000-0000-0000-0000-000000000013", "display_name": "UI Smoke Teammate Two", "role": "player"]
            ], "waitlist_count": 0, "viewer_waitlist_position": NSNull()]
        case ("GET", "/rest/v1/session_participants") where value("user_id")?.lowercased() == ownUser.lowercased():
            guard query.filter({ $0.name == "user_id" }).count == 1 else { throw URLError(.unsupportedURL) }
            let ids = try gameIDs("session_id") ?? [gameID]
            json = ids.map { ["session_id": $0.uuidString, "status": "joined"] }
        case ("GET", "/rest/v1/sessions"):
            if let ids = try gameIDs("id") {
                if value("id")?.hasPrefix("eq.") == true {
                    guard query.allSatisfy({ $0.name == "select" || $0.name == "id" }),
                          query.filter({ $0.name == "select" }).count <= 1
                    else { throw URLError(.unsupportedURL) }
                    json = game(past: ids[0] == pastGameID)
                } else {
                    json = ids.map { game(past: $0 == pastGameID) }
                }
            } else if value("ends_at")?.hasPrefix("lte.") == true {
                json = [game(past: true)]
            } else if value("starts_at") != nil {
                json = [game(past: false)]
            } else { throw URLError(.unsupportedURL) }
        default: throw URLError(.unsupportedURL)
        }
        return try JSONSerialization.data(withJSONObject: json)
    }

    private static func requestBody(_ request: URLRequest) throws -> Data {
        if let body = request.httpBody {
            guard body.count <= 512 else { throw URLError(.unsupportedURL) }
            return body
        }
        guard let stream = request.httpBodyStream else { throw URLError(.unsupportedURL) }
        stream.open()
        defer { stream.close() }
        var body = Data()
        var buffer = [UInt8](repeating: 0, count: 128)
        while true {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count >= 0 else { throw URLError(.unsupportedURL) }
            if count == 0 { return body }
            body.append(contentsOf: buffer.prefix(count))
            guard body.count <= 512 else { throw URLError(.unsupportedURL) }
        }
    }

    private static func game(past: Bool) -> [String: Any] {
        let start = launchDate.addingTimeInterval(past ? -86_400 : 3_600)
        return ["id": (past ? pastGameID : gameID).uuidString, "host_id": userID.uuidString,
                "sport": "basketball", "custom_location": past ? "UI Smoke Past Court" : "UI Smoke Court",
                "starts_at": start.ISO8601Format(), "ends_at": start.addingTimeInterval(3_600).ISO8601Format(),
                "capacity": 8, "player_count": 3, "skill_level": "any",
                "status": past ? "completed" : "open", "notes": "UI Smoke game notes",
                "host": ["id": userID.uuidString, "display_name": "UI Smoke Student"]]
    }
}

/// The SDK can migrate/update/delete its session, but only within this client's memory.
private final class UISmokeAuthStorage: AuthLocalStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Data]
    init(session: Session) {
        // Encoding this SDK value cannot contain unsupported JSON values.
        values = [AuthenticatedUISmokeFixture.storageKey: try! JSONEncoder().encode(session)]
    }
    func store(key: String, value: Data) throws {
        lock.lock(); defer { lock.unlock() }
        values[key] = value
    }
    func retrieve(key: String) throws -> Data? {
        lock.lock(); defer { lock.unlock() }
        return values[key]
    }
    func remove(key: String) throws {
        lock.lock(); defer { lock.unlock() }
        values.removeValue(forKey: key)
    }
}

private final class AuthenticatedUISmokeTransport: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let data = try AuthenticatedUISmokeFixture.response(for: request)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil,
                                           headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}
#endif
