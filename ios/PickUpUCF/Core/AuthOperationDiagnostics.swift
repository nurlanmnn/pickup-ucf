import Foundation
import OSLog
import Supabase

/// An allowlisted local log schema: never serialize Error, SDK payloads or entity IDs.
struct AuthOperationDiagnostics {
    enum Operation: String, Encodable {
        case signUp = "sign_up", signIn = "sign_in", signOut = "sign_out"
        case resendVerification = "resend_verification", verifyOTP = "verify_otp"
        case passwordReset = "password_reset", passwordUpdate = "password_update"
        case changePasswordReauthenticate = "change_password_reauthenticate"
        case changePasswordUpdate = "change_password_update", callbackExchange = "callback_exchange"
        case restore
        case deleteOwnAccountRPC = "delete_own_account_rpc"
    }
    enum Result: String, Encodable {
        case succeeded, failed, cancelled
        // Restoration decisions, never inferred from a successful SDK substep.
        case sessionMissing = "session_missing", unavailable, verified
        case rejectedCached = "rejected_cached", rejectedRemote = "rejected_remote"
        case invalidated, superseded, cachedFallback = "cached_fallback"
    }
    enum Failure: String, Encodable { case none, cancelled, transport, backend, decoding, localPolicy = "local_policy", unknown }

    /// Generated per repository invocation; change-password's reauthentication/write share it. Retries get a new ID.
    struct Attempt { fileprivate let id = UUID() }

    struct Record: Encodable {
        let event = "auth_operation"
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

    private static let logger = Logger(subsystem: "edu.ucf.pickup", category: "auth_operation")
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
            let failure = Self.failure(for: error)
            emit(failure == .cancelled ? .cancelled : .failed, failure)
            throw error
        }
    }

    func finishRestoration(result: Result, failure: Failure, attempt: Attempt, startedAt: TimeInterval) {
        sink(Record(operation: .restore, result: result, failure: failure,
                    attemptID: attempt.id.uuidString,
                    durationMS: Int(max(0, ProcessInfo.processInfo.systemUptime - startedAt) * 1000)))
    }

    static func failure(for error: Error) -> Failure {
        if error is CancellationError || (error as? URLError)?.code == .cancelled { return .cancelled }
        if error is URLError { return .transport }
        if error is AuthError || error is PostgrestError { return .backend }
        if error is AuthRepositoryError { return .localPolicy }
        if error is DecodingError { return .decoding }
        return .unknown
    }

    private static func write(_ record: Record) {
        // Public only because every field above is closed/allowlisted; no raw error or input.
        if record.result == .failed { logger.error("\(record.json, privacy: .public)") }
        else { logger.info("\(record.json, privacy: .public)") }
    }
}
