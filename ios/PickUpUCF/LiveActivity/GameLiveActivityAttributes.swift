import ActivityKit
import Foundation

struct GameLiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var startsAt: Date
        var endsAt: Date
    }

    var sportName: String
    var locationName: String
    var sessionId: String
    var sportSystemImage: String
}

enum GameLiveActivityPresentation {
    enum Phase: Equatable {
        case preSession
        case live
        case ended
    }

    static func phase(startsAt: Date, endsAt: Date, now: Date = .now) -> Phase {
        if now >= endsAt { return .ended }
        if now >= startsAt { return .live }
        return .preSession
    }

    static func countdownInterval(startsAt: Date, now: Date = .now) -> ClosedRange<Date> {
        min(now, startsAt)...startsAt
    }
}
