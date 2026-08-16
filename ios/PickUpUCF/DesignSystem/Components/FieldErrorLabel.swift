import SwiftUI

struct FieldErrorLabel: View {
    let message: String

    var body: some View {
        Text(message)
            .font(AppFont.caption())
            .foregroundStyle(AppColor.destructive)
            .accessibilityLabel("Error: \(message)")
    }
}
