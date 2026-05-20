import Foundation

struct Venue: Codable, Identifiable, Equatable {
    let id: UUID
    let name: String
    let lat: Double
    let lng: Double
    var campusZone: String?
    var isOfficial: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, lat, lng
        case campusZone = "campus_zone"
        case isOfficial = "is_official"
    }
}
