import SwiftUI

struct SportPickerGrid: View {
    let selectedSports: Set<SportType>
    let onToggle: (SportType) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var sportColumns: [GridItem] {
        if AccessibilityLayout.usesVerticalActions(at: dynamicTypeSize) {
            return [GridItem(.flexible(), spacing: Spacing.s)]
        }
        return [GridItem(.adaptive(minimum: 104), spacing: Spacing.s)]
    }

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
                    .foregroundStyle(isSelected ? Color.black : AppColor.accent(colorScheme))

                HStack(spacing: Spacing.xs) {
                    Text(sport.displayName)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .accessibilityHidden(true)
                    }
                }
                    .font(AppFont.caption(.semibold))
                    .foregroundStyle(isSelected ? Color.black : AppColor.textPrimary(colorScheme))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: AccessibilityLayout.minimumTouchTarget)
            .padding(.vertical, Spacing.m)
            .padding(.horizontal, Spacing.s)
            .background(isSelected ? AppColor.gold : AppColor.surface(colorScheme))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isSelected ? AppColor.accent(colorScheme) : AppColor.textSecondary(colorScheme).opacity(0.25),
                        lineWidth: isSelected ? 0 : 1
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(AppPressStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityLabel(sport.displayName)
    }
}
