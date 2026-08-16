import Foundation

struct WeatherSnapshot: Codable, Equatable {
    let summary: String
    let tempF: Int
    let precipPct: Int
    let fetchedAt: Date

    enum CodingKeys: String, CodingKey {
        case summary
        case tempF = "temp_f"
        case precipPct = "precip_pct"
        case fetchedAt = "fetched_at"
    }

    /// One-line hint for session detail, e.g. "82°F · 30% rain".
    var displayLine: String {
        "\(tempF)°F · \(precipPct)% rain"
    }
}

extension Venue {
    /// RWC indoor courts are excluded from weather (v1 name heuristic per Phase C spec).
    var isRWCIndoorCourt: Bool {
        name.localizedCaseInsensitiveContains("RWC")
    }
}

extension PickupSession {
    /// Outdoor venue (official, not RWC indoor) or custom map pin.
    var isOutdoorForWeather: Bool {
        if customLat != nil, customLng != nil { return true }
        if let venue {
            return venue.isOfficial && !venue.isRWCIndoorCourt
        }
        return false
    }

    var weatherCoordinates: (lat: Double, lng: Double)? {
        if let venue { return (venue.lat, venue.lng) }
        if let lat = customLat, let lng = customLng { return (lat, lng) }
        return nil
    }
}
