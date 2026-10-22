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

/// Counts normalized Unicode code points, matching the database limit.
struct ContentFieldFeedback: View {
    let value: String
    let field: UserContentField
    var optional = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            FormFieldHint(text: "\(UserContentPolicy.length(value))/\(field.maximumLength) characters")
                .accessibilityHint("Emoji may count as several characters.")
            if !value.isEmpty, let message = UserContentPolicy.validationMessage(value, field: field, optional: optional) {
                FieldErrorLabel(message: message)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
