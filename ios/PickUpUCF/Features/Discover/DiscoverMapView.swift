import CoreLocation
import MapKit
import SwiftUI
import UIKit

// MARK: - Zoom math (pure, testable)

enum DiscoverMapZoom {
    static let inFactor: Double = 0.5
    static let outFactor: Double = 2.0
    static let minDelta: CLLocationDegrees = 0.002
    static let maxDelta: CLLocationDegrees = 0.4
    static let defaultSpan = MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)

    static var defaultRegion: MKCoordinateRegion {
        MKCoordinateRegion(center: CampusCoordinates.main, span: defaultSpan)
    }

    static func zoomed(_ region: MKCoordinateRegion, factor: Double) -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: region.center,
            span: MKCoordinateSpan(
                latitudeDelta: clamped(region.span.latitudeDelta * factor),
                longitudeDelta: clamped(region.span.longitudeDelta * factor)
            )
        )
    }

    static func canZoomIn(_ span: MKCoordinateSpan) -> Bool {
        span.latitudeDelta > minDelta
    }

    static func canZoomOut(_ span: MKCoordinateSpan) -> Bool {
        span.latitudeDelta < maxDelta
    }

    private static func clamped(_ delta: CLLocationDegrees) -> CLLocationDegrees {
        min(max(delta, minDelta), maxDelta)
    }
}

// MARK: - Location controller
// Requests "when in use" permission only on the first button tap, then pans to
// the user's location. Holds a weak reference to MKMapView to avoid retaining it.

@Observable
final class DiscoverMapLocationController: NSObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private(set) var authorizationStatus: CLAuthorizationStatus
    private(set) var isLocating = false
    weak var mapView: MKMapView?

    override init() {
        authorizationStatus = CLLocationManager().authorizationStatus
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    var isDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    /// True while the map is showing the user's location (tap again to return to campus).
    private(set) var isCenteredOnUser = false

    func handleButtonTap() {
        if isCenteredOnUser {
            centerOnCampus()
        } else {
            centerOnUserLocation()
        }
    }

    func centerOnCampus() {
        isCenteredOnUser = false
        mapView?.setRegion(DiscoverMapZoom.defaultRegion, animated: true)
    }

    private func centerOnUserLocation() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            isLocating = true
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            panToUserLocation()
        case .denied, .restricted:
            break
        @unknown default:
            break
        }
    }

    private func panToUserLocation() {
        guard let location = locationManager.location else {
            isLocating = true
            locationManager.requestLocation()
            return
        }
        animateToLocation(location)
    }

    private func animateToLocation(_ location: CLLocation) {
        isLocating = false
        isCenteredOnUser = true
        mapView?.showsUserLocation = true
        let region = MKCoordinateRegion(center: location.coordinate, span: DiscoverMapZoom.defaultSpan)
        mapView?.setRegion(region, animated: true)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            mapView?.showsUserLocation = true
            if isLocating { panToUserLocation() }
        case .denied, .restricted:
            isLocating = false
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        animateToLocation(location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isLocating = false
    }

    /// Called by the map delegate on every region change.
    /// Non-animated changes are user-initiated (pan/pinch or zoom button), so we
    /// un-track the user's location. Animated changes come from our own setRegion
    /// calls and should be ignored — the state was already set correctly before
    /// the setRegion call.
    func mapRegionChanged(animated: Bool) {
        if !animated {
            isCenteredOnUser = false
        }
    }
}

// MARK: - Zoom controller
// Holds a direct weak reference to the MKMapView so button taps call
// setRegion(animated:false) directly — no SwiftUI state round-trip, no race.

@Observable
final class DiscoverMapZoomController {
    private(set) var canZoomIn = true
    private(set) var canZoomOut = true
    weak var mapView: MKMapView?

    func zoomIn() {
        guard let mapView else { return }
        let next = DiscoverMapZoom.zoomed(mapView.region, factor: DiscoverMapZoom.inFactor)
        mapView.setRegion(next, animated: false)
        let span = next.span
        updateState(span: span)
        // MKMapView fires regionDidChangeAnimated a second time asynchronously after
        // setRegion(animated:false). Queue a correction on the main queue so it
        // always runs after that stale callback, ensuring the right button state wins.
        DispatchQueue.main.async { [weak self] in self?.updateState(span: span) }
    }

    func zoomOut() {
        guard let mapView else { return }
        let next = DiscoverMapZoom.zoomed(mapView.region, factor: DiscoverMapZoom.outFactor)
        mapView.setRegion(next, animated: false)
        let span = next.span
        updateState(span: span)
        DispatchQueue.main.async { [weak self] in self?.updateState(span: span) }
    }

    func regionChanged(_ region: MKCoordinateRegion) {
        updateState(span: region.span)
    }

    private func updateState(span: MKCoordinateSpan) {
        canZoomIn = DiscoverMapZoom.canZoomIn(span)
        canZoomOut = DiscoverMapZoom.canZoomOut(span)
    }
}

// MARK: - Annotation model

private final class SessionPointAnnotation: NSObject, MKAnnotation {
    let sessionId: UUID
    let sport: SportType
    let sportDisplayName: String
    let locationName: String
    dynamic var coordinate: CLLocationCoordinate2D
    var title: String? { locationName }

    init(annotation: SessionMapAnnotation) {
        sessionId = annotation.id
        sport = annotation.session.sport
        sportDisplayName = annotation.session.sportDisplayName
        locationName = annotation.session.locationName
        coordinate = annotation.coordinate
    }
}

// MARK: - Pin image cache

private enum DiscoverMapPinRenderer {
    private static var cache: [SportType: UIImage] = [:]

    static func image(for sport: SportType) -> UIImage {
        if let cached = cache[sport] { return cached }

        let size = CGSize(width: 40, height: 40)
        let image = UIGraphicsImageRenderer(size: size).image { _ in
            let rect = CGRect(origin: .zero, size: size)
            let gold = UIColor(red: 1.0, green: 0.788, blue: 0.016, alpha: 1.0)

            gold.setFill()
            UIBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1)).fill()

            UIColor.white.setStroke()
            let stroke = UIBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1))
            stroke.lineWidth = 2
            stroke.stroke()

            let cfg = UIImage.SymbolConfiguration(pointSize: 17, weight: .bold)
            if let symbol = UIImage(systemName: sport.systemImage, withConfiguration: cfg)?
                .withTintColor(.black, renderingMode: .alwaysOriginal) {
                let origin = CGPoint(
                    x: (size.width - symbol.size.width) / 2,
                    y: (size.height - symbol.size.height) / 2
                )
                symbol.draw(at: origin)
            }
        }

        cache[sport] = image
        return image
    }
}

// MARK: - UIViewRepresentable wrapper

private struct DiscoverMapRepresentable: UIViewRepresentable {
    let annotations: [SessionMapAnnotation]
    let onSelectSession: (UUID) -> Void
    let zoomController: DiscoverMapZoomController
    let locationController: DiscoverMapLocationController

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.pointOfInterestFilter = .excludingAll
        mapView.register(MKAnnotationView.self, forAnnotationViewWithReuseIdentifier: "session-pin")
        mapView.setRegion(DiscoverMapZoom.defaultRegion, animated: false)
        zoomController.mapView = mapView
        locationController.mapView = mapView
        context.coordinator.syncAnnotations(on: mapView, with: annotations)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self
        zoomController.mapView = mapView
        locationController.mapView = mapView
        context.coordinator.syncAnnotations(on: mapView, with: annotations)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: DiscoverMapRepresentable

        init(parent: DiscoverMapRepresentable) { self.parent = parent }

        func syncAnnotations(on mapView: MKMapView, with annotations: [SessionMapAnnotation]) {
            let existing = mapView.annotations.compactMap { $0 as? SessionPointAnnotation }
            let existingIds = Set(existing.map(\.sessionId))
            let targetIds = Set(annotations.map(\.id))

            let removable = existing.filter { !targetIds.contains($0.sessionId) }
            if !removable.isEmpty { mapView.removeAnnotations(removable) }

            let additions = annotations
                .filter { !existingIds.contains($0.id) }
                .map(SessionPointAnnotation.init)
            if !additions.isEmpty { mapView.addAnnotations(additions) }
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let session = annotation as? SessionPointAnnotation else { return nil }
            let view = mapView.dequeueReusableAnnotationView(
                withIdentifier: "session-pin", for: annotation
            )
            view.annotation = annotation
            view.image = DiscoverMapPinRenderer.image(for: session.sport)
            view.centerOffset = CGPoint(x: 0, y: -20)
            view.canShowCallout = false
            view.accessibilityLabel = "\(session.sportDisplayName) at \(session.locationName)"
            view.accessibilityHint = "Opens session details"
            return view
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let session = view.annotation as? SessionPointAnnotation else { return }
            mapView.deselectAnnotation(session, animated: false)
            parent.onSelectSession(session.sessionId)
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.zoomController.regionChanged(mapView.region)
            parent.locationController.mapRegionChanged(animated: animated)
        }
    }
}

// MARK: - Public view

struct DiscoverMapView: View {
    let sessions: [PickupSession]
    let onSelectSession: (UUID) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var zoom = DiscoverMapZoomController()
    @State private var location = DiscoverMapLocationController()

    private var annotations: [SessionMapAnnotation] {
        sessions.compactMap(SessionMapAnnotation.init)
    }

    var body: some View {
        DiscoverMapRepresentable(
            annotations: annotations,
            onSelectSession: onSelectSession,
            zoomController: zoom,
            locationController: location
        )
        .accessibilityLabel("Discover sessions map")
        .overlay(alignment: .top) {
            if annotations.isEmpty {
                Label("No mapped sessions in these results", systemImage: "mappin.slash")
                    .font(AppFont.caption(.semibold))
                    .padding(.horizontal, Spacing.m)
                    .padding(.vertical, Spacing.s)
                    .background(.regularMaterial, in: Capsule())
                    .padding(Spacing.m)
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .topTrailing) {
            zoomControls
                .padding(Spacing.s)
        }
        .overlay(alignment: .bottomTrailing) {
            if !location.isDenied {
                myLocationButton
                    .padding(Spacing.s)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var zoomControls: some View {
        VStack(spacing: 0) {
            zoomButton(systemImage: "plus", label: "Zoom in", enabled: zoom.canZoomIn) {
                zoom.zoomIn()
            }
            Divider().frame(width: 22)
            zoomButton(systemImage: "minus", label: "Zoom out", enabled: zoom.canZoomOut) {
                zoom.zoomOut()
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var myLocationButton: some View {
        Button {
            location.handleButtonTap()
        } label: {
            Group {
                if location.isLocating {
                    ProgressView()
                        .tint(AppColor.textPrimary(colorScheme))
                        .scaleEffect(0.75)
                } else {
                    Image(systemName: location.isCenteredOnUser ? "location.fill" : "location")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(
                            location.isCenteredOnUser
                                ? AppColor.gold
                                : AppColor.textPrimary(colorScheme)
                        )
                }
            }
            .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityLabel(location.isCenteredOnUser ? "Return to campus" : "Center on my location")
    }

    private func zoomButton(
        systemImage: String,
        label: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppColor.textPrimary(colorScheme))
                .frame(width: 36, height: 36)
                .opacity(enabled ? 1 : 0.35)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
}
