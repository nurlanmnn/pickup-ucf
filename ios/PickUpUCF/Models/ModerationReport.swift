import Foundation

enum ReportTargetType: String, Codable, CaseIterable {
    case session
    case message
    case user
}

struct ReportTarget: Equatable {
    let type: ReportTargetType
    let id: UUID

    static func session(_ id: UUID) -> Self { Self(type: .session, id: id) }
    static func message(_ id: UUID) -> Self { Self(type: .message, id: id) }
    static func user(_ id: UUID) -> Self { Self(type: .user, id: id) }
}

enum ReportCategory: String, Codable, CaseIterable, Identifiable {
    case harassment
    case hate
    case threat
    case sexualContent = "sexual_content"
    case spam
    case impersonation
    case unsafeBehavior = "unsafe_behavior"
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .harassment: "Harassment or bullying"
        case .hate: "Hate speech"
        case .threat: "Threats or violence"
        case .sexualContent: "Sexual content"
        case .spam: "Spam or scam"
        case .impersonation: "Impersonation"
        case .unsafeBehavior: "Unsafe behavior"
        case .other: "Other"
        }
    }
}

enum ModerationActionType: String, Codable, CaseIterable, Identifiable {
    case dismiss
    case removeContent = "remove_content"
    case warnUser = "warn_user"
    case suspendUser = "suspend_user"
    case resolve

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dismiss: "Dismiss report"
        case .removeContent: "Remove content"
        case .warnUser: "Warn user"
        case .suspendUser: "Suspend user"
        case .resolve: "Resolve without action"
        }
    }
}

struct ModerationQueueItem: Codable, Identifiable, Equatable {
    let id: UUID
    let targetType: ReportTargetType
    let targetId: UUID
    let category: ReportCategory
    let context: String?
    let targetSummary: String
    let subjectUserId: UUID
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case targetType = "target_type"
        case targetId = "target_id"
        case category, context
        case targetSummary = "target_summary"
        case subjectUserId = "subject_user_id"
        case createdAt = "created_at"
    }
}

struct ModerationNotice: Codable, Identifiable, Equatable {
    let id: UUID
    let kind: ModerationActionType
    let message: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, kind, message
        case createdAt = "created_at"
    }
}
