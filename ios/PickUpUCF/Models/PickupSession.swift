import Foundation

enum SessionStatus: String, Codable {
    case open
    case full
    case cancelled
    case completed
}

enum ParticipantStatus: String, Codable {
    case joined
    case waitlist
    case left
}

enum ParticipantRole: String, Codable {
    case host
    case player
}

struct ProfileSummary: Codable, Equatable {
    let id: UUID
    var displayName: String
    var username: String?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case username
    }

    var handle: String {
        if let username, !username.isEmpty { return "@\(username)" }
        return displayName
    }
}

struct PickupSession: Codable, Identifiable, Equatable {
    let id: UUID
    let hostId: UUID
    let sport: SportType
    /// When `sport` is `.other`, the name the host entered (e.g. "Pickleball").
    var customSportName: String?
    var venueId: UUID?
    var customLocation: String?
    var customLat: Double?
    var customLng: Double?
    let startsAt: Date
    let endsAt: Date
    let capacity: Int
    var playerCount: Int
    let skillLevel: SkillLevel
    var notes: String?
    var status: SessionStatus
    var venue: Venue?
    var host: ProfileSummary?

    enum CodingKeys: String, CodingKey {
        case id
        case hostId = "host_id"
        case sport
        case customSportName = "custom_sport_name"
        case venueId = "venue_id"
        case customLocation = "custom_location"
        case customLat = "custom_lat"
        case customLng = "custom_lng"
        case startsAt = "starts_at"
        case endsAt = "ends_at"
        case capacity
        case playerCount = "player_count"
        case skillLevel = "skill_level"
        case notes, status, venue, host
    }

    var locationName: String {
        if let venue { return venue.name }
        if let customLocation, !customLocation.isEmpty { return customLocation }
        return "Campus location"
    }

    var spotsLeft: Int {
        max(0, capacity - playerCount)
    }

    var isFull: Bool {
        status == .full || playerCount >= capacity
    }

    /// Title for cards and headers. Uses `custom_sport_name` when present, else embedded tag in `notes`.
    var sportDisplayName: String {
        if sport == .other {
            let db = customSportName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !db.isEmpty { return db }
            if let embedded = OtherSportNotes.parse(notes).embeddedName, !embedded.isEmpty {
                return embedded
            }
            return sport.displayName
        }
        return sport.displayName
    }

    /// Notes without the embedded "Other" sport tag (for forms and detail UI).
    var notesForDisplay: String? {
        let parsed = OtherSportNotes.parse(notes)
        if parsed.embeddedName != nil {
            if let user = parsed.userNotes, !user.isEmpty { return user }
            return nil
        }
        guard let n = notes?.trimmingCharacters(in: .whitespacesAndNewlines), !n.isEmpty else { return nil }
        return n
    }
}

struct SessionInsert: Encodable {
    let hostId: UUID
    let sport: SportType
    let venueId: UUID?
    let customLocation: String?
    let customLat: Double?
    let customLng: Double?
    let startsAt: Date
    let endsAt: Date
    let capacity: Int
    let playerCount: Int
    let skillLevel: SkillLevel
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case hostId = "host_id"
        case sport
        case venueId = "venue_id"
        case customLocation = "custom_location"
        case customLat = "custom_lat"
        case customLng = "custom_lng"
        case startsAt = "starts_at"
        case endsAt = "ends_at"
        case capacity
        case playerCount = "player_count"
        case skillLevel = "skill_level"
        case notes
    }
}

struct HostParticipantInsert: Encodable {
    let sessionId: UUID
    let userId: UUID
    let role: ParticipantRole
    let status: ParticipantStatus

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case userId = "user_id"
        case role, status
    }
}

struct JoinSessionParams: Encodable {
    let pSessionId: UUID

    enum CodingKeys: String, CodingKey {
        case pSessionId = "p_session_id"
    }
}

struct SessionParticipantRow: Codable {
    let status: ParticipantStatus
}
