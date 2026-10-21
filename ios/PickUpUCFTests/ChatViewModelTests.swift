import XCTest
import Supabase
import SwiftUI
@testable import PickUpUCF

@MainActor
final class ChatViewModelTests: XCTestCase {
    private let sessionId = UUID()
    private let userId = UUID()
    private let cursor = ChatMessageCursor(timestamp: "2026-10-14T12:00:00.123456Z", id: UUID())

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
        XCTAssertEqual(updatedScroll.contentOffset.y - originalOffset, insertedHeight, accuracy: 80,
                       "Prepending history should keep the same message in view")
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
    var saved: SessionMessage!

    func fetchMessages(sessionId: UUID, before: ChatMessageCursor?, limit: Int) async throws -> ChatMessagePage {
        cursors.append(before)
        if shouldFail { throw URLError(.notConnectedToInternet) }
        await duringFetch?()
        return pages.removeFirst()
    }

    func sendMessage(sessionId: UUID, body: String) async throws -> SessionMessage {
        duringSend?()
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
