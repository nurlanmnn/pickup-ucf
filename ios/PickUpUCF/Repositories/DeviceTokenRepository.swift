import Foundation
import OSLog
import Supabase

struct DeviceTokenParams: Encodable {
    let apnsToken: String

    enum CodingKeys: String, CodingKey {
        case apnsToken = "p_apns_token"
    }
}

struct LiveActivityTokenRegistrationParams: Encodable {
    let sessionId: UUID
    let apnsToken: String

    enum CodingKeys: String, CodingKey {
        case sessionId = "p_session_id"
        case apnsToken = "p_apns_token"
    }
}

protocol DeviceTokenRepositoryProtocol {
    func register(token: String) async throws
    func unregister(token: String) async throws
}

private enum DeviceTokenRepositoryError: Error {
    case missingAuthenticatedUser
}

final class DeviceTokenRepository: DeviceTokenRepositoryProtocol {
    private let registerRPC: (DeviceTokenParams) async throws -> Void
    private let unregisterRPC: (DeviceTokenParams) async throws -> Void
    private let deleteOwnedToken: (String) async throws -> Void

    private let diagnostics: DeviceTokenDiagnostics

    init(client: SupabaseClient = SupabaseManager.shared, diagnostics: DeviceTokenDiagnostics = .init()) {
        self.diagnostics = diagnostics
        registerRPC = { params in
            try await client.rpc("register_device_token", params: params).execute()
        }
        unregisterRPC = { params in
            try await client.rpc("unregister_device_token", params: params).execute()
        }
        deleteOwnedToken = { token in
            guard let userId = client.auth.currentUser?.id else {
                throw DeviceTokenRepositoryError.missingAuthenticatedUser
            }
            try await client
                .from("device_tokens")
                .delete()
                .eq("user_id", value: userId.uuidString)
                .eq("apns_token", value: token)
                .execute()
        }
    }

    init(
        unregisterRPC: @escaping (DeviceTokenParams) async throws -> Void,
        deleteOwnedToken: @escaping (String) async throws -> Void
    ) {
        diagnostics = .init()
        registerRPC = { _ in }
        self.unregisterRPC = unregisterRPC
        self.deleteOwnedToken = deleteOwnedToken
    }

    func register(token: String) async throws {
        try await diagnostics.record(.registerRPC) {
            try await registerRPC(DeviceTokenParams(apnsToken: token))
        }
    }

    func unregister(token: String) async throws {
        let attempt = DeviceTokenDiagnostics.Attempt()
        do {
            try await diagnostics.record(.unregisterRPC, attempt: attempt) {
                try await unregisterRPC(DeviceTokenParams(apnsToken: token))
            }
        } catch let error as PostgrestError where error.code == "PGRST202" {
            // Pre-migration production still has owner-scoped RLS. The explicit
            // user-and-token filters add defense in depth without enabling writes.
            try await diagnostics.record(.deleteOwnedToken, attempt: attempt) {
                try await deleteOwnedToken(token)
            }
        }
    }
}

protocol LiveActivityTokenRepositoryProtocol {
    func register(sessionId: UUID, token: String) async throws
}

final class LiveActivityTokenRepository: LiveActivityTokenRepositoryProtocol {
    private let client: SupabaseClient
    private let diagnostics: DeviceTokenDiagnostics

    init(client: SupabaseClient = SupabaseManager.shared, diagnostics: DeviceTokenDiagnostics = .init()) {
        self.diagnostics = diagnostics
        self.client = client
    }

    func register(sessionId: UUID, token: String) async throws {
        try await diagnostics.record(.registerLiveActivityRPC) {
            try await client.rpc(
                "register_live_activity_token",
                params: LiveActivityTokenRegistrationParams(
                    sessionId: sessionId,
                    apnsToken: token
                )
            ).execute()
        }
    }
}

/// An allowlisted local log schema: never serialize Error, SDK payloads or entity IDs.
// Success describes only this backend stage returning, never delivery or affected rows.
struct DeviceTokenDiagnostics {
    enum Operation: String, Encodable { case registerRPC = "register_rpc", unregisterRPC = "unregister_rpc", deleteOwnedToken = "delete_owned_token", registerLiveActivityRPC = "register_live_activity_rpc", accountTransitionCleanup = "account_transition_cleanup" }
    enum Result: String, Encodable { case succeeded, failed, cancelled
        case noStoredToken = "no_stored_token", returnedFirstAttempt = "returned_first_attempt", returnedAfterRetry = "returned_after_retry", recoveryRequired = "recovery_required"
    }
    enum Failure: String, Encodable { case none, cancelled, transport, backend, decoding, localPolicy = "local_policy", unknown }

    /// Fresh per invocation; unregister RPC and optional compatibility delete share it.
    struct Attempt {
        fileprivate let id = UUID()
        fileprivate let start = ProcessInfo.processInfo.systemUptime
    }

    enum CleanupOutcome {
        case noStoredToken, returnedFirstAttempt, returnedAfterRetry
        case recoveryRequired(Error)
    }

    struct Record: Encodable {
        let event = "device_token_operation"
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

    private static let logger = Logger(subsystem: "edu.ucf.pickup", category: "device_token_operation")
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
            let failure = Self.classify(error)
            emit(failure == .cancelled ? .cancelled : .failed, failure)
            throw error
        }
    }

    /// Service completion, including local cleanup and queued-registration wait.
    func finishCleanup(_ outcome: CleanupOutcome, attempt: Attempt) {
        let result: Result
        let failure: Failure
        switch outcome {
        case .noStoredToken: result = .noStoredToken; failure = .none
        case .returnedFirstAttempt: result = .returnedFirstAttempt; failure = .none
        case .returnedAfterRetry: result = .returnedAfterRetry; failure = .none
        case .recoveryRequired(let error): result = .recoveryRequired; failure = Self.classify(error)
        }
        sink(Record(operation: .accountTransitionCleanup, result: result, failure: failure,
                    attemptID: attempt.id.uuidString,
                    durationMS: Int(max(0, ProcessInfo.processInfo.systemUptime - attempt.start) * 1000)))
    }

    private static func classify(_ error: Error) -> Failure {
        if error is CancellationError || (error as? URLError)?.code == .cancelled { return .cancelled }
        if error is URLError { return .transport }
        if error is PostgrestError || error is AuthError { return .backend }
        if error is DeviceTokenRepositoryError { return .localPolicy }
        if error is DecodingError { return .decoding }
        return .unknown
    }

    private static func write(_ record: Record) {
        // Public only because every field above is closed/allowlisted; no raw error or input.
        if record.result == .failed || record.result == .recoveryRequired { logger.error("\(record.json, privacy: .public)") }
        else { logger.info("\(record.json, privacy: .public)") }
    }
}
