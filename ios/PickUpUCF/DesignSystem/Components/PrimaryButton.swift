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
        .buttonStyle(AppPressStyle())
        .disabled(!isEnabled || isLoading)
        .accessibilityLabel(title)
        .accessibilityIdentifier("primary-button-\(title)")
    }
}

#Preview {
    PrimaryButton(title: "Join game", action: {})
        .padding()
}

/// Shared, subtle touch feedback. No animation when Reduce Motion is enabled.
struct AppPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.86 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: configuration.isPressed)
    }
}
