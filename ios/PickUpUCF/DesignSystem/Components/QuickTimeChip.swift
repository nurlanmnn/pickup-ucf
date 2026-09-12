import SwiftUI

struct QuickTimeChip: View {
    @Environment(\.colorScheme) private var colorScheme

    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(AppFont.caption(.semibold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(isSelected ? Color.black : AppColor.textPrimary(colorScheme))
                .padding(.horizontal, Spacing.m)
                .padding(.vertical, Spacing.s)
                .background(isSelected ? AppColor.gold : AppColor.surface(colorScheme))
                .overlay {
                    Capsule()
                        .stroke(
                            isSelected ? AppColor.gold : AppColor.textSecondary(colorScheme).opacity(0.25),
                            lineWidth: isSelected ? 0 : 1
                        )
                }
                .clipShape(Capsule())
                .frame(minHeight: AccessibilityLayout.minimumTouchTarget)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
