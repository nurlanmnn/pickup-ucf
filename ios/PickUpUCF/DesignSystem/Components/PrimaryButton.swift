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
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .foregroundStyle(.black)
            .background(isEnabled && !isLoading ? AppColor.gold : AppColor.gold.opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .disabled(!isEnabled || isLoading)
        .accessibilityLabel(title)
    }
}

#Preview {
    PrimaryButton(title: "Join game", action: {})
        .padding()
}
