import Foundation

struct CreateSessionDefaults: Equatable {
    var sport: SportType?
    var venueId: UUID?
}

enum CreateSessionDefaultsStorage {
    private static let sportKey = "createSession.lastSport"
    private static let venueKey = "createSession.lastVenueId"

    static func load(from defaults: UserDefaults = .standard) -> CreateSessionDefaults {
        let sport = defaults.string(forKey: sportKey).flatMap(SportType.init(rawValue:))
        let venueId = defaults.string(forKey: venueKey).flatMap(UUID.init(uuidString:))
        return CreateSessionDefaults(sport: sport, venueId: venueId)
    }

    static func save(sport: SportType, venueId: UUID?, to defaults: UserDefaults = .standard) {
        defaults.set(sport.rawValue, forKey: sportKey)
        if let venueId {
            defaults.set(venueId.uuidString, forKey: venueKey)
        }
    }
}
