import SwiftUI

struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: Spacing.m) {
            Image(systemName: symbol)
                .font(.system(size: 48))
                .foregroundStyle(AppColor.gold)
            Text(title)
                .font(AppFont.title())
                .foregroundStyle(AppColor.textPrimary(colorScheme))
                .multilineTextAlignment(.center)
            Text(message)
                .font(AppFont.body())
                .foregroundStyle(AppColor.textSecondary(colorScheme))
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                PrimaryButton(title: actionTitle, action: action)
                    .frame(maxWidth: 280)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.xl)
    }
}
