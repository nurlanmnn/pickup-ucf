import Foundation
import Supabase

struct SubmitAttendanceParams: Encodable {
    let pSessionId: UUID
    let pAttendedUserIds: [UUID]

    enum CodingKeys: String, CodingKey {
        case pSessionId = "p_session_id"
        case pAttendedUserIds = "p_attended_user_ids"
    }
}

final class AttendanceRepository {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseManager.shared) {
        self.client = client
    }

    func fetchJoinedParticipants(sessionId: UUID) async throws -> [SessionParticipant] {
        struct Row: Decodable {
            let profile: SessionParticipant

            enum CodingKeys: String, CodingKey {
                case profile = "profiles"
            }
        }

        let rows: [Row] = try await client
            .from("session_participants")
            .select("user_id, profiles!session_participants_user_id_fkey(id, display_name, username)")
            .eq("session_id", value: sessionId.uuidString)
            .eq("status", value: ParticipantStatus.joined.rawValue)
            .execute()
            .value

        return rows.map(\.profile)
    }

    func submitAttendance(sessionId: UUID, attendedUserIds: [UUID]) async throws {
        try await client.rpc(
            "submit_session_attendance",
            params: SubmitAttendanceParams(
                pSessionId: sessionId,
                pAttendedUserIds: attendedUserIds
            )
        ).execute()
    }
}
