import Foundation
import Supabase
import UIKit

@Observable
final class ChatViewModel {
    let sessionId: UUID
    let currentUserId: UUID

    var messages = Loadable<[SessionMessage]>.idle
    var draftText = ""
    var isSending = false
    var sendError: String?

    private let repository: ChatRepositoryProtocol
    private let blockRepository: BlockRepositoryProtocol
    private let client: SupabaseClient

    private var realtimeChannel: RealtimeChannelV2?
    private var realtimeTask: Task<Void, Never>?
    private var blockedUserIds: Set<UUID> = []

    init(
        sessionId: UUID,
        currentUserId: UUID,
        repository: ChatRepositoryProtocol = ChatRepository(),
        blockRepository: BlockRepositoryProtocol = BlockRepository(),
        client: SupabaseClient = SupabaseManager.shared
    ) {
        self.sessionId = sessionId
        self.currentUserId = currentUserId
        self.repository = repository
        self.blockRepository = blockRepository
        self.client = client
    }

    @MainActor
    func load() async {
        messages = .loading
        do {
            async let fetchedMessages = repository.fetchMessages(sessionId: sessionId, limit: AppPagination.chatMessageLimit)
            async let fetchedBlockedIds = blockRepository.fetchBlockedUserIds()
            let (items, blockedIds) = try await (fetchedMessages, fetchedBlockedIds)
            blockedUserIds = blockedIds
            messages = .loaded(
                BlockedMessageFilter.visibleMessages(
                    items,
                    currentUserId: currentUserId,
                    blockedUserIds: blockedIds
                )
            )
        } catch {
            messages = .failed(AppErrorMapper.message(for: error))
        }
    }

    @MainActor
    func block(userId: UUID) async -> Bool {
        guard userId != currentUserId else { return false }
        sendError = nil
        do {
            try await blockRepository.block(userId: userId)
            blockedUserIds.insert(userId)
            if case let .loaded(current) = messages {
                messages = .loaded(
                    BlockedMessageFilter.visibleMessages(
                        current,
                        currentUserId: currentUserId,
                        blockedUserIds: blockedUserIds
                    )
                )
            }
            return true
        } catch {
            sendError = AppErrorMapper.message(for: error)
            return false
        }
    }

    @MainActor
    func send() async {
        let trimmed = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSending else { return }

        sendError = nil
        isSending = true
        defer { isSending = false }

        let optimisticId = UUID()
        let optimistic = SessionMessage(
            id: optimisticId,
            sessionId: sessionId,
            userId: currentUserId,
            body: trimmed,
            createdAt: .now,
            author: nil
        )

        appendMessage(optimistic)
        draftText = ""

        do {
            let saved = try await repository.sendMessage(sessionId: sessionId, body: trimmed)
            replaceMessage(id: optimisticId, with: saved)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } catch {
            removeMessage(id: optimisticId)
            draftText = trimmed
            sendError = AppErrorMapper.message(for: error)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    @MainActor
    func startRealtime() async {
        await stopRealtime()
        guard case .loaded = messages else { return }

        let channel = client.channel("session-chat-\(sessionId.uuidString)")
        realtimeChannel = channel

        let inserts = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "messages",
            filter: .eq("session_id", value: sessionId)
        )

        do {
            try await channel.subscribeWithError()
        } catch {
            return
        }

        realtimeTask = Task { @MainActor in
            for await action in inserts {
                guard !Task.isCancelled else { break }
                appendFromRealtime(action)
            }
        }
    }

    @MainActor
    func stopRealtime() async {
        realtimeTask?.cancel()
        realtimeTask = nil

        if let channel = realtimeChannel {
            await channel.unsubscribe()
            await client.removeChannel(channel)
            realtimeChannel = nil
        }
    }

    @MainActor
    private func appendFromRealtime(_ action: InsertAction) {
        guard let id = uuid(from: action.record["id"]),
              let sessionId = uuid(from: action.record["session_id"]),
              let userId = uuid(from: action.record["user_id"]),
              let body = action.record["body"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !body.isEmpty else {
            return
        }

        let createdAt = date(from: action.record["created_at"]) ?? action.commitTimestamp
        let row = SessionMessage(
            id: id,
            sessionId: sessionId,
            userId: userId,
            body: body,
            createdAt: createdAt,
            author: nil
        )
        guard row.userId == currentUserId || !blockedUserIds.contains(row.userId) else { return }
        guard !containsMessage(id: row.id) else { return }
        appendMessage(row)
    }

    private func uuid(from json: AnyJSON?) -> UUID? {
        guard let json else { return nil }
        if let string = json.stringValue { return UUID(uuidString: string) }
        return nil
    }

    private func date(from json: AnyJSON?) -> Date? {
        guard let string = json?.stringValue else { return nil }
        if let date = Self.isoWithFraction.date(from: string) { return date }
        return Self.isoPlain.date(from: string)
    }

    private static let isoPlain: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let isoWithFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    @MainActor
    private func appendMessage(_ message: SessionMessage) {
        guard case let .loaded(current) = messages else { return }
        guard !containsMessage(id: message.id) else { return }
        messages = .loaded(current + [message])
    }

    @MainActor
    private func replaceMessage(id: UUID, with message: SessionMessage) {
        guard case let .loaded(current) = messages else { return }
        if let index = current.firstIndex(where: { $0.id == id }) {
            var next = current
            next[index] = message
            messages = .loaded(next)
        } else if !containsMessage(id: message.id) {
            messages = .loaded(current + [message])
        }
    }

    @MainActor
    private func removeMessage(id: UUID) {
        guard case let .loaded(current) = messages else { return }
        messages = .loaded(current.filter { $0.id != id })
    }

    private func containsMessage(id: UUID) -> Bool {
        messages.value?.contains(where: { $0.id == id }) ?? false
    }
}
