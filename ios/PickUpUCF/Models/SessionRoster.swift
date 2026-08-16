import Foundation

struct SessionRosterMember: Decodable, Equatable, Identifiable {
    let userId: UUID
    let displayName: String
    let username: String?
    let role: ParticipantRole

    var id: UUID { userId }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case displayName = "display_name"
        case username, role
    }

    var handle: String {
        if let username, !username.isEmpty { return "@\(username)" }
        return displayName
    }
}

struct SessionRoster: Decodable, Equatable {
    let joined: [SessionRosterMember]
    let waitlistCount: Int
    let viewerWaitlistPosition: Int?

    enum CodingKeys: String, CodingKey {
        case joined
        case waitlistCount = "waitlist_count"
        case viewerWaitlistPosition = "viewer_waitlist_position"
    }

    func waitlistLabel(participantStatus: ParticipantStatus?) -> String? {
        guard participantStatus == .waitlist,
              let position = viewerWaitlistPosition else { return nil }
        return "You're #\(position) on the waitlist (\(waitlistCount) waiting)"
    }
}

struct GetSessionRosterParams: Encodable {
    let pSessionId: UUID

    enum CodingKeys: String, CodingKey {
        case pSessionId = "p_session_id"
    }
}
