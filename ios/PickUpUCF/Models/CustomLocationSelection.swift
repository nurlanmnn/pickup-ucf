import CoreLocation
import Foundation

/// User-picked spot for a session that is not an official campus venue.
struct CustomLocationSelection: Equatable {
    var label: String
    var latitude: Double
    var longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(label: String, latitude: Double, longitude: Double) {
        self.label = label
        self.latitude = latitude
        self.longitude = longitude
    }

    init(label: String, coordinate: CLLocationCoordinate2D) {
        self.label = label
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }
}
