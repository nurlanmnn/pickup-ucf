import SwiftUI

/// A row of filled/empty dots showing how many of `capacity` spots are taken.
/// Caps the display at `maxDots` to stay compact on any card width.
struct CapacityIndicator: View {
    let playerCount: Int
    let capacity: Int
    var maxDots: Int = 12
    var filledColor: Color = AppColor.gold
    var dotSize: CGFloat = 6
    /// Color for empty (unfilled) dots. Defaults to `mutedSurface` when nil.
    var emptyColor: Color? = nil
    /// Color for the "X/Y" count label. Defaults to `textSecondary` when nil.
    var labelColor: Color? = nil

    @Environment(\.colorScheme) private var colorScheme

    private var displayCount: Int { min(capacity, maxDots) }
    private var filledCount: Int {
        guard capacity > 0 else { return 0 }
        if capacity <= maxDots {
            return min(playerCount, capacity)
        }
        // Scale proportionally when capacity exceeds maxDots
        return Int((Double(playerCount) / Double(capacity) * Double(maxDots)).rounded())
    }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<displayCount, id: \.self) { index in
                Circle()
                    .fill(index < filledCount ? filledColor : (emptyColor ?? AppColor.mutedSurface(colorScheme)))
                    .frame(width: dotSize, height: dotSize)
            }

            Text("\(playerCount)/\(capacity)")
                .font(AppFont.caption2(.semibold))
                .foregroundStyle(labelColor ?? AppColor.textSecondary(colorScheme))
                .padding(.leading, 4)
        }
        .accessibilityLabel("\(playerCount) of \(capacity) spots filled")
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
