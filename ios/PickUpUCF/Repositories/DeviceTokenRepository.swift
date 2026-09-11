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

final class DeviceTokenRepository: DeviceTokenRepositoryProtocol {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseManager.shared) {
        self.client = client
    }

    func register(token: String) async throws {
        try await client.rpc(
            "register_device_token",
            params: DeviceTokenParams(apnsToken: token)
        ).execute()
    }

    func unregister(token: String) async throws {
        try await client.rpc(
            "unregister_device_token",
            params: DeviceTokenParams(apnsToken: token)
        ).execute()
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
