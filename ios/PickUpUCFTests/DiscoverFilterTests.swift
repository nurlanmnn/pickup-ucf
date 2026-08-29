import XCTest
@testable import PickUpUCF

final class DiscoverFilterTests: XCTestCase {
    private var calendar: Calendar { DiscoverTimeWindow.campusCalendar }

    func testTodayExcludesTomorrow() {
        let now = makeDate(year: 2026, month: 7, day: 18, hour: 14)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!

        XCTAssertTrue(DiscoverTimeWindow.today.contains(now, relativeTo: now, calendar: calendar))
        XCTAssertFalse(DiscoverTimeWindow.today.contains(tomorrow, relativeTo: now, calendar: calendar))
    }

    func testWeekendIncludesSaturday() {
        let wednesday = makeDate(year: 2026, month: 7, day: 15, hour: 10)
        let saturday = makeDate(year: 2026, month: 7, day: 18, hour: 12)

        XCTAssertTrue(
            DiscoverTimeWindow.thisWeekend.contains(saturday, relativeTo: wednesday, calendar: calendar)
        )
    }

    func testNext48hWindowMatchesExistingBehavior() {
        let now = makeDate(year: 2026, month: 7, day: 18, hour: 14)
        let withinWindow = calendar.date(byAdding: .hour, value: 24, to: now)!
        let outsideWindow = calendar.date(byAdding: .hour, value: 49, to: now)!

        XCTAssertTrue(DiscoverTimeWindow.next48h.contains(withinWindow, relativeTo: now, calendar: calendar))
        XCTAssertFalse(DiscoverTimeWindow.next48h.contains(outsideWindow, relativeTo: now, calendar: calendar))
    }

    func testSessionListCapHintShowsWhenLoadedCountHitsCap() {
        XCTAssertTrue(
            DiscoverViewModel.shouldShowSessionListCapHint(
                loadedCount: AppPagination.discoverSessions,
                visibleCount: AppPagination.discoverSessions,
                searchText: ""
            )
        )
    }

    func testSessionListCapHintHidesWhenUnderCap() {
        XCTAssertFalse(
            DiscoverViewModel.shouldShowSessionListCapHint(
                loadedCount: AppPagination.discoverSessions - 1,
                visibleCount: AppPagination.discoverSessions - 1,
                searchText: ""
            )
        )
    }

    func testSessionListCapHintHidesWhenSearchIsActive() {
        XCTAssertFalse(
            DiscoverViewModel.shouldShowSessionListCapHint(
                loadedCount: AppPagination.discoverSessions,
                visibleCount: 3,
                searchText: "cornhole"
            )
        )
    }

    func testSessionListCapHintTreatsWhitespaceOnlySearchAsEmpty() {
        XCTAssertTrue(
            DiscoverViewModel.shouldShowSessionListCapHint(
                loadedCount: AppPagination.discoverSessions,
                visibleCount: AppPagination.discoverSessions,
                searchText: "   "
            )
        )
    }

    func testSessionListCapHintHidesWhenVisibleListIsEmpty() {
        XCTAssertFalse(
            DiscoverViewModel.shouldShowSessionListCapHint(
                loadedCount: AppPagination.discoverSessions,
                visibleCount: 0,
                searchText: ""
            )
        )
    }

    func testSessionListCapHintCopyUsesTheCap() {
        XCTAssertEqual(
            DiscoverViewModel.sessionListCapHint,
            "Showing the next \(AppPagination.discoverSessions). Narrow sport, venue, or time to see more."
        )
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int) -> Date {
        let components = DateComponents(
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour
        )
        return calendar.date(from: components)!
    }
}
