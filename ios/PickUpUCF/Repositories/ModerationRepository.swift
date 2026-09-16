import Foundation
import Supabase

private struct ModerationQueueParams: Encodable {
    let limit: Int
    enum CodingKeys: String, CodingKey { case limit = "p_limit" }
}

private struct ModerateReportParams: Encodable {
    let reportId: UUID
    let action: ModerationActionType
    let reason: String
    let suspensionHours: Int?

    enum CodingKeys: String, CodingKey {
        case reportId = "p_report_id"
        case action = "p_action"
        case reason = "p_reason"
        case suspensionHours = "p_suspension_hours"
    }
}

private struct AcknowledgeModerationNoticeParams: Encodable {
    let noticeId: UUID
    enum CodingKeys: String, CodingKey { case noticeId = "p_notice_id" }
}

protocol ModerationRepositoryProtocol {
    func isCurrentUserModerator() async throws -> Bool
    func fetchNotices() async throws -> [ModerationNotice]
    func acknowledgeNotice(id: UUID) async throws
    func fetchQueue(limit: Int) async throws -> [ModerationQueueItem]
    func act(on reportId: UUID, action: ModerationActionType, reason: String, suspensionHours: Int?) async throws
}

final class ModerationRepository: ModerationRepositoryProtocol {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseManager.shared) {
        self.client = client
    }

    func isCurrentUserModerator() async throws -> Bool {
        try await client.rpc("is_current_user_moderator").execute().value
    }

    func fetchNotices() async throws -> [ModerationNotice] {
        try await client.rpc("list_my_moderation_notices").execute().value
    }

    func acknowledgeNotice(id: UUID) async throws {
        try await client.rpc(
            "acknowledge_moderation_notice",
            params: AcknowledgeModerationNoticeParams(noticeId: id)
        ).execute()
    }

    func fetchQueue(limit: Int = 50) async throws -> [ModerationQueueItem] {
        try await client
            .rpc("list_moderation_reports", params: ModerationQueueParams(limit: limit))
            .execute()
            .value
    }

    func act(
        on reportId: UUID,
        action: ModerationActionType,
        reason: String,
        suspensionHours: Int?
    ) async throws {
        let safeReason = try UserContentPolicy.validate(reason, field: .reportContext)
        guard safeReason.count >= 10 else { throw ReportRepositoryError.contextTooShort }
        try await client.rpc(
            "moderate_report",
            params: ModerateReportParams(
                reportId: reportId,
                action: action,
                reason: safeReason,
                suspensionHours: action == .suspendUser ? suspensionHours : nil
            )
        ).execute()
    }
}
