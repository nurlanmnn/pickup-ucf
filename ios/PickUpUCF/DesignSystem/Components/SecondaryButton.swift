import SwiftUI

struct SecondaryButton: View {
    let title: String
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.headline(.semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .foregroundStyle(AppColor.textPrimary(colorScheme))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppColor.gold, lineWidth: 2)
                }
        }
        .accessibilityLabel(title)
    }
}

#Preview {
    SecondaryButton(title: "Sign In", action: {})
        .padding()
}
