import MapKit
import SwiftUI

struct SessionLocationMap: View {
    let session: PickupSession

    @Environment(\.colorScheme) private var colorScheme
    @State private var coordinate: CLLocationCoordinate2D?
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let coordinate {
                        Map(position: $cameraPosition) {
                            Marker(session.locationName, coordinate: coordinate)
                        }
                        .disabled(!isExpanded)
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
                .frame(height: isExpanded ? 280 : 160)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    if coordinate != nil, !isExpanded {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                    isExpanded = true
                                }
                            }
                            .accessibilityHidden(true)
                    }
                }

                if coordinate != nil {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isExpanded
                              ? "arrow.down.right.and.arrow.up.left"
                              : "arrow.up.left.and.arrow.down.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppColor.textPrimary(colorScheme))
                            .padding(Spacing.s)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(Spacing.s)
                    .accessibilityLabel(isExpanded ? "Collapse map" : "Expand map")
                }
            }

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
