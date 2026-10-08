import Foundation
import Observation
import Supabase

struct ProfileAttendanceRecord: Decodable, Identifiable {
    let sessionId: UUID
    let markedAt: Date
    let session: ProfileHistorySession?
    var id: UUID { sessionId }

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case markedAt = "marked_at"
        case session
    }
}

struct ProfileHistorySession: Decodable {
    let sport: SportType
    let customSportName: String?
    let startsAt: Date
    let customLocation: String?
    let venue: HistoryVenue?

    struct HistoryVenue: Decodable { let name: String }

    enum CodingKeys: String, CodingKey {
        case sport, venue
        case customSportName = "custom_sport_name"
        case startsAt = "starts_at"
        case customLocation = "custom_location"
    }

    var title: String {
        sport == .other ? (customSportName ?? sport.displayName) : sport.displayName
    }
    var location: String { venue?.name ?? customLocation ?? "Campus location" }
}

protocol ProfileHistoryRepositoryProtocol {
    func fetchAttendance(limit: Int, offset: Int) async throws -> [ProfileAttendanceRecord]
}

struct ProfileHistoryRepository: ProfileHistoryRepositoryProtocol {
    let client: SupabaseClient
    init(client: SupabaseClient = SupabaseManager.shared) { self.client = client }

    func fetchAttendance(limit: Int, offset: Int) async throws -> [ProfileAttendanceRecord] {
        let userId = try await client.auth.session.user.id
        let size = min(max(limit, 1), 20)
        let start = max(offset, 0)
        return try await client.from("attendance")
            .select("session_id, marked_at, session:sessions(sport, custom_sport_name, starts_at, custom_location, venue:venues(name))")
            .eq("user_id", value: userId.uuidString)
            .order("marked_at", ascending: false)
            .order("session_id", ascending: false)
            .range(from: start, to: start + size - 1)
            .execute().value
    }
}

@MainActor @Observable
final class ProfileHistoryViewModel {
    private(set) var records: [ProfileAttendanceRecord] = []
    private(set) var isLoading = false
    private(set) var hasMore = true
    private(set) var hasLoaded = false
    private(set) var errorMessage: String?
    private(set) var retryResetsHistory = true
    private var offset = 0
    private let repository: ProfileHistoryRepositoryProtocol

    init(repository: ProfileHistoryRepositoryProtocol = ProfileHistoryRepository()) {
        self.repository = repository
    }

    func load(reset: Bool) async {
        guard !isLoading, reset || hasMore else { return }
        isLoading = true
        retryResetsHistory = reset
        errorMessage = nil
        defer { isLoading = false }
        let pageOffset = reset ? 0 : offset
        do {
            let page = try await repository.fetchAttendance(limit: 20, offset: pageOffset)
            try Task.checkCancellation()
            if reset { records = [] }
            let existing = Set(records.map(\.id))
            records.append(contentsOf: page.filter { !existing.contains($0.id) })
            offset = pageOffset + page.count
            hasMore = page.count == 20
            hasLoaded = true
        } catch is CancellationError {
            // A dismissed screen must not publish a new error.
        } catch {
            errorMessage = AppErrorMapper.message(for: error)
        }
    }
}
