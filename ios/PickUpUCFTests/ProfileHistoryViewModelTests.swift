import XCTest
@testable import PickUpUCF

@MainActor
final class ProfileHistoryViewModelTests: XCTestCase {
    func testLoadMoreAppendsAndUsesRecordOffset() async {
        let repository = HistoryRepositoryStub()
        repository.pages = [(0..<20).map { _ in record() }, [record()]]
        let vm = ProfileHistoryViewModel(repository: repository)
        await vm.load(reset: true)
        XCTAssertTrue(vm.hasMore)
        await vm.load(reset: false)
        XCTAssertEqual(vm.records.count, 21)
        XCTAssertEqual(repository.offsets, [0, 20])
        XCTAssertFalse(vm.hasMore)
    }

    func testFailedLoadMorePreservesHistoryAndRetryOffset() async {
        let repository = HistoryRepositoryStub()
        repository.pages = [(0..<20).map { _ in record() }]
        let vm = ProfileHistoryViewModel(repository: repository)
        await vm.load(reset: true)
        repository.shouldFail = true
        await vm.load(reset: false)
        XCTAssertEqual(vm.records.count, 20)
        XCTAssertNotNil(vm.errorMessage)
        repository.shouldFail = false
        repository.pages = [[]]
        await vm.load(reset: false)
        XCTAssertEqual(repository.offsets, [0, 20, 20])
        XCTAssertNil(vm.errorMessage)
    }

    func testRefreshReplacesHistoryAndEmptyPageEndsPagination() async {
        let repository = HistoryRepositoryStub()
        repository.pages = [[record()], []]
        let vm = ProfileHistoryViewModel(repository: repository)
        await vm.load(reset: true)
        await vm.load(reset: true)
        XCTAssertTrue(vm.records.isEmpty)
        XCTAssertFalse(vm.hasMore)
        XCTAssertEqual(repository.offsets, [0, 0])
    }

    func testFailedRefreshRetriesFromBeginningAndKeepsOldHistory() async {
        let repository = HistoryRepositoryStub()
        repository.pages = [[record()]]
        let vm = ProfileHistoryViewModel(repository: repository)
        await vm.load(reset: true)
        repository.shouldFail = true
        await vm.load(reset: true)
        XCTAssertEqual(vm.records.count, 1)
        XCTAssertTrue(vm.retryResetsHistory)
        repository.shouldFail = false
        repository.pages = [[]]
        await vm.load(reset: vm.retryResetsHistory)
        XCTAssertTrue(vm.records.isEmpty)
        XCTAssertEqual(repository.offsets, [0, 0, 0])
    }

    func testOverlappingPagesDoNotRepeatGames() async {
        let repository = HistoryRepositoryStub()
        let first = (0..<20).map { _ in record() }
        repository.pages = [first, [first[19], record()]]
        let vm = ProfileHistoryViewModel(repository: repository)
        await vm.load(reset: true)
        await vm.load(reset: false)
        XCTAssertEqual(vm.records.count, 21)
    }

    private func record() -> ProfileAttendanceRecord {
        ProfileAttendanceRecord(sessionId: UUID(), markedAt: .now, session: nil)
    }
}

private final class HistoryRepositoryStub: ProfileHistoryRepositoryProtocol {
    var pages: [[ProfileAttendanceRecord]] = []
    var offsets: [Int] = []
    var shouldFail = false

    func fetchAttendance(limit: Int, offset: Int) async throws -> [ProfileAttendanceRecord] {
        offsets.append(offset)
        if shouldFail { throw URLError(.notConnectedToInternet) }
        return pages.removeFirst()
    }
}
