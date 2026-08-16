import SwiftUI

struct SportPickerGrid: View {
    let selectedSports: Set<SportType>
    let onToggle: (SportType) -> Void

    private let sportColumns = [
        GridItem(.adaptive(minimum: 104), spacing: Spacing.s),
    ]

    var body: some View {
        LazyVGrid(columns: sportColumns, spacing: Spacing.s) {
            ForEach(SportType.allCases) { sport in
                SportPickerChip(
                    sport: sport,
                    isSelected: selectedSports.contains(sport),
                    action: { onToggle(sport) }
                )
            }
        }
    }
}

struct SportPickerChip: View {
    @Environment(\.colorScheme) private var colorScheme

    let sport: SportType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.s) {
                Image(systemName: sport.systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.black : AppColor.sportAccent(sport))

                Text(sport.displayName)
                    .font(AppFont.caption(.semibold))
                    .foregroundStyle(isSelected ? Color.black : AppColor.textPrimary(colorScheme))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.m)
            .padding(.horizontal, Spacing.s)
            .background(isSelected ? AppColor.gold : AppColor.surface(colorScheme))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isSelected ? AppColor.gold : AppColor.textSecondary(colorScheme).opacity(0.25),
                        lineWidth: isSelected ? 0 : 1
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityLabel(sport.displayName)
    }
}
