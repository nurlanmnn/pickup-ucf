import SwiftUI

/// Tappable section header for lazy-loaded lists (e.g. Past games on My Games).
struct CollapsibleSectionHeader: View {
    let title: String
    let subtitle: String?
    let isExpanded: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: Spacing.s) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFont.headline(.semibold))
                    .foregroundStyle(AppColor.textPrimary(colorScheme))
                if let subtitle {
                    Text(subtitle)
                        .font(AppFont.caption())
                        .foregroundStyle(AppColor.textSecondary(colorScheme))
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColor.textSecondary(colorScheme))
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .animation(.easeInOut(duration: 0.2), value: isExpanded)
        }
        .contentShape(Rectangle())
        .accessibilityAddTraits(isExpanded ? .isSelected : [])
        .accessibilityHint(isExpanded ? "Collapse section" : "Expand to load section")
    }
}
