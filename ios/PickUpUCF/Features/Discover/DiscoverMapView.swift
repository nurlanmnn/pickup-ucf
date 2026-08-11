import MapKit
import SwiftUI

struct DiscoverMapView: View {
    let sessions: [PickupSession]
    let onSelectSession: (UUID) -> Void

    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CampusCoordinates.main,
            span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
        )
    )

    private var annotations: [SessionMapAnnotation] {
        sessions.compactMap(SessionMapAnnotation.init)
    }

    var body: some View {
        Map(position: $cameraPosition) {
            ForEach(annotations) { annotation in
                Annotation(
                    annotation.session.locationName,
                    coordinate: annotation.coordinate,
                    anchor: .bottom
                ) {
                    Button {
                        onSelectSession(annotation.id)
                    } label: {
                        Image(systemName: annotation.session.sport.systemImage)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Color.black)
                            .frame(width: 40, height: 40)
                            .background(AppColor.gold)
                            .clipShape(Circle())
                            .overlay {
                                Circle().stroke(Color.white, lineWidth: 2)
                            }
                            .shadow(radius: 2, y: 1)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        "\(annotation.session.sportDisplayName) at \(annotation.session.locationName)"
                    )
                    .accessibilityHint("Opens session details")
                }
            }
        }
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
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityLabel("Discover sessions map")
    }
}
