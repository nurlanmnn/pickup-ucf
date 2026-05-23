import SwiftUI

struct SecondaryButton: View {
    enum Variant {
        /// Adapts to system light/dark (forms, settings).
        case adaptive
        /// White label on dark backgrounds (welcome / marketing).
        case onDark
    }

    let title: String
    var variant: Variant = .adaptive
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.headline(.semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .foregroundStyle(foregroundColor)
                .background(backgroundFill)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppColor.gold, lineWidth: 2)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .accessibilityLabel(title)
    }

    private var foregroundColor: Color {
        switch variant {
        case .adaptive:
            return AppColor.textPrimary(colorScheme)
        case .onDark:
            return .white
        }
    }

    private var backgroundFill: Color {
        switch variant {
        case .adaptive:
            return Color.clear
        case .onDark:
            return Color.white.opacity(0.08)
        }
    }
}

#Preview("Adaptive") {
    SecondaryButton(title: "Sign In", action: {})
        .padding()
}

#Preview("On dark") {
    ZStack {
        Color.black.ignoresSafeArea()
        SecondaryButton(title: "Sign In", variant: .onDark, action: {})
            .padding()
    }
}
