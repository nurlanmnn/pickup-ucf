import SwiftUI

struct SuccessBanner: View {
    let message: String
    var onDismiss: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.s) {
            Image(systemName: "checkmark.circle.fill")
                .font(AppFont.caption(.semibold))
                .foregroundStyle(AppColor.success)
                .accessibilityHidden(true)

            Text(message)
                .font(AppFont.caption())
                .foregroundStyle(AppColor.textPrimary(colorScheme))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body.weight(.medium))
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppColor.textSecondary(colorScheme))
                .accessibilityLabel("Dismiss message")
            }
        }
        .padding(Spacing.m)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppColor.success.opacity(colorScheme == .dark ? 0.16 : 0.09))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppColor.success.opacity(0.28), lineWidth: 1)
        )
    }
}
