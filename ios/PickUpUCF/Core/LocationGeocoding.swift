import CoreLocation
import MapKit

enum LocationGeocoding {
    static let campusRegion = MKCoordinateRegion(
        center: CampusCoordinates.main,
        span: MKCoordinateSpan(latitudeDelta: 0.14, longitudeDelta: 0.14)
    )

    static func label(for coordinate: CLLocationCoordinate2D) async -> String {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard let placemark = try? await geocoder.reverseGeocodeLocation(location).first else {
            return String(format: "Pin (%.4f, %.4f)", coordinate.latitude, coordinate.longitude)
        }
        return placemarkLabel(placemark)
    }

    static func placemarkLabel(_ placemark: CLPlacemark) -> String {
        if let name = placemark.name, !name.isEmpty { return name }
        let parts = [placemark.thoroughfare, placemark.locality].compactMap { $0 }.filter { !$0.isEmpty }
        if !parts.isEmpty { return parts.joined(separator: ", ") }
        return "Selected location"
    }

    static func selection(from mapItem: MKMapItem) -> CustomLocationSelection {
        let coordinate = mapItem.placemark.coordinate
        let label = mapItem.name ?? placemarkLabel(mapItem.placemark)
        return CustomLocationSelection(label: label, coordinate: coordinate)
    }

    /// Build initial picker state when editing a session with only a text custom location.
    static func selectionForExistingSession(
        label: String,
        latitude: Double?,
        longitude: Double?
    ) async -> CustomLocationSelection? {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let latitude, let longitude {
            return CustomLocationSelection(label: trimmed, latitude: latitude, longitude: longitude)
        }

        let geocoder = CLGeocoder()
        let query = "\(trimmed), University of Central Florida, Orlando, FL"
        if let placemark = try? await geocoder.geocodeAddressString(query).first,
           let location = placemark.location {
            let resolved = placemarkLabel(placemark)
            return CustomLocationSelection(
                label: resolved.isEmpty ? trimmed : resolved,
                coordinate: location.coordinate
            )
        }

        return CustomLocationSelection(label: trimmed, coordinate: CampusCoordinates.main)
    }
}
