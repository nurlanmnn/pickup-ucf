import Foundation
import Supabase

protocol BlockRepositoryProtocol {
    func block(userId: UUID) async throws
    func unblock(userId: UUID) async throws
    func fetchBlockedUserIds() async throws -> Set<UUID>
    func fetchBlockedUsers() async throws -> [BlockedUser]
}

final class BlockRepository: BlockRepositoryProtocol {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseManager.shared) {
        self.client = client
    }

    func block(userId: UUID) async throws {
        try await client.rpc("block_user", params: BlockUserParams(pBlockedId: userId)).execute()
    }

    func unblock(userId: UUID) async throws {
        try await client.rpc("unblock_user", params: UnblockUserParams(pBlockedId: userId)).execute()
    }

    func fetchBlockedUserIds() async throws -> Set<UUID> {
        Set(try await fetchBlockedUsers().map(\.id))
    }

    func fetchBlockedUsers() async throws -> [BlockedUser] {
        let rows: [BlockedUserRow] = try await client
            .from("user_blocks")
            .select("blocked_id, profiles!user_blocks_blocked_id_fkey(id, display_name, username)")
            .execute()
            .value

        return rows.map(\.blockedUser)
    }
}
