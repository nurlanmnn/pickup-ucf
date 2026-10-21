import SwiftUI

/// Shared editorial header for every account flow.
struct AuthHeaderView: View {
    let title: String
    var subtitle: String? = nil
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            AppBrandLockup()
                .padding(.bottom, Spacing.m)
            Text(title)
                .font(AppFont.display())
                .tracking(-1)
                .foregroundStyle(AppColor.textPrimary(colorScheme))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(subtitle)
                    .font(AppFont.body())
                    .foregroundStyle(AppColor.textSecondary(colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Spacing.l)
        .padding(.bottom, Spacing.m)
    }
}

/// The original PickUp logo, reused unchanged from the app icon artwork.
struct AppBrandLockup: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: Spacing.s) {
            Image("BrandLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityHidden(true)
            Text("PickUp")
                .font(AppFont.title(.bold))
                .tracking(-0.8)
                .foregroundStyle(AppColor.textPrimary(colorScheme))
            Text("UCF")
                .font(AppFont.caption2(.bold))
                .foregroundStyle(AppColor.textSecondary(colorScheme))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("PickUp UCF")
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}

/// A full touch target that wraps naturally with larger text.
struct AuthSwitchLink: View {
    let prompt: String
    let title: String
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            (Text(prompt + " ").foregroundColor(AppColor.textSecondary(colorScheme))
             + Text(title).bold().underline())
                .font(AppFont.body())
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: AccessibilityLayout.minimumTouchTarget)
        }
        .buttonStyle(AppPressStyle())
        .accessibilityLabel(prompt + " " + title)
    }
}
