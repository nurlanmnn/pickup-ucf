import Foundation
import OSLog

enum DeepLinkRouter {
    static let webHost = "pickup-ucf-privacy.vercel.app"
    static let passwordResetURL = URL(string: "https://\(webHost)/auth/reset-password")!

    enum Destination {
        case confirmEmail
        case resetPassword
        case session(UUID)
    }

    static func destination(from url: URL) -> Destination? {
        guard url.user == nil, url.password == nil, url.port == nil,
              url.fragment == nil else { return nil }
        let isWeb = url.scheme == "https" && url.host == webHost
        let isLegacySession = url.scheme == "pickupucf" && url.host == "session"
        guard isWeb || isLegacySession else { return nil }

        if isWeb && ["/auth/confirm", "/auth/reset-password"].contains(url.path) {
            guard let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
                  items.count == 1, items[0].name == "code",
                  let code = items[0].value, !code.isEmpty, code.utf8.count <= 2048,
                  code.unicodeScalars.allSatisfy({ !CharacterSet.whitespacesAndNewlines.contains($0) && !CharacterSet.controlCharacters.contains($0) }) else { return nil }
            return url.path == "/auth/reset-password" ? .resetPassword : .confirmEmail
        }

        guard url.query == nil else { return nil }
        let prefix = isLegacySession ? "/" : "/session/"
        guard url.path.hasPrefix(prefix) else { return nil }
        let value = String(url.path.dropFirst(prefix.count))
        guard let id = UUID(uuidString: value), value.count == 36 else { return nil }
        return .session(id)
    }
}

/// Local state handoff only; never proves a destination loaded or a notification arrived.
struct SessionLinkDiagnostics {
    enum Operation: String, Encodable { case queueSession = "queue_session", resumePending = "resume_pending" }
    enum Result: String, Encodable {
        case assigned, deferred, noPending = "no_pending", waitingForAuth = "waiting_for_auth", resumed
    }
    enum Decision { case queueAssigned, queueDeferred, resumeNoPending, resumeWaitingForAuth, resumeAssigned }

    struct Attempt {
        fileprivate let id = UUID()
        fileprivate let start = ProcessInfo.processInfo.systemUptime
    }

    struct Record: Encodable {
        let event = "session_link_handoff"
        let operation: Operation
        let result: Result
        let failure = "none"
        let attemptID: String
        let durationMS: Int
        let version = Self.bundleNumber("CFBundleShortVersionString")
        let build = Self.bundleNumber("CFBundleVersion")
        #if DEBUG
        let configuration = "debug"
        #else
        let configuration = "release"
        #endif
        let environment = SupabaseManager.isUnitTestMode ? "unit_test" : "configured"

        enum CodingKeys: String, CodingKey {
            case event, operation, result, failure, version, build, configuration, environment
            case attemptID = "attempt_id", durationMS = "duration_ms"
        }

        var json: String {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            guard let data = try? encoder.encode(self), let json = String(data: data, encoding: .utf8) else { return "{}" }
            return json
        }

        private static func bundleNumber(_ key: String) -> String {
            guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
                  !value.isEmpty, value.utf8.count <= 32,
                  value.utf8.allSatisfy({ (48...57).contains($0) || $0 == 46 }) else { return "unknown" }
            return value
        }
    }

    private static let logger = Logger(subsystem: "edu.ucf.pickup", category: "session_link_handoff")
    private let sink: (Record) -> Void
    init(sink: @escaping (Record) -> Void = Self.write) { self.sink = sink }

    func finish(_ decision: Decision, attempt: Attempt) {
        let operation: Operation
        let result: Result
        switch decision {
        case .queueAssigned: operation = .queueSession; result = .assigned
        case .queueDeferred: operation = .queueSession; result = .deferred
        case .resumeNoPending: operation = .resumePending; result = .noPending
        case .resumeWaitingForAuth: operation = .resumePending; result = .waitingForAuth
        case .resumeAssigned: operation = .resumePending; result = .resumed
        }
        sink(Record(operation: operation, result: result, attemptID: attempt.id.uuidString,
                    durationMS: Int(max(0, ProcessInfo.processInfo.systemUptime - attempt.start) * 1000)))
    }

    private static func write(_ record: Record) {
        // Every field is closed/allowlisted; session/user IDs, URLs and intent never enter the record.
        logger.info("\(record.json, privacy: .public)")
    }
}
