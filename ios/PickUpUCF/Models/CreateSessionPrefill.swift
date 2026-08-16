import Foundation

struct CreateSessionPrefill: Equatable {
    let sport: SportType
    let customSportName: String?
    let venueId: UUID?
    let customLocationSelection: CustomLocationSelection?
    let customLocationLabel: String?
    let skillLevel: SkillLevel
    let capacity: Int
    let durationMinutes: Int
    let notes: String
    let startsAt: Date

    /// Sport + optional venue prefill for Discover empty-state host nudges and last-used defaults.
    init(
        sport: SportType,
        venueId: UUID? = nil,
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        self.sport = sport
        customSportName = nil
        self.venueId = venueId
        customLocationSelection = nil
        customLocationLabel = nil
        skillLevel = .intermediate
        capacity = 10
        durationMinutes = 90
        notes = ""
        startsAt = calendar.date(byAdding: .hour, value: 2, to: now) ?? now
    }

    init(from session: PickupSession, now: Date = Date(), calendar: Calendar = .current) {
        sport = session.sport
        if session.sport == .other {
            let fromDb = session.customSportName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let embedded = OtherSportNotes.parse(session.notes).embeddedName ?? ""
            customSportName = !fromDb.isEmpty ? fromDb : embedded
        } else {
            customSportName = nil
        }

        venueId = session.venueId
        if session.venueId == nil,
           let lat = session.customLat,
           let lng = session.customLng {
            let label = session.customLocation?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            customLocationSelection = CustomLocationSelection(
                label: label.isEmpty ? "Selected location" : label,
                latitude: lat,
                longitude: lng
            )
            customLocationLabel = nil
        } else if session.venueId == nil,
                  let label = session.customLocation?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !label.isEmpty {
            customLocationSelection = nil
            customLocationLabel = label
        } else {
            customLocationSelection = nil
            customLocationLabel = nil
        }

        skillLevel = session.skillLevel
        capacity = session.capacity
        let mins = calendar.dateComponents([.minute], from: session.startsAt, to: session.endsAt).minute ?? 90
        durationMinutes = min(300, max(15, mins))
        notes = session.notesForDisplay ?? ""
        startsAt = Self.clampedStartsAt(from: session.startsAt, now: now, calendar: calendar)
    }

    static func clampedStartsAt(
        from sourceStartsAt: Date,
        now: Date,
        calendar: Calendar = .current
    ) -> Date {
        let proposed = calendar.date(byAdding: .day, value: 7, to: sourceStartsAt) ?? sourceStartsAt
        let minimum = now.addingTimeInterval(60)
        let maximum = calendar.date(byAdding: .hour, value: 48, to: now) ?? now
        return min(max(proposed, minimum), maximum)
    }
}
