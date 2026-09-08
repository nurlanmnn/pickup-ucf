import ActivityKit
import Foundation

struct GameLiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var startsAt: Date
    }

    var sportName: String
    var locationName: String
    var sessionId: String
    var sportSystemImage: String
}

enum GameLiveActivityPresentation {
    static func isLive(startsAt: Date, isStale: Bool, now: Date = .now) -> Bool {
        isStale || startsAt <= now
    }

    static func countdownInterval(startsAt: Date, now: Date = .now) -> ClosedRange<Date> {
        min(now, startsAt)...startsAt
    }
}
