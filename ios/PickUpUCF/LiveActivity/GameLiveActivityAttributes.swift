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
