import Foundation
import UIKit

@Observable
final class CreateSessionViewModel {
    static let customVenuePickerTag = "__custom__"

    var sport: SportType = .basketball {
        didSet { markDirtyIfNeeded() }
    }
    /// When `sport` is `.other`, the name is embedded in `notes` (and in `custom_sport_name` when that column exists).
    var customSportName = "" {
        didSet { markDirtyIfNeeded() }
    }
    var venuePickerOptionId: String = "__custom__" {
        didSet { markDirtyIfNeeded() }
    }
    var customLocationSelection: CustomLocationSelection? {
        didSet { markDirtyIfNeeded() }
    }
    var startsAt = Calendar.current.date(byAdding: .hour, value: 2, to: .now) ?? .now {
        didSet { markDirtyIfNeeded() }
    }

    var durationMinutes = 90 {
        didSet { markDirtyIfNeeded() }
    }
    var durationText = "90" {
        didSet { markDirtyIfNeeded() }
    }
    var capacity = 10 {
        didSet { markDirtyIfNeeded() }
    }
    var capacityText = "10" {
        didSet { markDirtyIfNeeded() }
    }

    var skillLevel: SkillLevel = .intermediate {
        didSet { markDirtyIfNeeded() }
    }
    var notes = "" {
        didSet { markDirtyIfNeeded() }
    }
    var repeatWeekly = false {
        didSet { markDirtyIfNeeded() }
    }
    var recurrenceWeekCount = 4 {
        didSet { markDirtyIfNeeded() }
    }
    var venues: [Venue] = []
    var errorMessage: String?
    var isLoading = false
    var didCreate = false
    var isDirty = false
    var showFieldErrors = false

    private(set) var pendingVenueId: UUID?
    private var pendingCustomLocationLabel: String?
    private var suppressDirtyTracking = false
    private let repository: SessionRepositoryProtocol

    init(repository: SessionRepositoryProtocol = SessionRepository()) {
        self.repository = repository
    }

    var selectedVenueId: UUID? {
        venuePickerOptionId == Self.customVenuePickerTag ? nil : UUID(uuidString: venuePickerOptionId)
    }

    var showsCustomLocationField: Bool {
        guard !venues.isEmpty || pendingVenueId == nil else { return false }
        return venuePickerOptionId == Self.customVenuePickerTag
    }

    var canSubmit: Bool {
        guard !isLoading else { return false }
        guard (15 ... 300).contains(durationMinutes), (2 ... 50).contains(capacity) else { return false }
        if sport == .other, customSportName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return false
        }
        let hasLocation = selectedVenueId != nil || customLocationSelection != nil
        guard hasLocation else { return false }
        return validateSchedule() == nil
    }

    func canAdvance(from step: CreateSessionStep) -> Bool {
        switch step {
        case .sportAndTime:
            return sportAndTimeIsValid
        case .location:
            return locationIsValid
        case .details:
            return canSubmit
        }
    }

    var sportNameError: String? {
        guard showFieldErrors else { return nil }
        if sport == .other, customSportName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Enter a sport name (e.g. pickleball)."
        }
        return nil
    }

    var scheduleError: String? {
        guard showFieldErrors else { return nil }
        return validateSchedule()
    }

    var locationError: String? {
        guard showFieldErrors else { return nil }
        if showsCustomLocationField {
            if customLocationSelection == nil {
                return "Search on the map and choose where you're playing."
            }
        } else if selectedVenueId == nil {
            return "Choose a venue."
        }
        return nil
    }

    var sessionSummaryLine: String {
        let sportLabel = sport == .other && !customSportName.isEmpty
            ? customSportName
            : sport.displayName
        let locationLabel: String
        if let venueId = selectedVenueId,
           let venue = venues.first(where: { $0.id == venueId }) {
            locationLabel = venue.name
        } else if let custom = customLocationSelection {
            locationLabel = custom.label
        } else {
            locationLabel = "Location TBD"
        }
        let timeLabel = SessionDateFormatter.cardLabel(for: startsAt)
        return "\(sportLabel) · \(locationLabel) · \(timeLabel)"
    }

    func markDirty() {
        guard !suppressDirtyTracking else { return }
        isDirty = true
    }

    func revealFieldErrors() {
        showFieldErrors = true
    }

    func firstInvalidStep() -> CreateSessionStep? {
        if !sportAndTimeIsValid { return .sportAndTime }
        if !locationIsValid { return .location }
        if !canSubmit { return .details }
        return nil
    }

    func firstInvalidScrollAnchor(for step: CreateSessionStep) -> CreateSessionScrollAnchor? {
        guard showFieldErrors else { return nil }
        switch step {
        case .sportAndTime:
            if sportNameError != nil { return .sport }
            if scheduleError != nil { return .schedule }
            return nil
        case .location:
            if locationError != nil { return .location }
            return nil
        case .details:
            return nil
        }
    }

    /// Call when the duration field loses focus or from keyboard Done.
    func commitDurationFromText() {
        let trimmed = durationText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            durationText = "\(durationMinutes)"
            return
        }
        let digits = trimmed.filter(\.isNumber)
        guard let raw = Int(digits), !digits.isEmpty else {
            durationText = "\(durationMinutes)"
            return
        }
        durationMinutes = min(300, max(15, raw))
        durationText = "\(durationMinutes)"
    }

    func commitCapacityFromText() {
        let trimmed = capacityText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            capacityText = "\(capacity)"
            return
        }
        let digits = trimmed.filter(\.isNumber)
        guard let raw = Int(digits), !digits.isEmpty else {
            capacityText = "\(capacity)"
            return
        }
        capacity = min(50, max(2, raw))
        capacityText = "\(capacity)"
    }

    func applyPrefill(_ prefill: CreateSessionPrefill) {
        suppressDirtyTracking = true
        defer {
            suppressDirtyTracking = false
            isDirty = false
        }

        sport = prefill.sport
        customSportName = prefill.customSportName ?? ""
        skillLevel = prefill.skillLevel
        capacity = prefill.capacity
        capacityText = "\(prefill.capacity)"
        durationMinutes = prefill.durationMinutes
        durationText = "\(prefill.durationMinutes)"
        notes = prefill.notes
        startsAt = prefill.startsAt
        repeatWeekly = false

        if let venueId = prefill.venueId {
            pendingVenueId = venueId
            venuePickerOptionId = Self.customVenuePickerTag
            customLocationSelection = nil
            pendingCustomLocationLabel = nil
        } else {
            pendingVenueId = nil
            venuePickerOptionId = Self.customVenuePickerTag
            customLocationSelection = prefill.customLocationSelection
            pendingCustomLocationLabel = prefill.customLocationLabel
        }
    }

    func applyLastUsedDefaults(_ defaults: CreateSessionDefaults = CreateSessionDefaultsStorage.load()) {
        suppressDirtyTracking = true
        defer {
            suppressDirtyTracking = false
            isDirty = false
        }

        if let sport = defaults.sport {
            self.sport = sport
        }
        if let venueId = defaults.venueId {
            pendingVenueId = venueId
            venuePickerOptionId = Self.customVenuePickerTag
            customLocationSelection = nil
            pendingCustomLocationLabel = nil
        }
    }

    @MainActor
    func hydrateCustomLocationIfNeeded() async {
        guard customLocationSelection == nil,
              let label = pendingCustomLocationLabel else { return }
        if let hydrated = await LocationGeocoding.selectionForExistingSession(
            label: label,
            latitude: nil,
            longitude: nil
        ) {
            suppressDirtyTracking = true
            customLocationSelection = hydrated
            pendingCustomLocationLabel = nil
            suppressDirtyTracking = false
        }
    }

    @MainActor
    func loadVenues() async {
        do {
            venues = try await repository.fetchVenues()
            suppressDirtyTracking = true
            defer { suppressDirtyTracking = false }

            if let pendingVenueId,
               venues.contains(where: { $0.id == pendingVenueId }) {
                venuePickerOptionId = pendingVenueId.uuidString
            }
            self.pendingVenueId = nil

            if venuePickerOptionId == Self.customVenuePickerTag,
               customLocationSelection == nil,
               pendingCustomLocationLabel == nil,
               let firstVenue = venues.first {
                venuePickerOptionId = firstVenue.id.uuidString
            }

            if venuePickerOptionId != Self.customVenuePickerTag,
               UUID(uuidString: venuePickerOptionId) == nil
                   || !venues.contains(where: { $0.id.uuidString == venuePickerOptionId }) {
                venuePickerOptionId = venues.first.map { $0.id.uuidString } ?? Self.customVenuePickerTag
            }
        } catch {
            errorMessage = AppErrorMapper.message(for: error)
        }
    }

    /// Human-readable list of missing/invalid fields for Create session.
    func validationIssues() -> [String] {
        var issues: [String] = []

        if sport == .other, customSportName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("Enter a sport name (e.g. pickleball).")
        }

        if showsCustomLocationField {
            if customLocationSelection == nil {
                issues.append("Search on the map and choose where you're playing.")
            }
        } else if selectedVenueId == nil {
            issues.append("Choose a venue.")
        }

        let durationIssue = numericFieldIssue(
            label: "Duration",
            text: durationText,
            range: 15 ... 300,
            unit: "minutes"
        )
        if let durationIssue { issues.append(durationIssue) }

        let capacityIssue = numericFieldIssue(
            label: "Capacity",
            text: capacityText,
            range: 2 ... 50,
            unit: "players"
        )
        if let capacityIssue { issues.append(capacityIssue) }

        if let scheduleError = validateSchedule() {
            issues.append(scheduleError)
        }

        return issues
    }

    @MainActor
    func create() async -> PickupSession? {
        errorMessage = nil
        revealFieldErrors()
        commitDurationFromText()
        commitCapacityFromText()

        let issues = validationIssues()
        if !issues.isEmpty {
            errorMessage = issues.count == 1
                ? issues[0]
                : "Please complete the following:\n" + issues.map { "• \($0)" }.joined(separator: "\n")
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return nil
        }

        if selectedVenueId == nil && customLocationSelection == nil {
            errorMessage = SessionRepositoryError.customLocationPinRequired.localizedDescription
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return nil
        }
        if sport == .other, customSportName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = SessionRepositoryError.customSportNameRequired.localizedDescription
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return nil
        }

        isLoading = true
        defer { isLoading = false }

        let recurrenceRule = repeatWeekly ? RecurrenceRule.weekly(count: recurrenceWeekCount) : nil

        let input = CreateSessionInput(
            sport: sport,
            customSportName: sport == .other ? customSportName : nil,
            venueId: selectedVenueId,
            customLocation: customLocationSelection,
            startsAt: startsAt,
            durationMinutes: durationMinutes,
            capacity: capacity,
            skillLevel: skillLevel,
            notes: notes,
            recurrenceRule: recurrenceRule
        )

        do {
            let session = try await repository.createSession(input)
            didCreate = true
            CreateSessionDefaultsStorage.save(sport: session.sport, venueId: session.venueId)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            return session
        } catch {
            errorMessage = AppErrorMapper.message(for: error)
            return nil
        }
    }

    // MARK: - Quick time presets

    static func inTwoHours(from now: Date = .now, calendar: Calendar = .current) -> Date {
        clampedStartsAt(from: calendar.date(byAdding: .hour, value: 2, to: now) ?? now, now: now, calendar: calendar)
    }

    static func tonightAtSixPM(from now: Date = .now, calendar: Calendar = .current) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = 18
        components.minute = 0
        components.second = 0
        let candidate = calendar.date(from: components) ?? now
        if candidate <= now {
            return clampedStartsAt(
                from: calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate,
                now: now,
                calendar: calendar
            )
        }
        return clampedStartsAt(from: candidate, now: now, calendar: calendar)
    }

    static func tomorrowAtNineAM(from now: Date = .now, calendar: Calendar = .current) -> Date {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        var components = calendar.dateComponents([.year, .month, .day], from: tomorrow)
        components.hour = 9
        components.minute = 0
        components.second = 0
        let candidate = calendar.date(from: components) ?? tomorrow
        return clampedStartsAt(from: candidate, now: now, calendar: calendar)
    }

    static func clampedStartsAt(from date: Date, now: Date, calendar: Calendar) -> Date {
        let minimum = now.addingTimeInterval(60)
        let maximum = calendar.date(byAdding: .hour, value: 48, to: now) ?? now
        return min(max(date, minimum), maximum)
    }

    private var sportAndTimeIsValid: Bool {
        if sport == .other, customSportName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return false
        }
        guard (15 ... 300).contains(durationMinutes) else { return false }
        return validateSchedule() == nil
    }

    private var locationIsValid: Bool {
        selectedVenueId != nil || customLocationSelection != nil
    }

    private func markDirtyIfNeeded() {
        markDirty()
    }

    private func validateSchedule() -> String? {
        if startsAt <= .now {
            return SessionRepositoryError.scheduleInPast.localizedDescription
        }
        let windowEnd = Calendar.current.date(byAdding: .hour, value: 48, to: .now) ?? .now
        if startsAt > windowEnd {
            return SessionRepositoryError.scheduleTooFarAhead.localizedDescription
        }
        return nil
    }

    private func numericFieldIssue(
        label: String,
        text: String,
        range: ClosedRange<Int>,
        unit: String
    ) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let digits = trimmed.filter(\.isNumber)
        guard let raw = Int(digits), !digits.isEmpty else {
            return "\(label) must be a number (\(range.lowerBound)–\(range.upperBound) \(unit))."
        }
        guard range.contains(raw) else {
            return "\(label) must be between \(range.lowerBound) and \(range.upperBound) \(unit)."
        }
        return nil
    }
}
