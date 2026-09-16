import Foundation
import Supabase

private struct SubmitReportParams: Encodable {
    let targetType: ReportTargetType
    let targetId: UUID
    let category: ReportCategory
    let context: String?

    enum CodingKeys: String, CodingKey {
        case targetType = "p_target_type"
        case targetId = "p_target_id"
        case category = "p_category"
        case context = "p_context"
    }
}

enum ReportRepositoryError: LocalizedError {
    case contextTooShort
    case contextTooLong
    case alreadyReported
    case rateLimited
    case invalidTarget

    var errorDescription: String? {
        switch self {
        case .contextTooShort:
            "Add at least 10 characters of context or leave it blank."
        case .contextTooLong:
            "Keep your report context under 500 characters."
        case .alreadyReported:
            "You already have an open report for this item."
        case .rateLimited:
            "You’ve submitted several reports. Please wait before sending another."
        case .invalidTarget:
            "This item can’t be reported or is no longer available."
        }
    }
}

protocol ReportRepositoryProtocol {
    func submitReport(target: ReportTarget, category: ReportCategory, context: String?) async throws
}

final class ReportRepository: ReportRepositoryProtocol {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseManager.shared) {
        self.client = client
    }

    func submitReport(target: ReportTarget, category: ReportCategory, context: String?) async throws {
        let safeContext = try UserContentPolicy.validateOptional(context, field: .reportContext)
        if let safeContext, safeContext.count < 10 {
            throw ReportRepositoryError.contextTooShort
        }

        do {
            try await client.rpc(
                "submit_moderation_report",
                params: SubmitReportParams(
                    targetType: target.type,
                    targetId: target.id,
                    category: category,
                    context: safeContext
                )
            ).execute()
        } catch {
            let text = String(describing: error).lowercased()
            if text.contains("report_already_submitted") { throw ReportRepositoryError.alreadyReported }
            if text.contains("report_rate_limited") { throw ReportRepositoryError.rateLimited }
            if text.contains("report_target") || text.contains("invalid_report_target") {
                throw ReportRepositoryError.invalidTarget
            }
            throw error
        }
    }
}
