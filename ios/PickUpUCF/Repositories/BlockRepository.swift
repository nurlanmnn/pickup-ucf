import Foundation
import Supabase

struct BlockUserParams: Encodable {
    let pBlockedId: UUID

    enum CodingKeys: String, CodingKey {
        case pBlockedId = "p_blocked_id"
    }
}

protocol BlockRepositoryProtocol {
    func block(userId: UUID) async throws
    func fetchBlockedUserIds() async throws -> Set<UUID>
}

final class BlockRepository: BlockRepositoryProtocol {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseManager.shared) {
        self.client = client
    }

    func block(userId: UUID) async throws {
        try await client.rpc("block_user", params: BlockUserParams(pBlockedId: userId)).execute()
    }

    func fetchBlockedUserIds() async throws -> Set<UUID> {
        struct Row: Decodable {
            let blockedId: UUID

            enum CodingKeys: String, CodingKey {
                case blockedId = "blocked_id"
            }
        }

        let rows: [Row] = try await client
            .from("user_blocks")
            .select("blocked_id")
            .execute()
            .value

        return Set(rows.map(\.blockedId))
    }
}
