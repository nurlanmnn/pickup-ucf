import Foundation
import UIKit

@Observable
final class CreateSessionViewModel {
    static let customVenuePickerTag = "__custom__"

    var sport: SportType = .basketball
    /// When `sport` is `.other`, the name is embedded in `notes` (and in `custom_sport_name` when that column exists).
    var customSportName = ""
    var venuePickerOptionId: String = "__custom__"
    var customLocation = ""
    var startsAt = Calendar.current.date(byAdding: .hour, value: 2, to: .now) ?? .now

    /// Defaults used until the user types or uses the stepper; text fields start empty with placeholders.
    var durationMinutes = 90
    var durationText = ""
    var capacity = 10
    var capacityText = ""

    var skillLevel: SkillLevel = .intermediate
    var notes = ""
    var venues: [Venue] = []
    var errorMessage: String?
    var isLoading = false
    var didCreate = false

    private let repository: SessionRepositoryProtocol

    init(repository: SessionRepositoryProtocol = SessionRepository()) {
        self.repository = repository
    }

    var selectedVenueId: UUID? {
        venuePickerOptionId == Self.customVenuePickerTag ? nil : UUID(uuidString: venuePickerOptionId)
    }

    var showsCustomLocationField: Bool {
        venuePickerOptionId == Self.customVenuePickerTag
    }

    var canSubmit: Bool {
        guard !isLoading else { return false }
        guard (15 ... 300).contains(durationMinutes), (2 ... 50).contains(capacity) else { return false }
        if sport == .other, customSportName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return false
        }
        let hasLocation = selectedVenueId != nil
            || !customLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard hasLocation else { return false }
        return validateSchedule() == nil
    }

    /// Call when the duration field loses focus or from keyboard Done.
    func commitDurationFromText() {
        let trimmed = durationText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            durationText = ""
            return
        }
        let digits = trimmed.filter(\.isNumber)
        guard let raw = Int(digits), !digits.isEmpty else {
            durationText = ""
            return
        }
        durationMinutes = min(300, max(15, raw))
        durationText = "\(durationMinutes)"
    }

    func commitCapacityFromText() {
        let trimmed = capacityText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            capacityText = ""
            return
        }
        let digits = trimmed.filter(\.isNumber)
        guard let raw = Int(digits), !digits.isEmpty else {
            capacityText = ""
            return
        }
        capacity = min(50, max(2, raw))
        capacityText = "\(capacity)"
    }

    @MainActor
    func loadVenues() async {
        do {
            venues = try await repository.fetchVenues()
            if venuePickerOptionId != Self.customVenuePickerTag,
               UUID(uuidString: venuePickerOptionId) == nil
                   || !venues.contains(where: { $0.id.uuidString == venuePickerOptionId }) {
                venuePickerOptionId = Self.customVenuePickerTag
            }
        } catch {
            errorMessage = AppErrorMapper.message(for: error)
        }
    }

    @MainActor
    func create() async -> PickupSession? {
        errorMessage = nil
        commitDurationFromText()
        commitCapacityFromText()

        if let scheduleError = validateSchedule() {
            errorMessage = scheduleError
            return nil
        }
        if selectedVenueId == nil && customLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = SessionRepositoryError.locationRequired.localizedDescription
            return nil
        }
        if sport == .other, customSportName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = SessionRepositoryError.customSportNameRequired.localizedDescription
            return nil
        }

        isLoading = true
        defer { isLoading = false }

        let input = CreateSessionInput(
            sport: sport,
            customSportName: sport == .other ? customSportName : nil,
            venueId: selectedVenueId,
            customLocation: customLocation,
            startsAt: startsAt,
            durationMinutes: durationMinutes,
            capacity: capacity,
            skillLevel: skillLevel,
            notes: notes
        )

        do {
            let session = try await repository.createSession(input)
            didCreate = true
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            return session
        } catch {
            errorMessage = AppErrorMapper.message(for: error)
            return nil
        }
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
}
