import MapKit
import SwiftUI

struct SessionLocationMap: View {
    let session: PickupSession

    @Environment(\.colorScheme) private var colorScheme
    @State private var coordinate: CLLocationCoordinate2D?
    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Group {
                if let coordinate {
                    Map(position: $cameraPosition) {
                        Marker(session.locationName, coordinate: coordinate)
                    }
                    .onAppear {
                        cameraPosition = .region(
                            MKCoordinateRegion(
                                center: coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
                            )
                        )
                    }
                } else {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppColor.surface(colorScheme))
                        .overlay {
                            ProgressView()
                        }
                }
            }
            .frame(height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            if coordinate != nil {
                Button {
                    openInMaps()
                } label: {
                    Label("Open in Maps", systemImage: "map")
                        .font(AppFont.caption(.semibold))
                        .foregroundStyle(AppColor.gold)
                }
                .buttonStyle(.plain)
            }
        }
        .task(id: session.id) {
            coordinate = await SessionLocationResolver.coordinate(for: session)
        }
    }

    private func openInMaps() {
        guard let coordinate else { return }
        let placemark = MKPlacemark(coordinate: coordinate)
        let item = MKMapItem(placemark: placemark)
        item.name = session.locationName
        item.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking,
        ])
    }
}
