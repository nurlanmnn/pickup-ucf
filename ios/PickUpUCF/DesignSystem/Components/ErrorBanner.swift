import SwiftUI

struct ErrorBanner: View {
    enum Tone {
        /// User-visible fault, validation, or hard failure.
        case critical
        /// Server / configuration hints (e.g. migrations) — less alarming than a red error.
        case warning
    }

    let message: String
    var tone: Tone = .critical
    var onDismiss: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.s) {
            Image(systemName: tone == .critical ? "exclamationmark.triangle.fill" : "exclamationmark.circle.fill")
                .font(AppFont.caption(.semibold))
                .foregroundStyle(tone == .critical ? AppColor.destructive : AppColor.goldDark)
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
                .accessibilityLabel("Dismiss error")
            }
        }
        .padding(Spacing.m)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(backgroundFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(borderStroke, lineWidth: 1)
        )
    }

    private var backgroundFill: Color {
        switch tone {
        case .critical:
            return AppColor.destructive.opacity(colorScheme == .dark ? 0.16 : 0.09)
        case .warning:
            return AppColor.gold.opacity(colorScheme == .dark ? 0.14 : 0.12)
        }
    }

    private var borderStroke: Color {
        switch tone {
        case .critical:
            return AppColor.destructive.opacity(0.28)
        case .warning:
            return AppColor.gold.opacity(0.45)
        }
    }
}
