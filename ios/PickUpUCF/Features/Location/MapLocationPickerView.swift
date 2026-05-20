import MapKit
import SwiftUI

/// Search campus-area places, tap the map, and confirm a custom session location.
struct MapLocationPickerView: View {
    @Binding var selection: CustomLocationSelection?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching = false
    @State private var draftLabel = ""
    @State private var pinCoordinate = CampusCoordinates.main
    @State private var cameraPosition: MapCameraPosition = .region(LocationGeocoding.campusRegion)

    var body: some View {
        VStack(spacing: 0) {
            searchField

            if isSearching {
                ProgressView()
                    .padding(Spacing.m)
            } else if !searchResults.isEmpty {
                searchResultsList
            }

            mapSection
            selectedSummary
        }
        .background(AppColor.background(colorScheme))
        .navigationTitle("Choose location")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Use this spot") {
                    confirmSelection()
                }
                .fontWeight(.semibold)
                .disabled(draftLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .onAppear {
            if let existing = selection {
                pinCoordinate = existing.coordinate
                draftLabel = existing.label
                cameraPosition = .region(region(around: existing.coordinate))
            }
        }
        .task(id: searchText) {
            await runSearch()
        }
    }

    private var searchField: some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppColor.textSecondary(colorScheme))
            TextField("Search near UCF", text: $searchText)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    searchResults = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppColor.textSecondary(colorScheme))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Spacing.m)
        .background(AppColor.surface(colorScheme))
    }

    private var searchResultsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(searchResults.enumerated()), id: \.offset) { _, item in
                    Button {
                        applyMapItem(item)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name ?? "Place")
                                .font(AppFont.body(.semibold))
                                .foregroundStyle(AppColor.textPrimary(colorScheme))
                            if let subtitle = item.placemark.title {
                                Text(subtitle)
                                    .font(AppFont.caption())
                                    .foregroundStyle(AppColor.textSecondary(colorScheme))
                                    .lineLimit(2)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Spacing.m)
                    }
                    .buttonStyle(.plain)
                    Divider()
                }
            }
        }
        .frame(maxHeight: 160)
        .background(AppColor.surface(colorScheme))
    }

    private var mapSection: some View {
        MapReader { proxy in
            Map(position: $cameraPosition) {
                Marker(draftLabel.isEmpty ? "Selected spot" : draftLabel, coordinate: pinCoordinate)
            }
            .mapStyle(.standard(elevation: .realistic))
            .onTapGesture { point in
                guard let coordinate = proxy.convert(point, from: .local) else { return }
                Task { await applyCoordinate(coordinate) }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var selectedSummary: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("Selected")
                .font(AppFont.caption(.semibold))
                .foregroundStyle(AppColor.textSecondary(colorScheme))
            Text(draftLabel.isEmpty ? "Search or tap the map to drop a pin." : draftLabel)
                .font(AppFont.body())
                .foregroundStyle(AppColor.textPrimary(colorScheme))
            FormFieldHint(text: "Tip: tap the map to fine-tune the pin after searching.")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.m)
        .background(.ultraThinMaterial)
    }

    @MainActor
    private func runSearch() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else {
            searchResults = []
            isSearching = false
            return
        }

        try? await Task.sleep(nanoseconds: 300_000_000)
        guard !Task.isCancelled else { return }

        isSearching = true
        defer { isSearching = false }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = LocationGeocoding.campusRegion
        request.resultTypes = [.pointOfInterest, .address]

        do {
            let response = try await MKLocalSearch(request: request).start()
            searchResults = Array(response.mapItems.prefix(8))
        } catch {
            searchResults = []
        }
    }

    @MainActor
    private func applyMapItem(_ item: MKMapItem) {
        let picked = LocationGeocoding.selection(from: item)
        pinCoordinate = picked.coordinate
        draftLabel = picked.label
        cameraPosition = .region(region(around: picked.coordinate))
        searchResults = []
        searchText = picked.label
    }

    @MainActor
    private func applyCoordinate(_ coordinate: CLLocationCoordinate2D) async {
        pinCoordinate = coordinate
        cameraPosition = .region(region(around: coordinate))
        draftLabel = await LocationGeocoding.label(for: coordinate)
    }

    private func confirmSelection() {
        let trimmed = draftLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        selection = CustomLocationSelection(label: trimmed, coordinate: pinCoordinate)
        dismiss()
    }

    private func region(around coordinate: CLLocationCoordinate2D) -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
        )
    }
}
