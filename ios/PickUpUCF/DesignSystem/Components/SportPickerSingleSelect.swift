import SwiftUI

struct SportPickerSingleSelect: View {
    @Binding var selectedSport: SportType
    var onSelect: () -> Void = {}

    var body: some View {
        SportPickerGrid(
            selectedSports: [selectedSport],
            onToggle: { sport in
                selectedSport = sport
                onSelect()
            }
        )
    }
}
