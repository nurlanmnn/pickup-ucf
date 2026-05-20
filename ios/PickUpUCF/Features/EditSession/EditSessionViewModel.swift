import Foundation
import UIKit

@Observable
final class EditSessionViewModel {
    static let customVenuePickerTag = "__custom__"

    let sessionId: UUID
    let minimumCapacity: Int

    var sport: SportType = .basketball
    var customSportName = ""
    var venuePickerOptionId: String = EditSessionViewModel.customVenuePickerTag
    var customLocation = ""
    var startsAt = Date()

    var durationMinutes = 90
    var durationText = "90"
    var capacity = 10
    var capacityText = "10"

    var skillLevel: SkillLevel = .intermediate
    var notes = ""
    var venues: [Venue] = []
    var errorMessage: String?
    var isLoading = false

    private let repository: SessionRepositoryProtocol

    init(session: PickupSession, repository: SessionRepositoryProtocol = SessionRepository()) {
        sessionId = session.id
        minimumCapacity = session.playerCount
        self.repository = repository
        apply(session)
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
        guard capacity >= minimumCapacity else { return false }
        if sport == .other, customSportName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return false
        }
        let hasLocation = selectedVenueId != nil
            || !customLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard hasLocation else { return false }
        return validateSchedule() == nil
    }

    func commitDurationFromText() {
        if let raw = Int(durationText.filter(\.isNumber)) {
            durationMinutes = min(300, max(15, raw))
        }
        durationText = "\(durationMinutes)"
    }

    func commitCapacityFromText() {
        if let raw = Int(capacityText.filter(\.isNumber)) {
            capacity = min(50, max(minimumCapacity, raw))
        }
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
    func save() async -> PickupSession? {
        errorMessage = nil
        commitDurationFromText()
        commitCapacityFromText()

        if capacity < minimumCapacity {
            errorMessage = SessionRepositoryError.capacityBelowSignups.localizedDescription
            return nil
        }

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

        let input = UpdateSessionInput(
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
            let updated = try await repository.updateSession(id: sessionId, input: input)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            return updated
        } catch {
            errorMessage = AppErrorMapper.message(for: error)
            return nil
        }
    }

    private func apply(_ session: PickupSession) {
        sport = session.sport
        let parsed = OtherSportNotes.parse(session.notes)
        let fromDb = session.customSportName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        customSportName = fromDb.isEmpty ? (parsed.embeddedName ?? "") : fromDb
        notes = parsed.userNotes ?? ""
        if let vid = session.venueId {
            venuePickerOptionId = vid.uuidString
        } else {
            venuePickerOptionId = Self.customVenuePickerTag
        }
        customLocation = session.customLocation ?? ""
        startsAt = session.startsAt
        let mins = Calendar.current.dateComponents([.minute], from: session.startsAt, to: session.endsAt).minute ?? 90
        durationMinutes = min(300, max(15, mins))
        durationText = "\(durationMinutes)"
        capacity = session.capacity
        capacityText = "\(capacity)"
        skillLevel = session.skillLevel
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
