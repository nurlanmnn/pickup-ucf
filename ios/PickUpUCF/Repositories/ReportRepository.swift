import Foundation
import Supabase

private struct SessionReportInsert: Encodable {
    let reporterId: UUID
    let sessionId: UUID
    let reason: String

    enum CodingKeys: String, CodingKey {
        case reporterId = "reporter_id"
        case sessionId = "session_id"
        case reason
    }
}

enum ReportRepositoryError: LocalizedError {
    case reasonTooShort
    case reasonTooLong
    case alreadyReported

    var errorDescription: String? {
        switch self {
        case .reasonTooShort:
            return "Please describe the issue in at least 10 characters."
        case .reasonTooLong:
            return "Keep your report under 500 characters."
        case .alreadyReported:
            return "You already reported this session."
        }
    }
}

final class ReportRepository {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseManager.shared) {
        self.client = client
    }

    func submitReport(sessionId: UUID, reason: String) async throws {
        let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 10 else {
            throw ReportRepositoryError.reasonTooShort
        }
        guard trimmed.count <= 500 else {
            throw ReportRepositoryError.reasonTooLong
        }

        let reporterId = try await client.auth.session.user.id
        let payload = SessionReportInsert(
            reporterId: reporterId,
            sessionId: sessionId,
            reason: trimmed
        )

        do {
            try await client
                .from("session_reports")
                .insert(payload)
                .execute()
        } catch {
            let text = String(describing: error).lowercased()
            if text.contains("duplicate") || text.contains("unique") {
                throw ReportRepositoryError.alreadyReported
            }
            throw error
        }
    }
}
