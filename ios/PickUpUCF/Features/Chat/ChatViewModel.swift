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
    var isLoadingOlder = false
    var historyError: String?
    var hasOlderMessages: Bool { nextCursor != nil }
    private(set) var isRefreshing = false
    var syncError: String?
    private(set) var authorError: String?

    private let repository: ChatRepositoryProtocol
    private let blockRepository: BlockRepositoryProtocol
    private let client: SupabaseClient

    private var realtimeChannel: RealtimeChannelV2?
    private var realtimeTask: Task<Void, Never>?
    private var statusTask: Task<Void, Never>?
    private var authorTask: Task<Void, Never>?
    private var lifecycleVersion = 0
    private var refreshAfterHistory = false
    private var resolvingAuthors = false
    private var pendingAuthors: [UUID: UUID] = [:] // User ID -> permitted message ID.
    private var inFlightAuthors: Set<UUID> = []
    private struct AuthorEntry {
        let profile: ProfileSummary?
        let resolvedAt: Date
    }
    private var authors: [UUID: AuthorEntry] = [:]
    private var authorRevision = 0
    private var refreshingVersion: Int?
    private var refreshAfterTransition = false
    private var locallyBlockedIds: Set<UUID> = []
    private var blockedUserIds: Set<UUID> = []
    private var nextCursor: ChatMessageCursor?
    // Realtime rows alone cannot prove that the gap before them has been fetched.
    private var synchronizedIds: Set<UUID> = []
    private var pendingMessageIds: Set<UUID> = []
    private let now: () -> Date

    init(
        sessionId: UUID,
        currentUserId: UUID,
        repository: ChatRepositoryProtocol = ChatRepository(),
        blockRepository: BlockRepositoryProtocol = BlockRepository(),
        client: SupabaseClient = SupabaseManager.shared,
        now: @escaping () -> Date = { .now }
    ) {
        self.sessionId = sessionId
        self.currentUserId = currentUserId
        self.repository = repository
        self.blockRepository = blockRepository
        self.client = client
        self.now = now
    }

    @MainActor
    func load() async {
        guard !messages.isLoading, !isLoadingOlder else { return }
        messages = .loading
        nextCursor = nil
        historyError = nil
        syncError = nil
        authorError = nil
        let version = lifecycleVersion
        do {
            async let fetchedMessages = repository.fetchMessages(sessionId: sessionId, before: nil, limit: AppPagination.chatMessageLimit)
            async let fetchedBlockedIds = blockRepository.fetchBlockedUserIds()
            let (page, blockedIds) = try await (fetchedMessages, fetchedBlockedIds)
            guard version == lifecycleVersion, !Task.isCancelled else { return }
            blockedUserIds = blockedIds
            nextCursor = page.nextCursor
            synchronizedIds = Set(page.messages.map(\.id))
            authors.removeAll()
            authorRevision += 1
            rememberAuthors(page.messages)
            messages = .loaded(merged(page.messages, into: []))
        } catch {
            guard version == lifecycleVersion, !Task.isCancelled else { return }
            messages = .failed(AppErrorMapper.message(for: error))
        }
    }

    @MainActor
    func loadOlder() async {
        guard let cursor = nextCursor, !isLoadingOlder, !isRefreshing, case .loaded = messages else { return }
        isLoadingOlder = true
        historyError = nil
        let version = lifecycleVersion
        defer {
            isLoadingOlder = false
            if refreshAfterHistory {
                refreshAfterHistory = false
                Task { await refresh() }
            }
        }
        do {
            let page = try await repository.fetchMessages(
                sessionId: sessionId, before: cursor, limit: AppPagination.chatMessageLimit
            )
            // Re-read current state after the await: realtime or a send may have
            // added messages, or blocking may have removed them in the meantime.
            guard version == lifecycleVersion, !Task.isCancelled, case let .loaded(current) = messages else { return }
            rememberAuthors(page.messages)
            messages = .loaded(merged(page.messages, into: current))
            nextCursor = page.nextCursor
        } catch {
            guard version == lifecycleVersion, !Task.isCancelled else { return }
            historyError = AppErrorMapper.message(for: error)
        }
    }

    @MainActor
    func block(userId: UUID) async -> Bool {
        guard userId != currentUserId else { return false }
        sendError = nil
        do {
            try await blockRepository.block(userId: userId)
            blockedUserIds.insert(userId)
            locallyBlockedIds.insert(userId)
            authors[userId] = nil
            pendingAuthors[userId] = nil
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
        guard !isSending, case .loaded = messages else { return }
        let trimmed: String
        do { trimmed = try UserContentPolicy.validate(draftText, field: .chatMessage) }
        catch { sendError = AppErrorMapper.message(for: error); return }

        sendError = nil
        isSending = true
        defer { isSending = false }

        let optimisticId = UUID()
        pendingMessageIds.insert(optimisticId)
        defer { pendingMessageIds.remove(optimisticId) }
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
            rememberAuthors([saved])
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
        let version = lifecycleVersion + 1
        await stopRealtime()
        guard case .loaded = messages, !Task.isCancelled, version == lifecycleVersion else { return }

        let channel = client.channel("session-chat-\(sessionId.uuidString)")
        realtimeChannel = channel

        let inserts = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "messages",
            filter: .eq("session_id", value: sessionId)
        )

        let statuses = channel.statusChange
        statusTask = Task { @MainActor [weak self] in
            for await status in statuses {
                guard let self, !Task.isCancelled, version == self.lifecycleVersion else { return }
                if status == .subscribed { await self.refresh() }
            }
        }

        do {
            try await channel.subscribeWithError()
        } catch {
            guard version == lifecycleVersion else { return }
            syncError = "Live updates paused."
            return
        }

        guard version == lifecycleVersion, !Task.isCancelled else { return }
        realtimeTask = Task { @MainActor [weak self] in
            for await action in inserts {
                guard let self, !Task.isCancelled, version == self.lifecycleVersion else { break }
                self.appendFromRealtime(action)
            }
        }
    }

    @MainActor
    func stopRealtime() async {
        lifecycleVersion += 1
        if messages.isLoading { messages = .idle }
        realtimeTask?.cancel()
        realtimeTask = nil
        statusTask?.cancel()
        statusTask = nil
        authorTask?.cancel()
        authorTask = nil
        pendingAuthors.removeAll()
        inFlightAuthors.removeAll()
        let channel = realtimeChannel
        realtimeChannel = nil

        if let channel {
            await channel.unsubscribe()
            await client.removeChannel(channel)
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
        receive(row)
    }

    @MainActor
    func receive(_ message: SessionMessage) {
        guard message.sessionId == sessionId, !blockedUserIds.contains(message.userId) else { return }
        var row = message
        if let entry = authors[row.userId], now().timeIntervalSince(entry.resolvedAt) < 60 {
            row.author = entry.profile
        } else if row.userId != currentUserId {
            queueAuthor(row)
        }
        appendMessage(row)
    }

    // Reads the same authorized message/author join as history; never broad profile queries.
    @MainActor
    func resolvePendingAuthors() async {
        guard !resolvingAuthors else { return }
        resolvingAuthors = true
        authorError = nil
        let version = lifecycleVersion
        defer {
            resolvingAuthors = false
            if version != lifecycleVersion, !pendingAuthors.isEmpty { scheduleAuthorResolution() }
        }
        while !pendingAuthors.isEmpty {
            let revision = authorRevision
            let batch = Dictionary(uniqueKeysWithValues: pendingAuthors.prefix(AppPagination.chatMessageLimit).map { ($0.key, $0.value) })
            for id in batch.keys { pendingAuthors[id] = nil }
            inFlightAuthors = Set(batch.keys)
            defer { inFlightAuthors.removeAll() }
            do {
                let rows = try await repository.fetchMessageUpdates(sessionId: sessionId, ids: Array(batch.values))
                guard version == lifecycleVersion, !Task.isCancelled else { return }
                if revision != authorRevision {
                    for (userId, id) in batch where authors[userId] == nil && !blockedUserIds.contains(userId) {
                        pendingAuthors[userId] = id
                    }
                    continue
                }
                for (userId, messageId) in batch where !blockedUserIds.contains(userId) {
                    let profile = rows.first { $0.id == messageId && $0.sessionId == sessionId && $0.userId == userId }?.author
                    cacheAuthor(profile, for: userId)
                }
                applyKnownAuthors()
            } catch {
                guard version == lifecycleVersion, !Task.isCancelled else { return }
                for (userId, id) in batch where !blockedUserIds.contains(userId) { pendingAuthors[userId] = id }
                authorError = "Sender names couldn’t load."
                return
            }
        }
    }

    @MainActor
    func refresh() async {
        guard case let .loaded(existing) = messages else { return }
        if isRefreshing {
            if refreshingVersion != lifecycleVersion { refreshAfterTransition = true }
            return
        }
        if isLoadingOlder { refreshAfterHistory = true; return }
        isRefreshing = true
        refreshingVersion = lifecycleVersion
        defer {
            isRefreshing = false
            refreshingVersion = nil
            if refreshAfterTransition {
                refreshAfterTransition = false
                Task { await refresh() }
            }
        }
        syncError = nil
        let version = lifecycleVersion
        do {
            let blocks = try await blockRepository.fetchBlockedUserIds()
            guard version == lifecycleVersion, !Task.isCancelled else { return }
            blockedUserIds = blocks.union(locallyBlockedIds)
            messages = .loaded(merged([], into: messages.value ?? []))
            let known = Set(existing.filter { synchronizedIds.contains($0.id) && !blockedUserIds.contains($0.userId) }.map(\.id))
            var fetched: [SessionMessage] = []
            var cursor: ChatMessageCursor?
            var seen: [ChatMessageCursor] = []
            var firstCursor: ChatMessageCursor?
            repeat {
                let page = try await repository.fetchMessages(sessionId: sessionId, before: cursor, limit: AppPagination.chatMessageLimit)
                guard version == lifecycleVersion, !Task.isCancelled else { return }
                if seen.isEmpty { firstCursor = page.nextCursor }
                fetched = page.messages + fetched
                if known.isEmpty || page.messages.contains(where: { known.contains($0.id) }) { break }
                cursor = page.nextCursor
                if let cursor {
                    guard !seen.contains(cursor) else { throw URLError(.badServerResponse) }
                    seen.append(cursor)
                }
            } while cursor != nil
            // Reconcile already-loaded history through authorized message reads.
            // Missing rows may have been deleted or become invisible since pagination.
            let fetchedIds = Set(fetched.map(\.id))
            let olderIds = existing.map(\.id).filter { !fetchedIds.contains($0) && !pendingMessageIds.contains($0) }
            var verifiedOlder: [SessionMessage] = []
            for offset in stride(from: 0, to: olderIds.count, by: AppPagination.chatMessageLimit) {
                let ids = Array(olderIds[offset..<min(offset + AppPagination.chatMessageLimit, olderIds.count)])
                let rows = try await repository.fetchMessageUpdates(sessionId: sessionId, ids: ids)
                guard version == lifecycleVersion, !Task.isCancelled else { return }
                verifiedOlder += rows.filter { $0.sessionId == sessionId && ids.contains($0.id) }
            }
            let checkedIds = Set(olderIds)
            let retained = (messages.value ?? []).filter { !checkedIds.contains($0.id) || pendingMessageIds.contains($0.id) }
            if known.isEmpty { nextCursor = firstCursor }
            synchronizedIds = Set(fetched.suffix(AppPagination.chatMessageLimit).map(\.id))
            authors.removeAll()
            authorRevision += 1
            rememberAuthors(fetched + verifiedOlder)
            messages = .loaded(merged(fetched + verifiedOlder, into: retained))
            // Revalidate identities in older loaded history, including renamed/hidden profiles.
            for row in messages.value ?? [] where authors[row.userId] == nil && row.userId != currentUserId {
                queueAuthor(row)
            }
            applyKnownAuthors()
        } catch {
            guard version == lifecycleVersion, !Task.isCancelled else { return }
            syncError = "Chat couldn’t refresh."
        }
    }

    private func cacheAuthor(_ profile: ProfileSummary?, for userId: UUID) {
        guard !blockedUserIds.contains(userId) else { return }
        authors[userId] = AuthorEntry(profile: profile?.id == userId ? profile : nil, resolvedAt: now())
        if authors.count > 100, let oldest = authors.min(by: { $0.value.resolvedAt < $1.value.resolvedAt })?.key {
            authors[oldest] = nil
        }
    }

    private func rememberAuthors(_ rows: [SessionMessage]) {
        for row in rows { cacheAuthor(row.author, for: row.userId) }
    }

    private func applyKnownAuthors() {
        guard case let .loaded(current) = messages else { return }
        messages = .loaded(merged(current.map { row in
            var row = row
            if let entry = authors[row.userId] { row.author = entry.profile }
            return row
        }, into: []))
    }

    private func queueAuthor(_ row: SessionMessage) {
        guard !inFlightAuthors.contains(row.userId) else { return }
        pendingAuthors[row.userId] = row.id
        scheduleAuthorResolution()
    }

    private func scheduleAuthorResolution() {
        guard authorTask == nil else { return }
        let version = lifecycleVersion
        authorTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .milliseconds(75)) }
            catch { return }
            guard let self, version == self.lifecycleVersion else { return }
            await self.resolvePendingAuthors()
            if version == self.lifecycleVersion { self.authorTask = nil }
        }
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
        messages = .loaded(merged([message], into: current))
    }

    @MainActor
    private func replaceMessage(id: UUID, with message: SessionMessage) {
        guard case let .loaded(current) = messages else { return }
        messages = .loaded(merged([message], into: current.filter { $0.id != id && $0.id != message.id }))
    }

    @MainActor
    private func removeMessage(id: UUID) {
        guard case let .loaded(current) = messages else { return }
        messages = .loaded(current.filter { $0.id != id })
    }

    private func merged(_ incoming: [SessionMessage], into current: [SessionMessage]) -> [SessionMessage] {
        var byId = Dictionary(current.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for message in incoming { byId[message.id] = message }
        return BlockedMessageFilter.visibleMessages(
            Array(byId.values), currentUserId: currentUserId, blockedUserIds: blockedUserIds
        ).sorted {
            if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
            return $0.id.uuidString < $1.id.uuidString
        }
    }
}
