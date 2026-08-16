import XCTest
@testable import PickUpUCF

final class EmptyStateCTATests: XCTestCase {
    func testHostNudgeCTATitleUsesSelectedSport() {
        XCTAssertEqual(
            DiscoverViewModel.hostNudgeCTATitle(filterMode: .single(.basketball)),
            "Host basketball game"
        )
    }

    func testHostNudgeCTATitleUsesGenericCopyForAllSports() {
        XCTAssertEqual(
            DiscoverViewModel.hostNudgeCTATitle(filterMode: .single(nil)),
            "Host a game"
        )
    }

    func testHostNudgeCTATitleUsesGenericCopyForMySports() {
        XCTAssertEqual(
            DiscoverViewModel.hostNudgeCTATitle(filterMode: .mySports),
            "Host a game"
        )
    }

    func testHostNudgePrefillUsesSelectedSport() {
        let prefill = DiscoverViewModel.hostNudgePrefill(
            filterMode: .single(.soccer),
            preferredSports: []
        )

        XCTAssertEqual(prefill.sport, .soccer)
    }

    func testHostNudgePrefillUsesFirstPreferredSportForMySports() {
        let prefill = DiscoverViewModel.hostNudgePrefill(
            filterMode: .mySports,
            preferredSports: [.volleyball, .tennis]
        )

        XCTAssertEqual(prefill.sport, .volleyball)
    }

    func testHostNudgePrefillDefaultsToBasketballForAllSports() {
        let prefill = DiscoverViewModel.hostNudgePrefill(
            filterMode: .single(nil),
            preferredSports: []
        )

        XCTAssertEqual(prefill.sport, .basketball)
    }

    func testHostNudgePrefillUsesSelectedVenueAndTwoHourStart() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let selectedVenueId = UUID()
        let otherVenueId = UUID()

        let prefill = DiscoverViewModel.hostNudgePrefill(
            filterMode: .single(.tennis),
            preferredSports: [],
            selectedVenueId: selectedVenueId,
            officialVenues: [
                Venue(id: otherVenueId, name: "IM Fields", lat: 28.6, lng: -81.2, campusZone: nil, isOfficial: true),
                Venue(id: selectedVenueId, name: "Memory Mall", lat: 28.6, lng: -81.2, campusZone: nil, isOfficial: true),
            ],
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(prefill.sport, .tennis)
        XCTAssertEqual(prefill.venueId, selectedVenueId)
        XCTAssertEqual(prefill.startsAt, calendar.date(byAdding: .hour, value: 2, to: now))
    }

    func testHostNudgePrefillFallsBackToFirstOfficialVenue() {
        let firstVenueId = UUID()

        let prefill = DiscoverViewModel.hostNudgePrefill(
            filterMode: .single(.soccer),
            preferredSports: [],
            selectedVenueId: nil,
            officialVenues: [
                Venue(id: firstVenueId, name: "IM Fields", lat: 28.6, lng: -81.2, campusZone: nil, isOfficial: true),
            ]
        )

        XCTAssertEqual(prefill.venueId, firstVenueId)
    }

    func testEmptyStateSymbolUsesSelectedSport() {
        XCTAssertEqual(
            DiscoverViewModel.emptyStateSymbol(filterMode: .single(.volleyball)),
            SportType.volleyball.systemImage
        )
    }

    func testEmptyStateSymbolUsesCourtIconWithoutSportFilter() {
        XCTAssertEqual(
            DiscoverViewModel.emptyStateSymbol(filterMode: .single(nil)),
            "sportscourt"
        )
        XCTAssertEqual(
            DiscoverViewModel.emptyStateSymbol(filterMode: .mySports),
            "sportscourt"
        )
    }

    func testQuickCreatePresetsHiddenWhenSportAlreadySelected() {
        let presets = DiscoverViewModel.quickCreatePresets(
            filterMode: .single(.basketball),
            preferredSports: [.soccer],
            selectedVenueId: nil,
            officialVenues: []
        )

        XCTAssertTrue(presets.isEmpty)
    }

    func testQuickCreatePresetsUseCampusDefaultsAndSelectedVenue() {
        let venueId = UUID()
        let presets = DiscoverViewModel.quickCreatePresets(
            filterMode: .single(nil),
            preferredSports: [],
            selectedVenueId: venueId,
            officialVenues: []
        )

        XCTAssertEqual(presets.map(\.sport), [.basketball, .soccer, .volleyball, .flagFootball])
        XCTAssertTrue(presets.allSatisfy { $0.venueId == venueId })
    }

    func testQuickCreatePresetsUsePreferredSportsForMySports() {
        let firstVenueId = UUID()
        let presets = DiscoverViewModel.quickCreatePresets(
            filterMode: .mySports,
            preferredSports: [.pickleball, .tennis, .other],
            selectedVenueId: nil,
            officialVenues: [
                Venue(id: firstVenueId, name: "IM Fields", lat: 28.6, lng: -81.2, campusZone: nil, isOfficial: true),
            ]
        )

        XCTAssertEqual(presets.map(\.sport), [.pickleball, .tennis])
        XCTAssertEqual(presets.first?.venueId, firstVenueId)
    }
}
