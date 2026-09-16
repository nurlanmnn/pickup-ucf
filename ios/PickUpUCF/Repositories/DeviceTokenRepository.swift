import Foundation
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

    init(client: SupabaseClient = SupabaseManager.shared) {
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
        registerRPC = { _ in }
        self.unregisterRPC = unregisterRPC
        self.deleteOwnedToken = deleteOwnedToken
    }

    func register(token: String) async throws {
        try await registerRPC(DeviceTokenParams(apnsToken: token))
    }

    func unregister(token: String) async throws {
        do {
            try await unregisterRPC(DeviceTokenParams(apnsToken: token))
        } catch let error as PostgrestError where error.code == "PGRST202" {
            // Pre-migration production still has owner-scoped RLS. The explicit
            // user-and-token filters add defense in depth without enabling writes.
            try await deleteOwnedToken(token)
        }
    }
}

protocol LiveActivityTokenRepositoryProtocol {
    func register(sessionId: UUID, token: String) async throws
}

final class LiveActivityTokenRepository: LiveActivityTokenRepositoryProtocol {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseManager.shared) {
        self.client = client
    }

    func register(sessionId: UUID, token: String) async throws {
        try await client.rpc(
            "register_live_activity_token",
            params: LiveActivityTokenRegistrationParams(
                sessionId: sessionId,
                apnsToken: token
            )
        ).execute()
    }
}
