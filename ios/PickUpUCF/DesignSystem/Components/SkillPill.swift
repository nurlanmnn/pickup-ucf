import SwiftUI

struct SkillPill: View {
    let skill: SkillLevel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(skill.displayName)
            .font(AppFont.caption(.semibold))
            .padding(.horizontal, Spacing.s)
            .padding(.vertical, 4)
            .background(AppColor.surface(colorScheme).opacity(colorScheme == .dark ? 0.9 : 1))
            .overlay {
                Capsule().stroke(AppColor.textSecondary(colorScheme).opacity(0.25), lineWidth: 1)
            }
            .clipShape(Capsule())
            .foregroundStyle(AppColor.textSecondary(colorScheme))
    }
}
