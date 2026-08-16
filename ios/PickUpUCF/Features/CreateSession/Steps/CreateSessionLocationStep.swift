import SwiftUI

struct CreateSessionLocationStep: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var viewModel: CreateSessionViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            sectionHeader("Where")
                .id(CreateSessionScrollAnchor.location)

            if viewModel.venues.isEmpty {
                HStack(spacing: Spacing.s) {
                    ProgressView()
                    Text("Loading venues…")
                        .font(AppFont.body())
                        .foregroundStyle(AppColor.textSecondary(colorScheme))
                }
            } else {
                VStack(spacing: Spacing.s) {
                    ForEach(viewModel.venues) { venue in
                        venueCard(venue)
                    }
                    customLocationCard
                }
            }

            if let error = viewModel.locationError {
                FieldErrorLabel(message: error)
            }

            if viewModel.showsCustomLocationField {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text("Drop a pin")
                        .font(AppFont.caption(.semibold))
                        .foregroundStyle(AppColor.textSecondary(colorScheme))

                    MapLocationPickerView(
                        selection: $viewModel.customLocationSelection,
                        embedded: true
                    )
                    .frame(height: 360)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            } else if let venueId = viewModel.selectedVenueId,
                      let venue = viewModel.venues.first(where: { $0.id == venueId }) {
                selectedVenueSummary(venue)
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(AppFont.headline(.semibold))
            .foregroundStyle(AppColor.textPrimary(colorScheme))
    }

    private func venueCard(_ venue: Venue) -> some View {
        let isSelected = viewModel.venuePickerOptionId == venue.id.uuidString

        return Button {
            viewModel.venuePickerOptionId = venue.id.uuidString
            viewModel.customLocationSelection = nil
        } label: {
            HStack(spacing: Spacing.m) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(venue.name)
                        .font(AppFont.body(.semibold))
                        .foregroundStyle(AppColor.textPrimary(colorScheme))
                    if let zone = venue.campusZone, !zone.isEmpty {
                        Text(zone)
                            .font(AppFont.caption())
                            .foregroundStyle(AppColor.textSecondary(colorScheme))
                    }
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppColor.gold)
                }
            }
            .padding(Spacing.m)
            .background(isSelected ? AppColor.gold.opacity(0.15) : AppColor.surface(colorScheme))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isSelected ? AppColor.gold : AppColor.textSecondary(colorScheme).opacity(0.2),
                        lineWidth: isSelected ? 2 : 1
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var customLocationCard: some View {
        let isSelected = viewModel.venuePickerOptionId == CreateSessionViewModel.customVenuePickerTag

        return Button {
            viewModel.venuePickerOptionId = CreateSessionViewModel.customVenuePickerTag
        } label: {
            HStack(spacing: Spacing.m) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.title3)
                    .foregroundStyle(isSelected ? AppColor.gold : AppColor.textSecondary(colorScheme))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Custom location")
                        .font(AppFont.body(.semibold))
                        .foregroundStyle(AppColor.textPrimary(colorScheme))
                    Text("Search near campus or drop a pin")
                        .font(AppFont.caption())
                        .foregroundStyle(AppColor.textSecondary(colorScheme))
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppColor.gold)
                }
            }
            .padding(Spacing.m)
            .background(isSelected ? AppColor.gold.opacity(0.15) : AppColor.surface(colorScheme))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isSelected ? AppColor.gold : AppColor.textSecondary(colorScheme).opacity(0.2),
                        lineWidth: isSelected ? 2 : 1
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func selectedVenueSummary(_ venue: Venue) -> some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AppColor.gold)
            Text(venue.name)
                .font(AppFont.caption(.semibold))
                .foregroundStyle(AppColor.textSecondary(colorScheme))
        }
    }
}
