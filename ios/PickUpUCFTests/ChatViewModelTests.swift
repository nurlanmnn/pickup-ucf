import XCTest
import Network
import Supabase
import SwiftUI
@testable import PickUpUCF

@MainActor
final class ChatViewModelTests: XCTestCase {
    private let sessionId = UUID()
    private let userId = UUID()
    private let cursor = ChatMessageCursor(timestamp: "2026-10-14T12:00:00.123456Z", id: UUID())

    func testInvalidContentPreservesDraftAndNeverSendsOptimisticMessage() async {
        let repository = ChatHistoryStub()
        repository.pages = [page([])]
        let vm = model(repository)
        await vm.load()
        for draft in [String(repeating: "🏀", count: 501), "hello\u{000B}"] {
            vm.draftText = draft
            await vm.send()
            XCTAssertEqual(vm.draftText, draft)
            XCTAssertEqual(vm.messages.value?.count, 0)
            XCTAssertNotNil(vm.sendError)
        }
    }

    func testRefreshRemovesDeletedMessagesFromOlderLoadedHistoryAndRetriesSafely() async {
        let repository = ChatHistoryStub()
        let kept = message(1), deleted = message(2), newest = message(3)
        repository.pages = [page([newest], cursor), page([kept, deleted]), page([newest]), page([newest])]
        repository.updates = [kept]
        let vm = model(repository)
        await vm.load()
        await vm.loadOlder()
        repository.failUpdates = true
        await vm.refresh()
        XCTAssertEqual(vm.messages.value?.map(\.id), [kept, deleted, newest].map(\.id))
        XCTAssertNotNil(vm.syncError)
        repository.failUpdates = false
        await vm.refresh()
        XCTAssertEqual(vm.messages.value?.map(\.id), [kept, newest].map(\.id))
        XCTAssertNil(vm.syncError)
        XCTAssertTrue(repository.updateRequests.allSatisfy { $0.count <= 50 })
        await vm.stopRealtime()
    }

    func testRefreshDoesNotDropAnInFlightOptimisticSend() async {
        let repository = ChatHistoryStub()
        let newest = message(1), saved = message(2, own: true)
        repository.pages = [page([newest]), page([newest])]
        repository.saved = saved
        let vm = model(repository)
        await vm.load()
        repository.duringAsyncSend = {
            await vm.refresh()
            XCTAssertEqual(vm.messages.value?.count, 2)
            XCTAssertTrue(repository.updateRequests.isEmpty, "An optimistic ID is not yet a database row")
        }
        vm.draftText = "Synthetic message"
        await vm.send()
        XCTAssertEqual(vm.messages.value?.map(\.id), [newest, saved].map(\.id))
        await vm.stopRealtime()
    }

    func testClosingDuringHistoryReconciliationRejectsLateDeletions() async {
        let repository = ChatHistoryStub()
        let older = message(1), newest = message(2)
        repository.pages = [page([newest], cursor), page([older]), page([newest])]
        let vm = model(repository)
        await vm.load()
        await vm.loadOlder()
        repository.duringUpdates = { await vm.stopRealtime() }
        await vm.refresh()
        XCTAssertEqual(vm.messages.value?.map(\.id), [older, newest].map(\.id))
    }

    func testRealtimeMessageReusesThePermittedAuthorFromLoadedHistory() async {
        let repository = ChatHistoryStub()
        var known = message(1)
        known.author = ProfileSummary(id: known.userId, displayName: "Synthetic Knight", username: "knight")
        repository.pages = [page([known])]
        let vm = model(repository)
        await vm.load()
        let incoming = SessionMessage(id: UUID(), sessionId: sessionId, userId: known.userId,
                                      body: "Incoming", createdAt: known.createdAt.addingTimeInterval(1), author: nil)
        vm.receive(incoming)
        XCTAssertEqual(vm.messages.value?.last?.senderLabel(currentUserId: userId), "@knight")
    }

    func testSimultaneousUnknownSendersAreResolvedInBoundedBatches() async {
        let repository = ChatHistoryStub()
        repository.pages = [page([])]
        let vm = model(repository)
        await vm.load()
        let incoming = (1...120).map { message($0) }
        repository.updates = incoming.map { row in
            var row = row
            row.author = ProfileSummary(id: row.userId, displayName: "Synthetic \(row.body)")
            return row
        }
        incoming.forEach(vm.receive)
        await vm.resolvePendingAuthors()
        XCTAssertEqual(repository.updateRequests.count, 3)
        XCTAssertTrue(repository.updateRequests.allSatisfy { $0.count <= 50 })
        XCTAssertTrue(vm.messages.value?.allSatisfy { $0.author != nil } == true)
        await vm.stopRealtime()
    }

    func testRepeatedUnknownSenderNeedsOneLookupAndMissingProfileStaysAnonymous() async {
        let repository = ChatHistoryStub()
        repository.pages = [page([])]
        let vm = model(repository)
        await vm.load()
        let first = message(1)
        vm.receive(first)
        vm.receive(SessionMessage(id: UUID(), sessionId: sessionId, userId: first.userId,
                                  body: "Second", createdAt: .now, author: nil))
        await vm.resolvePendingAuthors()
        XCTAssertEqual(repository.updateRequests.count, 1)
        XCTAssertEqual(repository.updateRequests.first?.count, 1)
        XCTAssertTrue(vm.messages.value?.allSatisfy { $0.senderLabel(currentUserId: userId) == "Player" } == true)
        vm.receive(first)
        await vm.resolvePendingAuthors()
        XCTAssertEqual(repository.updateRequests.count, 1, "A missing/hidden profile is negatively cached briefly")
        await vm.stopRealtime()
    }

    func testBlockingDuringResolutionCannotRestoreIdentityOrMessages() async {
        let repository = ChatHistoryStub()
        repository.pages = [page([])]
        let vm = model(repository)
        await vm.load()
        let row = message(1)
        var resolved = row
        resolved.author = ProfileSummary(id: row.userId, displayName: "Hidden Knight")
        repository.updates = [resolved]
        vm.receive(row)
        repository.duringUpdates = { _ = await vm.block(userId: row.userId) }
        await vm.resolvePendingAuthors()
        XCTAssertEqual(vm.messages.value, [])
        vm.receive(row)
        XCTAssertEqual(vm.messages.value, [])
        await vm.stopRealtime()
    }

    func testAuthorFailureCanRecoverAndStoppingRejectsLateResults() async {
        let repository = ChatHistoryStub()
        repository.pages = [page([])]
        let vm = model(repository)
        await vm.load()
        let row = message(1)
        vm.receive(row)
        repository.shouldFail = true
        await vm.resolvePendingAuthors()
        XCTAssertNotNil(vm.authorError)
        repository.shouldFail = false
        var resolved = row
        resolved.author = ProfileSummary(id: row.userId, displayName: "Late Knight")
        repository.updates = [resolved]
        await vm.resolvePendingAuthors()
        XCTAssertEqual(vm.messages.value?.first?.author?.displayName, "Late Knight")
        XCTAssertNil(vm.authorError)
        let late = message(2)
        vm.receive(late)
        var lateResolved = late
        lateResolved.author = ProfileSummary(id: late.userId, displayName: "Must not appear")
        repository.updates = [lateResolved]
        repository.duringUpdates = { await vm.stopRealtime() }
        await vm.resolvePendingAuthors()
        XCTAssertNil(vm.messages.value?.last?.author)
    }

    func testReconnectFillsMultiplePagesWithoutDiscardingLoadedHistoryOrRealtimeRows() async {
        let repository = ChatHistoryStub()
        let original = (1...50).map { message($0) }
        let gap = (51...170).map { message($0) }
        let realtime = message(171)
        let secondCursor = ChatMessageCursor(timestamp: "2026-10-21T12:00:00Z", id: UUID())
        repository.pages = [page(original, cursor), page(Array(gap.suffix(49)) + [realtime], cursor),
                            page(Array(gap[21..<71]), secondCursor), page(original + Array(gap.prefix(21)))]
        let vm = model(repository)
        await vm.load()
        vm.receive(realtime) // A new event must not conceal the un-fetched gap before it.
        await vm.refresh()
        XCTAssertEqual(vm.messages.value?.map(\.id), (original + gap + [realtime]).map(\.id))
        XCTAssertTrue(vm.hasOlderMessages, "Catch-up must preserve the old-history cursor")
        XCTAssertEqual(repository.cursors.count, 4)
        await vm.stopRealtime()
    }

    func testForegroundRefreshUpdatesRenamedAndHiddenProfilesAcrossHistory() async {
        let repository = ChatHistoryStub()
        var old = message(1)
        old.author = ProfileSummary(id: old.userId, displayName: "Old name")
        var renamed = old
        renamed.author = ProfileSummary(id: old.userId, displayName: "New name")
        var hidden = old
        hidden.author = nil
        repository.pages = [page([old]), page([renamed]), page([hidden])]
        let vm = model(repository)
        await vm.load()
        await vm.refresh()
        XCTAssertEqual(vm.messages.value?.first?.author?.displayName, "New name")
        await vm.refresh()
        XCTAssertNil(vm.messages.value?.first?.author)
        XCTAssertEqual(vm.messages.value?.first?.senderLabel(currentUserId: userId), "Player")
    }

    func testRefreshFailurePreservesConversationAndCanRetryWithoutOverlap() async {
        let repository = ChatHistoryStub()
        let first = message(1), second = message(2)
        repository.pages = [page([first]), page([first, second])]
        let vm = model(repository)
        await vm.load()
        repository.shouldFail = true
        await vm.refresh()
        XCTAssertEqual(vm.messages.value, [first])
        XCTAssertNotNil(vm.syncError)
        repository.shouldFail = false
        repository.duringFetch = { await vm.refresh() }
        await vm.refresh()
        XCTAssertEqual(vm.messages.value, [first, second])
        XCTAssertNil(vm.syncError)
        XCTAssertFalse(vm.isRefreshing)
        XCTAssertEqual(repository.cursors.count, 3)
    }

    func testStaleAuthorLookupCannotUndoForegroundRename() async {
        let repository = ChatHistoryStub()
        let row = message(1)
        var renamed = row
        renamed.author = ProfileSummary(id: row.userId, displayName: "New name")
        var stale = row
        stale.author = ProfileSummary(id: row.userId, displayName: "Old name")
        repository.pages = [page([]), page([renamed])]
        let vm = model(repository)
        await vm.load()
        vm.receive(row)
        repository.updates = [stale]
        repository.duringUpdates = { await vm.refresh() }
        await vm.resolvePendingAuthors()
        XCTAssertEqual(vm.messages.value?.first?.author?.displayName, "New name")
        await vm.stopRealtime()
    }

    func testAuthorCacheExpiresAndIsBoundedToOneHundredSenders() async {
        let repository = ChatHistoryStub()
        let rows = (1...120).map { index in
            var row = message(index)
            row.author = ProfileSummary(id: row.userId, displayName: "Knight \(index)")
            return row
        }
        repository.pages = [page(rows)]
        var clock = Date(timeIntervalSince1970: 1000)
        let vm = ChatViewModel(sessionId: sessionId, currentUserId: userId, repository: repository,
                               blockRepository: ChatBlocksStub(), now: {
                                   clock = clock.addingTimeInterval(0.001)
                                   return clock
                               })
        await vm.load()
        repository.updates = rows
        vm.receive(rows[0]) // Evicted, even though the message remains in history.
        await vm.resolvePendingAuthors()
        XCTAssertEqual(repository.updateRequests.count, 1)
        vm.receive(rows[119])
        await vm.resolvePendingAuthors()
        XCTAssertEqual(repository.updateRequests.count, 1)
        clock = clock.addingTimeInterval(61)
        vm.receive(rows[119])
        await vm.resolvePendingAuthors()
        XCTAssertEqual(repository.updateRequests.count, 2)
        await vm.stopRealtime()
    }

    func testStoppingDuringCatchUpCannotApplyLateRows() async {
        let repository = ChatHistoryStub()
        let first = message(1), second = message(2)
        repository.pages = [page([first]), page([first, second])]
        let vm = model(repository)
        await vm.load()
        repository.duringFetch = { await vm.stopRealtime() }
        await vm.refresh()
        XCTAssertEqual(vm.messages.value, [first])
        XCTAssertFalse(vm.isRefreshing)
    }

    func testOlderPagePreservesRealtimeInsertAndDeduplicatesOverlap() async {
        let repository = ChatHistoryStub()
        let first = message(2), newest = message(3), older = message(1)
        repository.pages = [page([first], cursor), page([older, first])]
        let vm = model(repository)
        await vm.load()
        repository.duringFetch = { vm.receive(newest) }
        await vm.loadOlder()
        XCTAssertEqual(vm.messages.value?.map(\.id), [older.id, first.id, newest.id])
        XCTAssertEqual(repository.cursors, [nil, cursor])
        XCTAssertFalse(vm.hasOlderMessages)
    }

    func testFailedOlderPageKeepsMessagesAndRetriesTheSameCursor() async {
        let repository = ChatHistoryStub()
        let first = message(2), older = message(1)
        repository.pages = [page([first], cursor), page([older])]
        let vm = model(repository)
        await vm.load()
        repository.shouldFail = true
        await vm.loadOlder()
        XCTAssertEqual(vm.messages.value, [first])
        XCTAssertNotNil(vm.historyError)
        XCTAssertTrue(vm.hasOlderMessages)
        XCTAssertFalse(vm.isLoadingOlder)
        repository.shouldFail = false
        await vm.loadOlder()
        XCTAssertEqual(repository.cursors, [nil, cursor, cursor])
        XCTAssertEqual(vm.messages.value, [older, first])
        XCTAssertNil(vm.historyError)
    }

    func testInvalidatedInitialLoadCanRetryWithoutRemainingLoading() async {
        let repository = ChatHistoryStub()
        let stale = message(1), fresh = message(2)
        repository.pages = [page([stale]), page([fresh])]
        let vm = model(repository)
        repository.duringFetch = { await vm.stopRealtime() }
        await vm.load()
        XCTAssertFalse(vm.messages.isLoading)
        XCTAssertNil(vm.messages.value, "Invalidated load must not publish late rows")
        repository.duringFetch = nil
        await vm.load()
        XCTAssertEqual(vm.messages.value, [fresh])
    }

    func testCancelledInitialLoadCanRetryWithoutRemainingLoading() async {
        let repository = ChatHistoryStub()
        let stale = message(1), fresh = message(2)
        repository.pages = [page([stale]), page([fresh])]
        let vm = model(repository)
        var task: Task<Void, Never>?
        repository.duringFetch = { task?.cancel() }
        task = Task { await vm.load() }
        await task?.value
        XCTAssertFalse(vm.messages.isLoading)
        XCTAssertNil(vm.messages.value, "Cancelled load must not publish late rows")
        repository.duringFetch = nil
        await vm.load()
        XCTAssertEqual(vm.messages.value, [fresh])
    }

    func testEmptyHistoryStopsPaginationAndInitialFailureCanRetry() async {
        let repository = ChatHistoryStub()
        repository.pages = [page([])]
        repository.shouldFail = true
        let vm = model(repository)
        await vm.load()
        XCTAssertNotNil(vm.messages.errorMessage)
        repository.shouldFail = false
        await vm.load()
        await vm.loadOlder()
        XCTAssertEqual(vm.messages.value, [])
        XCTAssertEqual(repository.cursors, [nil, nil])
        XCTAssertFalse(vm.hasOlderMessages)
    }

    func testBlockedRowsDoNotHideTheNextPageAndRealtimeCannotRestoreThem() async {
        let blocked = message(2), visible = message(1)
        let repository = ChatHistoryStub()
        repository.pages = [page([blocked], cursor), page([visible])]
        let blocks = ChatBlocksStub(ids: [blocked.userId])
        let vm = model(repository, blocks: blocks)
        await vm.load()
        XCTAssertEqual(vm.messages.value, [])
        XCTAssertTrue(vm.hasOlderMessages)
        vm.receive(blocked)
        await vm.loadOlder()
        XCTAssertEqual(vm.messages.value, [visible])
    }

    func testBlockDuringOlderFetchFiltersReturnedHistory() async {
        let blocked = message(1), visible = message(2)
        let repository = ChatHistoryStub()
        repository.pages = [page([visible], cursor), page([blocked])]
        let vm = model(repository)
        await vm.load()
        repository.duringFetch = { _ = await vm.block(userId: blocked.userId) }
        await vm.loadOlder()
        XCTAssertEqual(vm.messages.value, [visible])
    }

    func testDuplicateAndOutOfOrderRealtimeRowsAreMergedChronologically() async {
        let repository = ChatHistoryStub()
        let first = message(1), last = message(3), middle = message(2)
        repository.pages = [page([last])]
        let vm = model(repository)
        await vm.load()
        vm.receive(first)
        vm.receive(middle)
        vm.receive(last)
        let foreign = SessionMessage(id: UUID(), sessionId: UUID(), userId: userId,
                                     body: "Other chat", createdAt: .now, author: nil)
        vm.receive(foreign)
        XCTAssertEqual(vm.messages.value, [first, middle, last])
    }

    func testRealtimeEchoBeforeSendResponseDoesNotDuplicateSavedMessage() async {
        let repository = ChatHistoryStub()
        repository.pages = [page([])]
        let vm = model(repository)
        await vm.load()
        let saved = message(1, own: true)
        repository.saved = saved
        repository.duringSend = { vm.receive(saved) }
        vm.draftText = "Synthetic message"
        await vm.send()
        XCTAssertEqual(vm.messages.value, [saved])
        XCTAssertEqual(vm.draftText, "")
        XCTAssertFalse(vm.isSending)
    }

    func testOverlappingOlderLoadsAreIgnored() async {
        let repository = ChatHistoryStub()
        repository.pages = [page([message(2)], cursor), page([message(1)])]
        let vm = model(repository)
        await vm.load()
        repository.duringFetch = { await vm.loadOlder() }
        await vm.loadOlder()
        XCTAssertEqual(repository.cursors.count, 2)
        XCTAssertEqual(vm.messages.value?.count, 2)
    }

    func testRenderedHistoryPrependKeepsTheReadingPosition() async throws {
        let repository = ChatHistoryStub()
        repository.pages = [page((101...150).map { message($0) }, cursor), page((51...100).map { message($0) })]
        let vm = model(repository)
        let host = UIHostingController(rootView: NavigationStack { ChatView(viewModel: vm) })
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKeyWindow = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.frame = scene.coordinateSpace.bounds
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
            previousKeyWindow?.makeKey()
        }

        try await settleLayout(host)
        let scroll = try XCTUnwrap(scrollViews(in: host.view).max { $0.contentSize.height < $1.contentSize.height })
        XCTAssertGreaterThan(scroll.contentSize.height, scroll.bounds.height)
        XCTAssertEqual(vm.messages.value?.count, 50)
        scroll.setContentOffset(CGPoint(x: 0, y: -scroll.adjustedContentInset.top), animated: false)
        try await settleLayout(host)
        let originalOffset = scroll.contentOffset.y
        let originalHeight = scroll.contentSize.height
        let originalMessageY = try XCTUnwrap(accessibilityElement(in: host.view, label: "Message 101")).accessibilityFrame.minY

        let button = try XCTUnwrap(accessibilityElement(in: host.view, label: "Load older messages"))
        XCTAssertTrue(button.accessibilityActivate())
        try await settleLayout(host)

        XCTAssertEqual(vm.messages.value?.count, 100)
        let updatedScroll = try XCTUnwrap(scrollViews(in: host.view).max { $0.contentSize.height < $1.contentSize.height })
        let metrics = XCTAttachment(string: "same scroll: \(scroll === updatedScroll); before: \(originalOffset), \(originalHeight); after: \(updatedScroll.contentOffset.y), \(updatedScroll.contentSize.height)")
        metrics.lifetime = .keepAlways
        add(metrics)
        let insertedHeight = updatedScroll.contentSize.height - originalHeight
        XCTAssertGreaterThan(insertedHeight, 1000)
        let updatedMessageY = try XCTUnwrap(accessibilityElement(in: host.view, label: "Message 101")).accessibilityFrame.minY
        XCTAssertEqual(updatedMessageY, originalMessageY, accuracy: 80, "The same actual message must stay in the viewport")
        // LazyVStack's content-height estimate changes with viewport height. Compare the
        // actual message above rather than treating estimated inserted height as exact.
        XCTAssertGreaterThan(updatedScroll.contentOffset.y - originalOffset, 1000)
        let image = UIGraphicsImageRenderer(bounds: host.view.bounds).image { _ in
            host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = "Chat history after loading older messages"
        attachment.lifetime = .keepAlways
        add(attachment)
        host.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
        try await settleLayout(host)
        let largeImage = UIGraphicsImageRenderer(bounds: host.view.bounds).image { _ in
            host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
        }
        let largeAttachment = XCTAttachment(image: largeImage)
        largeAttachment.name = "Chat at Accessibility XXXL"
        largeAttachment.lifetime = .keepAlways
        add(largeAttachment)
        await vm.stopRealtime()
    }

    private func settleLayout(_ host: UIViewController) async throws {
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(350))
        host.view.layoutIfNeeded()
    }

    private func scrollViews(in view: UIView) -> [UIScrollView] {
        let descendants = view.subviews.flatMap { self.scrollViews(in: $0) }
        return (view as? UIScrollView).map { [$0] + descendants } ?? descendants
    }

    private func accessibilityElement(in object: NSObject, label: String) -> NSObject? {
        if object.accessibilityLabel == label { return object }
        let count = object.accessibilityElementCount()
        if count > 0, count < 1000 {
            for index in 0..<count {
                if let child = object.accessibilityElement(at: index) as? NSObject,
                   child !== object,
                   let found = accessibilityElement(in: child, label: label) { return found }
            }
        }
        if let view = object as? UIView {
            for child in view.subviews {
                if let found = accessibilityElement(in: child, label: label) { return found }
            }
        }
        return nil
    }

    private func page(_ messages: [SessionMessage], _ cursor: ChatMessageCursor? = nil) -> ChatMessagePage {
        ChatMessagePage(messages: messages, nextCursor: cursor)
    }

    private func message(_ index: Int, own: Bool = false) -> SessionMessage {
        SessionMessage(id: UUID(), sessionId: sessionId, userId: own ? userId : UUID(),
                       body: "Message \(index)", createdAt: Date(timeIntervalSince1970: Double(index)), author: nil)
    }

    private func model(_ repository: ChatHistoryStub, blocks: ChatBlocksStub = ChatBlocksStub()) -> ChatViewModel {
        ChatViewModel(sessionId: sessionId, currentUserId: userId, repository: repository,
                      blockRepository: blocks, client: SupabaseClient(
                        supabaseURL: URL(string: "https://chat-tests.invalid")!, supabaseKey: "synthetic-test-key"
                      ))
    }
}

private final class ChatHistoryStub: ChatRepositoryProtocol {
    var pages: [ChatMessagePage] = []
    var cursors: [ChatMessageCursor?] = []
    var shouldFail = false
    var duringFetch: (() async -> Void)?
    var duringSend: (() -> Void)?
    var duringAsyncSend: (() async -> Void)?
    var saved: SessionMessage!
    var failUpdates = false
    var updates: [SessionMessage] = []
    var updateRequests: [[UUID]] = []
    var duringUpdates: (() async -> Void)?

    func fetchMessageUpdates(sessionId: UUID, ids: [UUID]) async throws -> [SessionMessage] {
        updateRequests.append(ids)
        await duringUpdates?()
        if shouldFail { throw URLError(.notConnectedToInternet) }
        if failUpdates { throw URLError(.notConnectedToInternet) }
        return updates.filter { ids.contains($0.id) }
    }

    func fetchMessages(sessionId: UUID, before: ChatMessageCursor?, limit: Int) async throws -> ChatMessagePage {
        cursors.append(before)
        if shouldFail { throw URLError(.notConnectedToInternet) }
        await duringFetch?()
        return pages.removeFirst()
    }

    func sendMessage(sessionId: UUID, body: String) async throws -> SessionMessage {
        duringSend?()
        await duringAsyncSend?()
        return saved
    }
}

private final class ChatBlocksStub: BlockRepositoryProtocol {
    var ids: Set<UUID>
    init(ids: Set<UUID> = []) { self.ids = ids }
    func block(userId: UUID) async throws { ids.insert(userId) }
    func unblock(userId: UUID) async throws { ids.remove(userId) }
    func fetchBlockedUserIds() async throws -> Set<UUID> { ids }
    func fetchBlockedUsers() async throws -> [BlockedUser] { [] }
}

@MainActor
final class ChatRealtimeDiagnosticsTests: XCTestCase {
    private var records: [ChatRealtimeDiagnostics.Record] = []

    func testActualSubscribeRecordsStatusAndReturnAndRefreshesWithExactFilter() async throws {
        try await harness { server, client, repository, vm in
            await vm.load()
            await vm.startRealtime()
            try await self.wait { repository.cursors.count == 2 }
            XCTAssertNil(vm.syncError)
            XCTAssertEqual(client.realtimeV2.channels.count, 1)
            let join = try XCTUnwrap(server.frames.first { $0[3] as? String == "phx_join" })
            let payload = try XCTUnwrap(join[4] as? [String: Any])
            let config = try XCTUnwrap(payload["config"] as? [String: Any])
            let changes = try XCTUnwrap(config["postgres_changes"] as? [[String: Any]])
            XCTAssertEqual(changes.count, 1)
            XCTAssertEqual(changes.first?["schema"] as? String, "public")
            XCTAssertEqual(changes.first?["table"] as? String, "messages")
            XCTAssertEqual(changes.first?["event"] as? String, "INSERT")
            XCTAssertEqual(changes.first?["filter"] as? String, "session_id=eq.\(vm.sessionId.uuidString)")
            XCTAssertEqual(self.outcomes, [.returned])
            XCTAssertTrue(self.records.contains { $0.operation == .channelStatus && $0.result == .subscribed })
            XCTAssertEqual(Set(self.records.map(\.attemptID)).count, 1)
            await vm.stopRealtime()
            XCTAssertTrue(client.realtimeV2.channels.isEmpty)
            XCTAssertTrue(server.frames.contains { $0[3] as? String == "phx_leave" })
            try self.assertPrivate(vm)
        }
    }

    func testRejectedSubscribePreservesPausedErrorAndNeverRefreshes() async throws {
        try await harness(mode: .reject) { _, _, repository, vm in
            await vm.load()
            await vm.startRealtime()
            XCTAssertEqual(vm.syncError, "Live updates paused.")
            XCTAssertEqual(repository.cursors.count, 1)
            XCTAssertEqual(self.outcomes, [.failed])
            XCTAssertEqual(self.records.last(where: { $0.operation == .subscribe })?.failure, .unknown)
            try self.assertPrivate(vm)
        }
    }

    func testUnacknowledgedSubscribeTimesOutWithoutClaimingTransportCause() async throws {
        try await harness(mode: .silent) { server, _, repository, vm in
            await vm.load()
            await vm.startRealtime()
            XCTAssertTrue(server.frames.contains { $0[3] as? String == "phx_join" })
            XCTAssertEqual(vm.syncError, "Live updates paused.")
            XCTAssertEqual(repository.cursors.count, 1)
            XCTAssertEqual(self.outcomes, [.failed])
            XCTAssertEqual(self.records.last(where: { $0.operation == .subscribe })?.failure, .unknown)
        }
    }

    func testStopDuringPendingSubscriptionRecordsSupersededWithoutLateUIError() async throws {
        try await harness(mode: .silent) { server, client, repository, vm in
            await vm.load()
            let start = Task { await vm.startRealtime() }
            try await self.wait { server.frames.contains { $0[3] as? String == "phx_join" } }
            await vm.stopRealtime()
            await start.value
            XCTAssertNil(vm.syncError)
            XCTAssertEqual(repository.cursors.count, 1)
            XCTAssertTrue(client.realtimeV2.channels.isEmpty)
            XCTAssertEqual(self.outcomes, [.superseded])
        }
    }

    func testCancellationDuringSubscribeIsVisibleAndPreservesOriginalPausedError() async throws {
        try await harness(mode: .silent) { server, _, repository, vm in
            await vm.load()
            let start = Task { await vm.startRealtime() }
            try await self.wait { server.frames.contains { $0[3] as? String == "phx_join" } }
            start.cancel()
            await start.value
            XCTAssertEqual(vm.syncError, "Live updates paused.")
            XCTAssertEqual(repository.cursors.count, 1)
            XCTAssertEqual(self.outcomes, [.cancelled])
            XCTAssertEqual(self.records.last(where: { $0.operation == .subscribe })?.failure, .cancelled)
        }
    }

    func testSupersededWinsWhenCallerAlsoCancelsPendingSubscribe() async throws {
        try await harness(mode: .silent) { server, client, repository, vm in
            await vm.load()
            let start = Task { await vm.startRealtime() }
            try await self.wait { server.frames.contains { $0[3] as? String == "phx_join" } }
            start.cancel()
            await vm.stopRealtime()
            await start.value
            XCTAssertEqual(self.outcomes, [.superseded])
            XCTAssertEqual(self.records.last(where: { $0.operation == .subscribe })?.failure, .cancelled)
            XCTAssertNil(vm.syncError)
            XCTAssertEqual(repository.cursors.count, 1)
            XCTAssertTrue(client.realtimeV2.channels.isEmpty)
        }
    }

    func testServerCloseIsFailureEvenWhenSDKThrowsCancellation() async throws {
        try await harness(mode: .silent) { server, _, repository, vm in
            await vm.load()
            let start = Task { await vm.startRealtime() }
            try await self.wait { server.frames.contains { $0[3] as? String == "phx_join" } }
            server.closeLastChannel()
            await start.value
            XCTAssertEqual(vm.syncError, "Live updates paused.")
            XCTAssertEqual(repository.cursors.count, 1)
            XCTAssertEqual(self.outcomes, [.failed])
            XCTAssertEqual(self.records.last(where: { $0.operation == .subscribe })?.failure, .cancelled)
        }
    }

    func testServerCloseAfterSubscribeRecordsStatusWithoutRewritingReturnedOutcome() async throws {
        try await harness { server, _, repository, vm in
            await vm.load()
            await vm.startRealtime()
            try await self.wait { repository.cursors.count == 2 }
            let priorUnsubscribed = self.records.filter { $0.result == .unsubscribed }.count
            server.closeLastChannel()
            try await self.wait { self.records.filter { $0.result == .unsubscribed }.count > priorUnsubscribed }
            XCTAssertEqual(self.outcomes, [.returned])
            XCTAssertEqual(repository.cursors.count, 2)
            try self.assertPrivate(vm)
        }
    }

    func testRetryCreatesFreshAttemptAndPreservesRefreshBehavior() async throws {
        try await harness(mode: .reject) { server, _, repository, vm in
            await vm.load()
            await vm.startRealtime()
            server.mode = .accept
            await vm.startRealtime()
            try await self.wait { repository.cursors.count == 2 }
            XCTAssertNil(vm.syncError)
            XCTAssertEqual(self.outcomes, [.failed, .returned])
            let attempts = self.records.filter { $0.operation == .subscribe }.map(\.attemptID)
            XCTAssertEqual(Set(attempts).count, 2)
        }
    }

    func testUnloadedAndAlreadyCancelledStartDoNotSubscribeOrLog() async throws {
        try await harness { server, client, _, vm in
            await vm.startRealtime()
            await vm.load()
            let start = Task { withUnsafeCurrentTask { $0?.cancel() }; await vm.startRealtime() }
            await start.value
            XCTAssertTrue(server.frames.isEmpty)
            XCTAssertTrue(client.realtimeV2.channels.isEmpty)
            XCTAssertTrue(self.records.isEmpty)
        }
    }

    func testDefaultLoggerRuntimeSmoke() async throws {
        try await harness(capture: false) { server, _, repository, vm in
            await vm.load()
            await vm.startRealtime()
            try await self.wait { repository.cursors.count == 2 }
            XCTAssertNil(vm.syncError)
            server.mode = .reject
            await vm.startRealtime()
            XCTAssertEqual(vm.syncError, "Live updates paused.")
        }
    }

    private var outcomes: [ChatRealtimeDiagnostics.Result] {
        records.filter { $0.operation == .subscribe }.map(\.result)
    }

    private func assertPrivate(_ vm: ChatViewModel) throws {
        XCTAssertFalse(records.isEmpty)
        for record in records {
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(record.json.utf8)) as? [String: Any])
            XCTAssertEqual(Set(json.keys), Set(["event", "operation", "result", "failure", "attempt_id", "duration_ms", "version", "build", "configuration", "environment"]))
            XCTAssertEqual(json["event"] as? String, "realtime_operation")
            XCTAssertEqual(json["environment"] as? String, "unit_test")
            XCTAssertNotNil(UUID(uuidString: record.attemptID))
            XCTAssertGreaterThanOrEqual(record.durationMS, 0)
            for secret in [vm.sessionId.uuidString, vm.currentUserId.uuidString, "private", "session-chat", "session_id", "127.0.0.1", "phx_", "https:", "ws:"] {
                XCTAssertFalse(record.json.contains(secret))
            }
        }
    }

    private func wait(_ predicate: () -> Bool) async throws {
        let end = ProcessInfo.processInfo.systemUptime + 4
        while !predicate() {
            guard ProcessInfo.processInfo.systemUptime < end else { throw RealtimeFixtureError.timeout }
            try await Task.sleep(for: .milliseconds(5))
        }
    }

    private func harness(
        mode: LoopbackRealtimeServer.Mode = .accept, capture: Bool = true,
        action: (LoopbackRealtimeServer, SupabaseClient, ChatHistoryStub, ChatViewModel) async throws -> Void
    ) async throws {
        let server = try LoopbackRealtimeServer(mode: mode)
        defer { server.stop() }
        try await wait { server.port != nil }
        let port = try XCTUnwrap(server.port)
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [RealtimeDenyHTTP.self]
        let client = SupabaseClient(supabaseURL: URL(string: "http://127.0.0.1:\(port)")!, supabaseKey: "private-synthetic-key",
            options: .init(auth: .init(storage: RealtimeDiscardStorage(), autoRefreshToken: false),
                           global: .init(session: URLSession(configuration: config), logger: nil),
                           realtime: .init(timeoutInterval: 0.4, maxRetryAttempts: 1,
                                           disconnectOnEmptyChannelsAfter: 0, handleAppLifecycle: false)))
        let repository = ChatHistoryStub()
        repository.pages = (0..<10).map { _ in ChatMessagePage(messages: [], nextCursor: nil) }
        let vm = ChatViewModel(sessionId: UUID(), currentUserId: UUID(), repository: repository,
            blockRepository: ChatBlocksStub(), client: client,
            realtimeDiagnostics: capture ? .init { self.records.append($0) } : .init())
        do { try await action(server, client, repository, vm) }
        catch {
            await vm.stopRealtime()
            await client.realtimeV2.disconnect()
            throw error
        }
        await vm.stopRealtime()
        await client.realtimeV2.disconnect()
    }
}

@MainActor
final class SessionDetailRealtimeIsolationTests: XCTestCase {
    func testUISmokeLoadedDetailNeverConnectsOrCreatesAChannel() async throws {
        for mode in [AppTestMode.uiSmoke, .uiSmokeAuthenticated] {
            try await harness(mode: mode) { server, client, vm in
                await vm.startSessionRealtime()
                try await Task.sleep(for: .milliseconds(250))
                XCTAssertEqual(server.acceptedConnectionCount, 0)
                XCTAssertTrue(server.frames.isEmpty)
                XCTAssertTrue(client.realtimeV2.channels.isEmpty)
                await vm.stopSessionRealtime()
                XCTAssertEqual(server.acceptedConnectionCount, 0)
            }
        }
    }

    func testNormalAndUnitLoadedDetailConnectAndStopTheRealSDKChannel() async throws {
        for mode in [AppTestMode.normal, .unit] {
            try await harness(mode: mode) { server, client, vm in
                await vm.startSessionRealtime()
                XCTAssertEqual(server.acceptedConnectionCount, 1)
                XCTAssertTrue(server.frames.contains { $0[3] as? String == "phx_join" })
                XCTAssertEqual(client.realtimeV2.channels.count, 1)
                await vm.stopSessionRealtime()
                XCTAssertTrue(client.realtimeV2.channels.isEmpty)
            }
        }
    }

    private func harness(
        mode: AppTestMode,
        action: (LoopbackRealtimeServer, SupabaseClient, SessionDetailViewModel) async throws -> Void
    ) async throws {
        let server = try LoopbackRealtimeServer(mode: .accept)
        defer { server.stop() }
        let deadline = ProcessInfo.processInfo.systemUptime + 4
        while server.port == nil {
            guard ProcessInfo.processInfo.systemUptime < deadline else { throw RealtimeFixtureError.timeout }
            try await Task.sleep(for: .milliseconds(5))
        }
        let port = try XCTUnwrap(server.port)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RealtimeDenyHTTP.self]
        let client = SupabaseClient(supabaseURL: URL(string: "http://127.0.0.1:\(port)")!, supabaseKey: "synthetic-detail-key",
            options: .init(auth: .init(storage: RealtimeDiscardStorage(), autoRefreshToken: false),
                           global: .init(session: URLSession(configuration: configuration), logger: nil),
                           realtime: .init(timeoutInterval: 0.4, maxRetryAttempts: 1,
                                           disconnectOnEmptyChannelsAfter: 0, handleAppLifecycle: false)))
        let session = PickupSession(id: UUID(), hostId: UUID(), sport: .basketball,
            startsAt: Date().addingTimeInterval(3600), endsAt: Date().addingTimeInterval(7200),
            capacity: 8, playerCount: 2, skillLevel: .any, status: .open)
        let vm = SessionDetailViewModel(sessionId: session.id, userId: nil, client: client, testMode: mode)
        vm.session = .loaded(session)
        do { try await action(server, client, vm) }
        catch {
            await vm.stopSessionRealtime()
            await client.realtimeV2.disconnect()
            throw error
        }
        await vm.stopSessionRealtime()
        await client.realtimeV2.disconnect()
    }
}

private enum RealtimeFixtureError: Error { case timeout }

private struct RealtimeDiscardStorage: AuthLocalStorage {
    func store(key: String, value: Data) throws {}
    func retrieve(key: String) throws -> Data? { nil }
    func remove(key: String) throws {}
}

private final class RealtimeDenyHTTP: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        XCTFail("Realtime fixture unexpectedly attempted HTTP")
        client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
    }
    override func stopLoading() {}
}

/// Only synthetic Phoenix v2 text frames, on a numeric IPv4 loopback endpoint.
@MainActor
private final class LoopbackRealtimeServer {
    enum Mode { case accept, reject, silent }
    var mode: Mode
    private(set) var port: UInt16?
    private(set) var frames: [[Any]] = []
    private(set) var acceptedConnectionCount = 0
    private let listener: NWListener
    private var connections: [NWConnection] = []
    private var stopped = false
    private let queue = DispatchQueue(label: "pickup.synthetic.realtime")

    init(mode: Mode) throws {
        self.mode = mode
        let parameters = NWParameters(tls: nil, tcp: NWProtocolTCP.Options())
        parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: .any)
        let websocket = NWProtocolWebSocket.Options()
        websocket.autoReplyPing = true
        parameters.defaultProtocolStack.applicationProtocols.insert(websocket, at: 0)
        listener = try NWListener(using: parameters)
        listener.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                guard let self, !self.stopped else { return }
                if case .ready = state { self.port = self.listener.port?.rawValue }
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            Task { @MainActor in
                guard let self, !self.stopped else { connection.cancel(); return }
                self.acceptedConnectionCount += 1
                self.connections.append(connection)
                connection.start(queue: self.queue)
                self.receive(connection)
            }
        }
        listener.start(queue: queue)
    }

    func stop() {
        stopped = true
        listener.cancel()
        connections.forEach { $0.cancel() }
        listener.newConnectionHandler = nil
        listener.stateUpdateHandler = nil
    }

    func closeLastChannel() {
        guard let frame = frames.last(where: { $0[3] as? String == "phx_join" }), let connection = connections.last else { return }
        send([frame[0], NSNull(), frame[2], "phx_close", [:]], on: connection)
    }

    private func receive(_ connection: NWConnection) {
        connection.receiveMessage { [weak self] data, context, _, error in
            Task { @MainActor in
                guard let self, !self.stopped else { return }
                let opcode = (context?.protocolMetadata(definition: NWProtocolWebSocket.definition) as? NWProtocolWebSocket.Metadata)?.opcode
                if opcode == .close { return }
                if let data, let metadata = context?.protocolMetadata(definition: NWProtocolWebSocket.definition) as? NWProtocolWebSocket.Metadata,
                   metadata.opcode == .text {
                    do {
                        let frame = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [Any])
                        guard frame.count == 5 else { XCTFail("Expected Phoenix v2 frame"); return }
                        self.frames.append(frame)
                        if frame[3] as? String == "phx_join", self.mode != .silent {
                            self.reply(frame, on: connection, accepted: self.mode == .accept)
                        } else if frame[3] as? String == "phx_leave" {
                            self.send([frame[0], NSNull(), frame[2], "phx_close", [:]], on: connection)
                        }
                    } catch { XCTFail("Invalid synthetic websocket frame") }
                }
                if error == nil { self.receive(connection) }
            }
        }
    }

    private func reply(_ frame: [Any], on connection: NWConnection, accepted: Bool) {
        let response: [String: Any] = accepted ? ["postgres_changes": []] : ["reason": "private synthetic rejection"]
        send([frame[0], frame[1], frame[2], "phx_reply", ["status": accepted ? "ok" : "error", "response": response]], on: connection)
    }

    private func send(_ frame: [Any], on connection: NWConnection) {
        do {
            let data = try JSONSerialization.data(withJSONObject: frame)
            let context = NWConnection.ContentContext(identifier: "synthetic-text",
                metadata: [NWProtocolWebSocket.Metadata(opcode: .text)])
            connection.send(content: data, contentContext: context, isComplete: true, completion: .idempotent)
        } catch { XCTFail("Could not encode synthetic websocket frame") }
    }
}
