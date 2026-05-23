import Foundation

/// Default list sizes to keep network and UI work bounded.
enum AppPagination {
    static let discoverSessions = 50
    static let myGamesUpcoming = 25
    static let myGamesPastPage = 15
    /// Cap participant rows scanned when resolving “my” upcoming games.
    static let myGamesParticipantIdCap = 80
    static let chatMessageLimit = 50
}
