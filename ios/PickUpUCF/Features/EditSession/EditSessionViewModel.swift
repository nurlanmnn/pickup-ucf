import Foundation
import UIKit

enum EditSessionScrollAnchor: String, Hashable {
    case sport
    case schedule
    case location
}

@Observable
final class EditSessionViewModel {
    static let customVenuePickerTag = "__custom__"

    let sessionId: UUID
    let minimumCapacity: Int

    var sport: SportType = .basketball
    var customSportName = ""
    var venuePickerOptionId: String = EditSessionViewModel.customVenuePickerTag
    var customLocationSelection: CustomLocationSelection?
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
    var isDirty = false
    var showFieldErrors = false

    private var pendingVenueId: UUID?
    private var pendingCustomLocationLabel: String?
    private var suppressDirtyTracking = false

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
        guard !venues.isEmpty else { return false }
        return venuePickerOptionId == Self.customVenuePickerTag
    }

    var canSubmit: Bool {
        guard !isLoading else { return false }
        guard (15 ... 300).contains(durationMinutes), (2 ... 50).contains(capacity) else { return false }
        guard capacity >= minimumCapacity else { return false }
        if sport == .other, customSportName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return false
        }
        let hasLocation = selectedVenueId != nil || customLocationSelection != nil
        guard hasLocation else { return false }
        return validateSchedule() == nil
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

    func markDirty() {
        guard !suppressDirtyTracking else { return }
        isDirty = true
    }

    func revealFieldErrors() {
        showFieldErrors = true
    }

    func firstInvalidScrollAnchor() -> EditSessionScrollAnchor? {
        guard showFieldErrors else { return nil }
        if sportNameError != nil { return .sport }
        if scheduleError != nil { return .schedule }
        if locationError != nil { return .location }
        return nil
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
    func hydrateCustomLocationIfNeeded() async {
        guard customLocationSelection == nil,
              let label = pendingCustomLocationLabel else { return }
        if let hydrated = await LocationGeocoding.selectionForExistingSession(
            label: label,
            latitude: nil,
            longitude: nil
        ) {
            customLocationSelection = hydrated
            pendingCustomLocationLabel = nil
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
                venuePickerOptionId = Self.customVenuePickerTag
            }
        } catch {
            errorMessage = AppErrorMapper.message(for: error)
        }
    }

    @MainActor
    func save() async -> PickupSession? {
        errorMessage = nil
        revealFieldErrors()
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
        if selectedVenueId == nil && customLocationSelection == nil {
            errorMessage = SessionRepositoryError.customLocationPinRequired.localizedDescription
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
            customLocation: customLocationSelection,
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
        suppressDirtyTracking = true
        defer {
            suppressDirtyTracking = false
            isDirty = false
        }

        sport = session.sport
        let parsed = OtherSportNotes.parse(session.notes)
        let fromDb = session.customSportName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        customSportName = fromDb.isEmpty ? (parsed.embeddedName ?? "") : fromDb
        notes = parsed.userNotes ?? ""
        if let vid = session.venueId {
            pendingVenueId = vid
            venuePickerOptionId = Self.customVenuePickerTag
        } else {
            pendingVenueId = nil
            venuePickerOptionId = Self.customVenuePickerTag
        }
        if session.venueId == nil {
            let label = session.customLocation ?? ""
            if let lat = session.customLat, let lng = session.customLng {
                customLocationSelection = CustomLocationSelection(
                    label: label.isEmpty ? "Selected location" : label,
                    latitude: lat,
                    longitude: lng
                )
                pendingCustomLocationLabel = nil
            } else if !label.isEmpty {
                customLocationSelection = nil
                pendingCustomLocationLabel = label
            } else {
                customLocationSelection = nil
                pendingCustomLocationLabel = nil
            }
        } else {
            customLocationSelection = nil
            pendingCustomLocationLabel = nil
        }
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
