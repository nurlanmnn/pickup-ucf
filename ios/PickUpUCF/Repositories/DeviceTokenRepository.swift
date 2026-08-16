import Foundation
import Supabase

struct DeviceTokenUpsertRow: Encodable {
    let userId: UUID
    let apnsToken: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case apnsToken = "apns_token"
    }
}

protocol DeviceTokenRepositoryProtocol {
    func upsert(token: String) async throws
    func delete(token: String) async throws
}

final class DeviceTokenRepository: DeviceTokenRepositoryProtocol {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseManager.shared) {
        self.client = client
    }

    func upsert(token: String) async throws {
        let userId = try await client.auth.session.user.id
        try await client.from("device_tokens")
            .upsert(DeviceTokenUpsertRow(userId: userId, apnsToken: token))
            .execute()
    }

    func delete(token: String) async throws {
        try await client.from("device_tokens")
            .delete()
            .eq("apns_token", value: token)
            .execute()
    }
}
