import SwiftUI

struct FieldErrorLabel: View {
    let message: String

    var body: some View {
        Text(message)
            .font(AppFont.caption())
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(AppColor.destructive)
            .accessibilityLabel("Error: \(message)")
    }

    /// Inset to match `FormFieldRow` padding inside a `FormCard`.
    func formCardInset() -> some View {
        padding(.horizontal, Spacing.m)
            .padding(.bottom, Spacing.xs)
    }
}
