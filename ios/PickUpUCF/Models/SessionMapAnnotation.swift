import CoreLocation

struct SessionMapAnnotation: Identifiable {
    let session: PickupSession
    let coordinate: CLLocationCoordinate2D

    var id: UUID {
        session.id
    }

    init?(session: PickupSession) {
        let coordinate: CLLocationCoordinate2D
        if let venue = session.venue {
            coordinate = CLLocationCoordinate2D(latitude: venue.lat, longitude: venue.lng)
        } else {
            guard let latitude = session.customLat,
                  let longitude = session.customLng else {
                return nil
            }
            coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }

        self.session = session
        self.coordinate = coordinate
    }
}
