import Foundation
import Supabase

struct CreateSessionInput {
    let sport: SportType
    /// When `sport` is `.other`, the user-visible sport name (trimmed, max 40 chars in repository).
    let customSportName: String?
    let venueId: UUID?
    let customLocation: CustomLocationSelection?
    let startsAt: Date
    let durationMinutes: Int
    let capacity: Int
    let skillLevel: SkillLevel
    let notes: String?
    let recurrenceRule: RecurrenceRule?
}

struct UpdateSessionInput {
    let sport: SportType
    let customSportName: String?
    let venueId: UUID?
    let customLocation: CustomLocationSelection?
    let startsAt: Date
    let durationMinutes: Int
    let capacity: Int
    let skillLevel: SkillLevel
    let notes: String?
}

protocol SessionRepositoryProtocol {
    func fetchUpcoming(
        sport: SportType?,
        timeWindow: DiscoverTimeWindow,
        skillLevel: SkillLevel?
    ) async throws -> [PickupSession]
    /// Sessions the user has joined or is waitlisted for, starting from now (open or full only).
    func fetchMySessions(userId: UUID) async throws -> [PickupSession]
    func fetchMyPastSessions(limit: Int, offset: Int) async throws -> [PickupSession]
    func fetchSession(id: UUID) async throws -> PickupSession
    func fetchVenues() async throws -> [Venue]
    func fetchParticipantStatus(sessionId: UUID, userId: UUID) async throws -> ParticipantStatus?
    func fetchParticipantStatuses(userId: UUID, sessionIds: [UUID]) async throws -> [UUID: ParticipantStatus]
    func createSession(_ input: CreateSessionInput) async throws -> PickupSession
    func updateSession(id: UUID, input: UpdateSessionInput) async throws -> PickupSession
    func cancelSession(id: UUID) async throws
    func joinSession(id: UUID) async throws -> ParticipantStatus
    func leaveSession(id: UUID) async throws
}

final class SessionRepository: SessionRepositoryProtocol {
    private let client: SupabaseClient
    /// `*` keeps sessions compatible before `custom_sport_name` exists; embeds stay explicit.
    private let sessionSelect = """
        *, \
        venue:venues(id, name, lat, lng, campus_zone, is_official), \
        host:profiles!sessions_host_id_fkey(id, display_name, username)
        """

    init(client: SupabaseClient = SupabaseManager.shared) {
        self.client = client
    }

    private static let maxCustomSportNameLength = 40

    /// Stored name when `sport == .other`; otherwise `nil` (clears any previous custom name on update).
    private static func normalizedCustomSportName(sport: SportType, raw: String?) -> String? {
        guard sport == .other else { return nil }
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return nil }
        if trimmed.count <= maxCustomSportNameLength { return trimmed }
        return String(trimmed.prefix(maxCustomSportNameLength))
    }

    func fetchUpcoming(
        sport: SportType?,
        timeWindow: DiscoverTimeWindow = .next48h,
        skillLevel: SkillLevel? = nil
    ) async throws -> [PickupSession] {
        let now = Date.now
        let range = timeWindow.queryRange(relativeTo: now)
        let statuses = [SessionStatus.open.rawValue, SessionStatus.full.rawValue]

        var query = client
            .from("sessions")
            .select(sessionSelect)
            .in("status", values: statuses)
            .gte("starts_at", value: range.lowerBound.ISO8601Format())
            .lte("starts_at", value: range.upperBound.ISO8601Format())

        if let sport {
            query = query.eq("sport", value: sport.rawValue)
        }

        if let skillLevel, skillLevel != .any {
            query = query.eq("skill_level", value: skillLevel.rawValue)
        }

        let rows: [PickupSession] = try await query
            .order("starts_at", ascending: true)
            .limit(AppPagination.discoverSessions)
            .execute()
            .value

        return rows.filter { $0.startsAt > now }
    }

    /// Removes sessions hosted by users the caller has blocked (client-side filter after one block-list fetch).
    static func filterBlockedHosts(
        _ sessions: [PickupSession],
        blockedHostIds: Set<UUID>
    ) -> [PickupSession] {
        guard !blockedHostIds.isEmpty else { return sessions }
        return sessions.filter { !blockedHostIds.contains($0.hostId) }
    }

    func fetchMySessions(userId: UUID) async throws -> [PickupSession] {
        struct ParticipantSessionId: Decodable {
            let sessionId: UUID
            enum CodingKeys: String, CodingKey {
                case sessionId = "session_id"
            }
        }

        let participantRows: [ParticipantSessionId] = try await client
            .from("session_participants")
            .select("session_id")
            .eq("user_id", value: userId.uuidString)
            .in("status", values: [ParticipantStatus.joined.rawValue, ParticipantStatus.waitlist.rawValue])
            .limit(AppPagination.myGamesParticipantIdCap)
            .execute()
            .value

        let ids = participantRows.map(\.sessionId)
        guard !ids.isEmpty else { return [] }

        let now = Date.now
        let statuses = [SessionStatus.open.rawValue, SessionStatus.full.rawValue]
        let idStrings = ids.map(\.uuidString)

        let sessions: [PickupSession] = try await client
            .from("sessions")
            .select(sessionSelect)
            .in("id", values: idStrings)
            .in("status", values: statuses)
            .gt("ends_at", value: now.ISO8601Format())
            .order("starts_at", ascending: true)
            .limit(AppPagination.myGamesUpcoming)
            .execute()
            .value

        return sessions.filter { $0.endsAt > now }
    }

    /// Ended games you hosted or joined (RLS limits rows to your sessions).
    func fetchMyPastSessions(limit: Int, offset: Int) async throws -> [PickupSession] {
        let pageSize = min(max(limit, 1), AppPagination.myGamesPastPage)
        let safeOffset = max(offset, 0)
        let now = Date.now

        return try await client
            .from("sessions")
            .select(sessionSelect)
            .lte("ends_at", value: now.ISO8601Format())
            .order("starts_at", ascending: false)
            .range(from: safeOffset, to: safeOffset + pageSize - 1)
            .execute()
            .value
    }

    func fetchSession(id: UUID) async throws -> PickupSession {
        try await client
            .from("sessions")
            .select(sessionSelect)
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value
    }

    func fetchVenues() async throws -> [Venue] {
        try await client
            .from("venues")
            .select()
            .order("name", ascending: true)
            .execute()
            .value
    }

    func fetchParticipantStatus(sessionId: UUID, userId: UUID) async throws -> ParticipantStatus? {
        let rows: [SessionParticipantRow] = try await client
            .from("session_participants")
            .select("status")
            .eq("session_id", value: sessionId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .limit(1)
            .execute()
            .value

        return rows.first?.status
    }

    func fetchParticipantStatuses(userId: UUID, sessionIds: [UUID]) async throws -> [UUID: ParticipantStatus] {
        guard !sessionIds.isEmpty else { return [:] }

        let rows: [SessionParticipantStatusRow] = try await client
            .from("session_participants")
            .select("session_id, status")
            .eq("user_id", value: userId.uuidString)
            .in("session_id", values: sessionIds.map(\.uuidString))
            .in("status", values: [
                ParticipantStatus.joined.rawValue,
                ParticipantStatus.waitlist.rawValue,
            ])
            .execute()
            .value

        return Dictionary(uniqueKeysWithValues: rows.map { ($0.sessionId, $0.status) })
    }

    func createSession(_ input: CreateSessionInput) async throws -> PickupSession {
        let userId = try await client.auth.session.user.id
        let endsAt = Calendar.current.date(
            byAdding: .minute,
            value: input.durationMinutes,
            to: input.startsAt
        ) ?? input.startsAt

        let resolved = try Self.resolveLocation(venueId: input.venueId, custom: input.customLocation)

        let normalizedOther = Self.normalizedCustomSportName(sport: input.sport, raw: input.customSportName)
        if input.sport == .other, normalizedOther == nil {
            throw SessionRepositoryError.customSportNameRequired
        }

        let notesToStore = OtherSportNotes.composedNotes(
            sport: input.sport,
            customOtherName: normalizedOther,
            userNotes: input.notes
        )

        let recurrenceRuleJSON: String?
        if let rule = input.recurrenceRule {
            recurrenceRuleJSON = try rule.jsonString
        } else {
            recurrenceRuleJSON = nil
        }

        let payload = SessionInsert(
            hostId: userId,
            sport: input.sport,
            venueId: resolved.venueId,
            customLocation: resolved.customLocation,
            customLat: resolved.customLat,
            customLng: resolved.customLng,
            startsAt: input.startsAt,
            endsAt: endsAt,
            capacity: input.capacity,
            playerCount: 1,
            skillLevel: input.skillLevel,
            notes: notesToStore,
            recurrenceRule: recurrenceRuleJSON
        )

        let created: PickupSession = try await client
            .from("sessions")
            .insert(payload)
            .select(sessionSelect)
            .single()
            .execute()
            .value

        let hostRow = HostParticipantInsert(
            sessionId: created.id,
            userId: userId,
            role: .host,
            status: .joined
        )
        try await client.from("session_participants").insert(hostRow).execute()

        if let withWeather = try? await attachWeatherSnapshotIfNeeded(to: created) {
            return withWeather
        }
        return created
    }

    func updateSession(id: UUID, input: UpdateSessionInput) async throws -> PickupSession {
        let endsAt = Calendar.current.date(
            byAdding: .minute,
            value: input.durationMinutes,
            to: input.startsAt
        ) ?? input.startsAt

        let resolved = try Self.resolveLocation(venueId: input.venueId, custom: input.customLocation)

        let normalizedOther = Self.normalizedCustomSportName(sport: input.sport, raw: input.customSportName)
        if input.sport == .other, normalizedOther == nil {
            throw SessionRepositoryError.customSportNameRequired
        }

        let notesToStore = OtherSportNotes.composedNotes(
            sport: input.sport,
            customOtherName: normalizedOther,
            userNotes: input.notes
        )

        let payload = SessionRowPatch(
            sport: input.sport,
            venueId: resolved.venueId,
            customLocation: resolved.customLocation,
            customLat: resolved.customLat,
            customLng: resolved.customLng,
            startsAt: input.startsAt,
            endsAt: endsAt,
            capacity: input.capacity,
            skillLevel: input.skillLevel,
            notes: notesToStore
        )

        return try await client
            .from("sessions")
            .update(payload)
            .eq("id", value: id.uuidString)
            .select(sessionSelect)
            .single()
            .execute()
            .value
    }

    func cancelSession(id: UUID) async throws {
        struct StatusPatch: Encodable {
            let status: SessionStatus
        }
        try await client
            .from("sessions")
            .update(StatusPatch(status: .cancelled))
            .eq("id", value: id.uuidString)
            .execute()
    }

    func joinSession(id: UUID) async throws -> ParticipantStatus {
        let status: ParticipantStatus = try await client
            .rpc("join_session", params: JoinSessionParams(pSessionId: id))
            .execute()
            .value
        return status
    }

    func leaveSession(id: UUID) async throws {
        struct LeaveParams: Encodable {
            let pSessionId: UUID
            enum CodingKeys: String, CodingKey {
                case pSessionId = "p_session_id"
            }
        }
        try await client.rpc("leave_session", params: LeaveParams(pSessionId: id)).execute()
    }

    /// Fetches forecast via Edge Function and patches `weather_snapshot` for outdoor sessions.
    private func attachWeatherSnapshotIfNeeded(to session: PickupSession) async throws -> PickupSession {
        guard session.isOutdoorForWeather, let coordinates = session.weatherCoordinates else {
            return session
        }

        struct FetchWeatherBody: Encodable {
            let lat: Double
            let lng: Double
            let startsAt: String

            enum CodingKeys: String, CodingKey {
                case lat, lng
                case startsAt = "starts_at"
            }
        }

        let snapshot: WeatherSnapshot = try await client.functions.invoke(
            "fetch-weather",
            options: FunctionInvokeOptions(
                body: FetchWeatherBody(
                    lat: coordinates.lat,
                    lng: coordinates.lng,
                    startsAt: session.startsAt.ISO8601Format()
                )
            )
        )

        struct WeatherPatch: Encodable {
            let weatherSnapshot: WeatherSnapshot

            enum CodingKeys: String, CodingKey {
                case weatherSnapshot = "weather_snapshot"
            }
        }

        return try await client
            .from("sessions")
            .update(WeatherPatch(weatherSnapshot: snapshot))
            .eq("id", value: session.id.uuidString)
            .select(sessionSelect)
            .single()
            .execute()
            .value
    }
}

enum SessionRepositoryError: LocalizedError {
    case locationRequired
    case customLocationPinRequired
    case scheduleTooFarAhead
    case scheduleInPast
    case capacityBelowSignups
    case customSportNameRequired

    var errorDescription: String? {
        switch self {
        case .locationRequired:
            return "Choose a venue or pick a custom location on the map."
        case .customLocationPinRequired:
            return "Search on the map and choose where you're playing."
        case .scheduleTooFarAhead:
            return "Sessions can only be scheduled up to 48 hours ahead."
        case .scheduleInPast:
            return "Start time must be in the future."
        case .capacityBelowSignups:
            return "Capacity can’t be lower than the number of players already signed up."
        case .customSportNameRequired:
            return "Enter a name for your sport (e.g. pickleball, badminton)."
        }
    }
}

private struct ResolvedSessionLocation {
    let venueId: UUID?
    let customLocation: String?
    let customLat: Double?
    let customLng: Double?
}

private extension SessionRepository {
    static func resolveLocation(
        venueId: UUID?,
        custom: CustomLocationSelection?
    ) throws -> ResolvedSessionLocation {
        if let venueId {
            return ResolvedSessionLocation(
                venueId: venueId,
                customLocation: nil,
                customLat: nil,
                customLng: nil
            )
        }

        guard let custom else {
            throw SessionRepositoryError.locationRequired
        }

        let label = custom.label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !label.isEmpty else {
            throw SessionRepositoryError.customLocationPinRequired
        }

        return ResolvedSessionLocation(
            venueId: nil,
            customLocation: label,
            customLat: custom.latitude,
            customLng: custom.longitude
        )
    }
}

private struct SessionRowPatch: Encodable {
    let sport: SportType
    let venueId: UUID?
    let customLocation: String?
    let customLat: Double?
    let customLng: Double?
    let startsAt: Date
    let endsAt: Date
    let capacity: Int
    let skillLevel: SkillLevel
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case sport
        case venueId = "venue_id"
        case customLocation = "custom_location"
        case customLat = "custom_lat"
        case customLng = "custom_lng"
        case startsAt = "starts_at"
        case endsAt = "ends_at"
        case capacity
        case skillLevel = "skill_level"
        case notes
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
