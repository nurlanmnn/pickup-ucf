import XCTest
@testable import PickUpUCF

final class CreateSessionStepValidationTests: XCTestCase {
    func testCanAdvanceSportAndTimeRequiresValidSportAndSchedule() {
        let vm = CreateSessionViewModel()
        vm.sport = .basketball
        vm.startsAt = Date().addingTimeInterval(7200)
        vm.durationMinutes = 90

        XCTAssertTrue(vm.canAdvance(from: .sportAndTime))

        vm.sport = .other
        vm.customSportName = ""
        XCTAssertFalse(vm.canAdvance(from: .sportAndTime))

        vm.customSportName = "Pickleball"
        XCTAssertTrue(vm.canAdvance(from: .sportAndTime))

        vm.startsAt = Date().addingTimeInterval(-60)
        XCTAssertFalse(vm.canAdvance(from: .sportAndTime))
    }

    func testCanAdvanceLocationRequiresVenueOrCustomPin() {
        let vm = CreateSessionViewModel()
        vm.venuePickerOptionId = CreateSessionViewModel.customVenuePickerTag
        vm.customLocationSelection = nil

        XCTAssertFalse(vm.canAdvance(from: .location))

        vm.customLocationSelection = CustomLocationSelection(
            label: "Memory Mall",
            latitude: 28.6,
            longitude: -81.2
        )
        XCTAssertTrue(vm.canAdvance(from: .location))

        vm.customLocationSelection = nil
        vm.venuePickerOptionId = UUID().uuidString
        XCTAssertTrue(vm.canAdvance(from: .location))
    }

    func testCanAdvanceDetailsMatchesCanSubmit() {
        let vm = CreateSessionViewModel()
        vm.sport = .soccer
        vm.venuePickerOptionId = UUID().uuidString
        vm.startsAt = Date().addingTimeInterval(7200)
        vm.durationMinutes = 90
        vm.capacity = 10

        XCTAssertEqual(vm.canAdvance(from: .details), vm.canSubmit)
    }

    func testQuickTimePresetsClampToFortyEightHourWindow() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        let twoHours = CreateSessionViewModel.inTwoHours(from: now, calendar: calendar)
        XCTAssertGreaterThan(twoHours, now)

        let tomorrowNine = CreateSessionViewModel.tomorrowAtNineAM(from: now, calendar: calendar)
        let maxAllowed = calendar.date(byAdding: .hour, value: 48, to: now)!
        XCTAssertLessThanOrEqual(tomorrowNine, maxAllowed)
    }

    func testFieldErrorsHiddenUntilRevealed() {
        let vm = CreateSessionViewModel()
        vm.sport = .other
        vm.customSportName = ""

        XCTAssertNil(vm.sportNameError)

        vm.revealFieldErrors()
        XCTAssertNotNil(vm.sportNameError)
    }

    func testApplyPrefillDoesNotMarkDirty() {
        let vm = CreateSessionViewModel()
        let prefill = CreateSessionPrefill(sport: .tennis)

        vm.applyPrefill(prefill)

        XCTAssertFalse(vm.isDirty)
        XCTAssertEqual(vm.sport, .tennis)
    }

    func testApplyLastUsedDefaultsSetsSportAndPendingVenueWithoutDirty() {
        let vm = CreateSessionViewModel()
        let venueId = UUID()

        vm.applyLastUsedDefaults(CreateSessionDefaults(sport: .soccer, venueId: venueId))

        XCTAssertFalse(vm.isDirty)
        XCTAssertEqual(vm.sport, .soccer)
        XCTAssertEqual(vm.pendingVenueId, venueId)
    }

    func testMarkDirtyAfterUserEdit() {
        let vm = CreateSessionViewModel()
        vm.applyPrefill(CreateSessionPrefill(sport: .tennis))

        vm.markDirty()

        XCTAssertTrue(vm.isDirty)
    }

    func testFirstInvalidStepReturnsSportAndTimeWhenScheduleInvalid() {
        let vm = CreateSessionViewModel()
        vm.revealFieldErrors()
        vm.startsAt = Date().addingTimeInterval(-60)

        XCTAssertEqual(vm.firstInvalidStep(), .sportAndTime)
        XCTAssertEqual(vm.firstInvalidScrollAnchor(for: .sportAndTime), .schedule)
    }

    func testFirstInvalidStepReturnsLocationWhenVenueMissing() {
        let vm = CreateSessionViewModel()
        vm.sport = .basketball
        vm.startsAt = Date().addingTimeInterval(7200)
        vm.venuePickerOptionId = CreateSessionViewModel.customVenuePickerTag
        vm.customLocationSelection = nil
        vm.revealFieldErrors()

        XCTAssertEqual(vm.firstInvalidStep(), .location)
        XCTAssertEqual(vm.firstInvalidScrollAnchor(for: .location), .location)
    }

    func testFirstInvalidScrollAnchorNilBeforeErrorsRevealed() {
        let vm = CreateSessionViewModel()
        vm.sport = .other
        vm.customSportName = ""

        XCTAssertNil(vm.firstInvalidScrollAnchor(for: .sportAndTime))
    }
}
