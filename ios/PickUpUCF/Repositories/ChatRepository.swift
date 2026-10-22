import Foundation
import Supabase

protocol ChatRepositoryProtocol {
    func fetchMessages(sessionId: UUID, before: ChatMessageCursor?, limit: Int) async throws -> ChatMessagePage
    func sendMessage(sessionId: UUID, body: String) async throws -> SessionMessage
    func fetchMessageUpdates(sessionId: UUID, ids: [UUID]) async throws -> [SessionMessage]
}

struct ChatMessageCursor: Equatable {
    let timestamp: String
    let id: UUID
}

struct ChatMessagePage {
    let messages: [SessionMessage]
    let nextCursor: ChatMessageCursor?
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

    func fetchMessages(
        sessionId: UUID,
        before: ChatMessageCursor? = nil,
        limit: Int = AppPagination.chatMessageLimit
    ) async throws -> ChatMessagePage {
        let pageSize = min(max(limit, 1), AppPagination.chatMessageLimit)
        var query = client
            .from("messages")
            .select(messageSelect)
            .eq("session_id", value: sessionId.uuidString)
        if let before {
            query = query.or("created_at.lt.\(before.timestamp),and(created_at.eq.\(before.timestamp),id.lt.\(before.id.uuidString))")
        }
        let rows: [MessageRow] = try await query
            .order("created_at", ascending: false)
            .order("id", ascending: false)
            .limit(pageSize + 1)
            .execute()
            .value
        let page = Array(rows.prefix(pageSize))
        return ChatMessagePage(
            messages: page.reversed().map(\.message),
            nextCursor: rows.count > pageSize ? page.last?.cursor : nil
        )
    }

    func sendMessage(sessionId: UUID, body: String) async throws -> SessionMessage {
        let safeBody: String
        do {
            safeBody = try UserContentPolicy.validate(body, field: .chatMessage)
        } catch UserContentPolicyError.required {
            throw ChatRepositoryError.emptyMessage
        }

        let userId = try await client.auth.session.user.id
        let payload = MessageInsert(sessionId: sessionId, userId: userId, body: safeBody)

        return try await client
            .from("messages")
            .insert(payload)
            .select(messageSelect)
            .single()
            .execute()
            .value
    }

    func fetchMessageUpdates(sessionId: UUID, ids: [UUID]) async throws -> [SessionMessage] {
        guard !ids.isEmpty else { return [] }
        precondition(ids.count <= AppPagination.chatMessageLimit)
        return try await client.from("messages").select(messageSelect)
            .eq("session_id", value: sessionId.uuidString)
            .in("id", values: ids.map(\.uuidString))
            .limit(AppPagination.chatMessageLimit)
            .execute().value
    }
}

// Keep the server timestamp verbatim: Date formatting can round away the
// microseconds needed to page reliably through messages with matching times.
private struct MessageRow: Decodable {
    let message: SessionMessage
    let cursor: ChatMessageCursor

    private enum CodingKeys: String, CodingKey { case createdAt = "created_at" }

    init(from decoder: Decoder) throws {
        message = try SessionMessage(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cursor = ChatMessageCursor(
            timestamp: try container.decode(String.self, forKey: .createdAt),
            id: message.id
        )
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
