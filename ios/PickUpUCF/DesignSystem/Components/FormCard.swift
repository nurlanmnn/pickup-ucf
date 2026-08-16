import SwiftUI

/// Wraps form fields in an elevated card — consistent with `SettingsCardGroup`.
/// Place `FormFieldRow` children inside for proper padding + dividers.
struct FormCard<Content: View>: View {
    var label: String? = nil
    var footer: String? = nil
    @ViewBuilder var content: Content

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            if let label {
                Text(label)
                    .font(AppFont.caption(.semibold))
                    .foregroundStyle(AppColor.textSecondary(colorScheme))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .padding(.horizontal, Spacing.xs)
            }

            VStack(spacing: 0) {
                content
            }
            .background(AppColor.elevatedSurface(colorScheme))
            .appCardStyle(cornerRadius: 16)

            if let footer {
                Text(footer)
                    .font(AppFont.caption())
                    .foregroundStyle(AppColor.textSecondary(colorScheme))
                    .padding(.horizontal, Spacing.xs)
            }
        }
    }
}

/// A single field row inside a `FormCard` — handles horizontal + vertical padding.
struct FormFieldRow<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, 12)
    }
}
