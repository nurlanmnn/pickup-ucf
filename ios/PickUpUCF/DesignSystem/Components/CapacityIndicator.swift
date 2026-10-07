import SwiftUI

/// A static, labeled player count that cannot be mistaken for page indicators.
struct CapacityIndicator: View {
    let playerCount: Int
    let capacity: Int
    var iconColor: Color = AppColor.gold
    /// Color for the player count. Defaults to `textSecondary` when nil.
    var labelColor: Color? = nil

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
            Image(systemName: "person.2.fill")
                .foregroundStyle(iconColor)
                .accessibilityHidden(true)

            Text("\(playerCount)/\(capacity) players")
                .monospacedDigit()
                .foregroundStyle(labelColor ?? AppColor.textSecondary(colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(AppFont.caption2(.semibold))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(playerCount) of \(capacity) player spots filled")
    }
}

#Preview {
    VStack(spacing: 16) {
        CapacityIndicator(playerCount: 4, capacity: 10)
        CapacityIndicator(playerCount: 10, capacity: 10)
        CapacityIndicator(playerCount: 0, capacity: 14)
        CapacityIndicator(playerCount: 7, capacity: 14)
    }
    .padding()
}
