import SwiftUI

struct PrimaryButton: View {
    let title: String
    var isLoading: Bool = false
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.s) {
                if isLoading {
                    ProgressView()
                        .tint(.black)
                }
                Text(title)
                    .font(AppFont.headline(.semibold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, AccessibilityLayout.controlVerticalPadding)
            .frame(minHeight: AccessibilityLayout.minimumTouchTarget)
            .foregroundStyle(.black)
            .background(isEnabled && !isLoading ? AppColor.gold : AppColor.gold.opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .disabled(!isEnabled || isLoading)
        .accessibilityLabel(title)
        .accessibilityIdentifier("primary-button-\(title)")
    }
}

#Preview {
    PrimaryButton(title: "Join game", action: {})
        .padding()
}
