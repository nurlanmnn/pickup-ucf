import MapKit
import XCTest
@testable import PickUpUCF

final class DiscoverMapZoomTests: XCTestCase {
    func testZoomInHalvesSpanAndKeepsCenter() {
        let region = MKCoordinateRegion(
            center: CampusCoordinates.main,
            span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
        )

        let zoomed = DiscoverMapZoom.zoomed(region, factor: DiscoverMapZoom.inFactor)

        XCTAssertEqual(zoomed.center.latitude, region.center.latitude)
        XCTAssertEqual(zoomed.center.longitude, region.center.longitude)
        XCTAssertEqual(zoomed.span.latitudeDelta, 0.02, accuracy: 0.0001)
        XCTAssertEqual(zoomed.span.longitudeDelta, 0.02, accuracy: 0.0001)
    }

    func testZoomOutDoublesSpanAndKeepsCenter() {
        let region = MKCoordinateRegion(
            center: CampusCoordinates.main,
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        )

        let zoomed = DiscoverMapZoom.zoomed(region, factor: DiscoverMapZoom.outFactor)

        XCTAssertEqual(zoomed.span.latitudeDelta, 0.04, accuracy: 0.0001)
        XCTAssertEqual(zoomed.span.longitudeDelta, 0.04, accuracy: 0.0001)
    }

    func testZoomInStopsAtMinimumSpan() {
        let region = MKCoordinateRegion(
            center: CampusCoordinates.main,
            span: MKCoordinateSpan(latitudeDelta: 0.003, longitudeDelta: 0.003)
        )

        let zoomed = DiscoverMapZoom.zoomed(region, factor: DiscoverMapZoom.inFactor)

        XCTAssertEqual(zoomed.span.latitudeDelta, DiscoverMapZoom.minDelta, accuracy: 0.0001)
        XCTAssertFalse(DiscoverMapZoom.canZoomIn(zoomed.span))
        XCTAssertTrue(DiscoverMapZoom.canZoomOut(zoomed.span))
    }

    func testZoomOutStopsAtMaximumSpan() {
        let region = MKCoordinateRegion(
            center: CampusCoordinates.main,
            span: MKCoordinateSpan(latitudeDelta: 0.3, longitudeDelta: 0.3)
        )

        let zoomed = DiscoverMapZoom.zoomed(region, factor: DiscoverMapZoom.outFactor)

        XCTAssertEqual(zoomed.span.latitudeDelta, DiscoverMapZoom.maxDelta, accuracy: 0.0001)
        XCTAssertFalse(DiscoverMapZoom.canZoomOut(zoomed.span))
        XCTAssertTrue(DiscoverMapZoom.canZoomIn(zoomed.span))
    }
}
