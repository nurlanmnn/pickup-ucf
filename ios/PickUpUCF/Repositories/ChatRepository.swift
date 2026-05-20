import Foundation
import Supabase

protocol ChatRepositoryProtocol {
    func fetchMessages(sessionId: UUID, limit: Int) async throws -> [SessionMessage]
    func sendMessage(sessionId: UUID, body: String) async throws -> SessionMessage
}

final class ChatRepository: ChatRepositoryProtocol {
    private let client: SupabaseClient
    private let messageSelect = """
        *, \
        author:profiles!messages_user_id_fkey(id, display_name, username)
        """

    init(client: SupabaseClient = SupabaseManager.shared) {
        self.client = client
    }

    func fetchMessages(sessionId: UUID, limit: Int = 50) async throws -> [SessionMessage] {
        try await client
            .from("messages")
            .select(messageSelect)
            .eq("session_id", value: sessionId.uuidString)
            .order("created_at", ascending: true)
            .limit(limit)
            .execute()
            .value
    }

    func sendMessage(sessionId: UUID, body: String) async throws -> SessionMessage {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ChatRepositoryError.emptyMessage
        }

        let userId = try await client.auth.session.user.id
        let payload = MessageInsert(sessionId: sessionId, userId: userId, body: trimmed)

        return try await client
            .from("messages")
            .insert(payload)
            .select(messageSelect)
            .single()
            .execute()
            .value
    }
}

enum ChatRepositoryError: LocalizedError {
    case emptyMessage
    case notParticipant

    var errorDescription: String? {
        switch self {
        case .emptyMessage:
            return "Type a message before sending."
        case .notParticipant:
            return "Join this session to chat with other players."
        }
    }
}
