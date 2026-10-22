import XCTest
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
