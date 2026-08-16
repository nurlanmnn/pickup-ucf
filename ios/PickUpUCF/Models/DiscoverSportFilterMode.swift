import Foundation

enum DiscoverSportFilterMode: Equatable {
    case mySports
    case single(SportType?)
}

enum DiscoverSportFilterStorage {
    private static let key = "discoverSportFilterMode"

    /// Returns the persisted filter mode.
    /// Only the "My Sports" preference is remembered across sessions;
    /// individual sport chip selections always reset to "All" on relaunch.
    static func load() -> DiscoverSportFilterMode? {
        guard let raw = UserDefaults.standard.string(forKey: key) else { return nil }
        if raw == "mySports" { return .mySports }
        // Any previously-saved specific sport or "all" → start on All.
        return .single(nil)
    }

    static func save(_ mode: DiscoverSportFilterMode) {
        switch mode {
        case .mySports:
            UserDefaults.standard.set("mySports", forKey: key)
        case .single(nil), .single(_?):
            // Don't persist specific sport chips — they reset to All on next launch.
            UserDefaults.standard.set("all", forKey: key)
        }
    }
}
