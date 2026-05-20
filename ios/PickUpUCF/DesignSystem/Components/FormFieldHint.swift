import SwiftUI

/// Subtle helper copy under form fields (not an error).
struct FormFieldHint: View {
    let text: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(text)
            .font(AppFont.caption())
            .foregroundStyle(AppColor.textSecondary(colorScheme).opacity(0.88))
            .fixedSize(horizontal: false, vertical: true)
    }
}
