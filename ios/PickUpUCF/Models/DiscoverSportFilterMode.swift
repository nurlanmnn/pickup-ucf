import Foundation

enum DiscoverSportFilterMode: Equatable {
    case mySports
    case single(SportType?)
}

enum DiscoverSportFilterStorage {
    private static let key = "discoverSportFilterMode"

    static func load() -> DiscoverSportFilterMode? {
        guard let raw = UserDefaults.standard.string(forKey: key) else { return nil }
        if raw == "mySports" { return .mySports }
        if raw == "all" { return .single(nil) }
        if let sport = SportType(rawValue: raw) { return .single(sport) }
        return nil
    }

    static func save(_ mode: DiscoverSportFilterMode) {
        switch mode {
        case .mySports:
            UserDefaults.standard.set("mySports", forKey: key)
        case .single(nil):
            UserDefaults.standard.set("all", forKey: key)
        case .single(let sport?):
            UserDefaults.standard.set(sport.rawValue, forKey: key)
        }
    }
}
