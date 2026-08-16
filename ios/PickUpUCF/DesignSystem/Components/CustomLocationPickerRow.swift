import SwiftUI

/// Form row: preview + button to open the map location picker.
struct CustomLocationPickerRow: View {
    @Binding var selection: CustomLocationSelection?
    @Environment(\.colorScheme) private var colorScheme
    @State private var showMapPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            if let selection {
                Label(selection.label, systemImage: "mappin.circle.fill")
                    .font(AppFont.body(.semibold))
                    .foregroundStyle(AppColor.textPrimary(colorScheme))
            } else {
                Text("No location chosen yet")
                    .font(AppFont.body())
                    .foregroundStyle(AppColor.textSecondary(colorScheme))
            }

            Button {
                showMapPicker = true
            } label: {
                Label(
                    selection == nil ? "Search on map" : "Change on map",
                    systemImage: "map"
                )
                .font(AppFont.headline(.semibold))
                .foregroundStyle(AppColor.gold)
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showMapPicker) {
            NavigationStack {
                MapLocationPickerView(selection: $selection)
            }
            .appSheetChrome()
        }
    }
}
