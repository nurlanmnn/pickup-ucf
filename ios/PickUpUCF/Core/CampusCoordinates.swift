import CoreLocation

/// Approximate center of UCF main campus — fallback for custom locations when geocoding fails.
enum CampusCoordinates {
    static let main = CLLocationCoordinate2D(latitude: 28.6024, longitude: -81.2001)
}
