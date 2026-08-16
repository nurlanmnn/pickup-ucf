import SwiftUI

/// A single row in a settings card group.
/// Use inside a `SettingsCardGroup` for consistent grouped styling.
struct SettingsRow: View {
    let systemImage: String
    let iconColor: Color
    let title: String
    var isDestructive: Bool = false

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(isDestructive ? AppColor.destructive : iconColor)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            Text(title)
                .font(AppFont.body())
                .foregroundStyle(
                    isDestructive ? AppColor.destructive : AppColor.textPrimary(colorScheme)
                )

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppColor.textSecondary(colorScheme).opacity(0.55))
        }
        .padding(.vertical, Spacing.s + 2)
        .contentShape(Rectangle())
    }
}

/// Wraps a list of settings rows in an elevated card with dividers.
struct SettingsCardGroup<Content: View>: View {
    var label: String? = nil
    @ViewBuilder var content: Content

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let label {
                Text(label)
                    .font(AppFont.caption(.semibold))
                    .foregroundStyle(AppColor.textSecondary(colorScheme))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .padding(.horizontal, Spacing.xs)
                    .padding(.bottom, Spacing.xs)
            }

            VStack(spacing: 0) {
                content
            }
            .padding(.horizontal, Spacing.m)
            .background(AppColor.elevatedSurface(colorScheme))
            .appCardStyle(cornerRadius: 16)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        SettingsCardGroup(label: "Account") {
            SettingsRow(systemImage: "sportscourt.fill", iconColor: .blue, title: "Edit sports")
            Divider().padding(.leading, 46)
            SettingsRow(systemImage: "at", iconColor: .blue, title: "Edit username")
            Divider().padding(.leading, 46)
            SettingsRow(systemImage: "lock.fill", iconColor: .orange, title: "Change password")
        }
        SettingsCardGroup {
            SettingsRow(systemImage: "trash.fill", iconColor: .red, title: "Delete account", isDestructive: true)
        }
    }
    .padding()
}
