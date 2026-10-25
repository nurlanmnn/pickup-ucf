import Foundation
import OSLog
import Supabase

/// An allowlisted local log schema: never serialize Error, SDK payloads or entity IDs.
struct ChatOperationDiagnostics {
    enum Operation: String, Encodable { case fetchFirst = "fetch_first", fetchOlder = "fetch_older", send, fetchUpdates = "fetch_updates" }
    enum Result: String, Encodable { case succeeded, failed, cancelled }
    enum Failure: String, Encodable { case none, cancelled, transport, backend, decoding, unknown }

    /// Generated per instrumented repository invocation, never from entity IDs. Retries get a new ID.
    struct Attempt { fileprivate let id = UUID() }

    struct Record: Encodable {
        let event = "chat_operation"
        let operation: Operation
        let result: Result
        let failure: Failure
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
            // This closed schema contains only JSON primitives, so encoding cannot fail.
            guard let data = try? encoder.encode(self), let json = String(data: data, encoding: .utf8) else {
                return "{}"
            }
            return json
        }

        private static func bundleNumber(_ key: String) -> String {
            guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
                  !value.isEmpty, value.utf8.count <= 32,
                  value.utf8.allSatisfy({ (48...57).contains($0) || $0 == 46 }) else { return "unknown" }
            return value
        }
    }

    private static let logger = Logger(subsystem: "edu.ucf.pickup", category: "chat_operation")
    private let sink: (Record) -> Void

    init(sink: @escaping (Record) -> Void = Self.write) { self.sink = sink }

    func record<T>(
        _ operation: Operation, attempt: Attempt = Attempt(), action: () async throws -> T
    ) async rethrows -> T {
        let start = ProcessInfo.processInfo.systemUptime
        func emit(_ result: Result, _ failure: Failure) {
            sink(Record(operation: operation, result: result, failure: failure,
                        attemptID: attempt.id.uuidString,
                        durationMS: Int(max(0, ProcessInfo.processInfo.systemUptime - start) * 1000)))
        }
        do {
            let value = try await action()
            emit(.succeeded, .none)
            return value
        } catch {
            let failure: Failure
            if error is CancellationError || (error as? URLError)?.code == .cancelled { failure = .cancelled }
            else if error is URLError { failure = .transport }
            else if error is PostgrestError || error is AuthError { failure = .backend }
            else if error is DecodingError { failure = .decoding }
            else { failure = .unknown }
            emit(failure == .cancelled ? .cancelled : .failed, failure)
            throw error
        }
    }

    private static func write(_ record: Record) {
        // Public only because every field above is closed/allowlisted; no raw error or input.
        if record.result == .failed { logger.error("\(record.json, privacy: .public)") }
        else { logger.info("\(record.json, privacy: .public)") }
    }
}
