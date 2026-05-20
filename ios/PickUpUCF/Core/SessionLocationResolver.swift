import CoreLocation
import MapKit

enum SessionLocationResolver {
    static func coordinate(for session: PickupSession) async -> CLLocationCoordinate2D {
        if let venue = session.venue {
            return CLLocationCoordinate2D(latitude: venue.lat, longitude: venue.lng)
        }

        if let lat = session.customLat, let lng = session.customLng {
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }

        if let custom = session.customLocation?.trimmingCharacters(in: .whitespacesAndNewlines),
           !custom.isEmpty {
            let query = "\(custom), University of Central Florida, Orlando, FL"
            let geocoder = CLGeocoder()
            if let placemarks = try? await geocoder.geocodeAddressString(query),
               let location = placemarks.first?.location {
                return location.coordinate
            }
        }

        return CampusCoordinates.main
    }
}
