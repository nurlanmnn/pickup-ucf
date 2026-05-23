import SwiftUI

/// Form row: leading label, trailing numeric field + stepper. Prevents `TextField` from expanding and
/// crowding the stepper (which made +/− hard to tap) inside `Form` / list layouts.
struct StepperNumberFieldRow<Focus: Hashable>: View {
    let title: String
    let prompt: String
    @Binding var text: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    var fieldWidth: CGFloat = 72
    var focus: FocusState<Focus>.Binding
    var focusValue: Focus

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.m) {
            Text(title)
                .font(AppFont.body())
                .foregroundStyle(AppColor.textPrimary(colorScheme))

            Spacer(minLength: Spacing.s)

            HStack(spacing: Spacing.s) {
                TextField(
                    "",
                    text: digitsOnlyBinding($text),
                    prompt: Text(prompt)
                        .foregroundStyle(AppColor.textSecondary(colorScheme).opacity(0.75))
                )
                .keyboardType(.numberPad)
                .focused(focus, equals: focusValue)
                .multilineTextAlignment(.trailing)
                .frame(width: fieldWidth, alignment: .trailing)

                Stepper("", value: $value, in: range, step: step)
                    .labelsHidden()
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .onChange(of: value) { _, newValue in
            text = "\(newValue)"
        }
    }

    private func digitsOnlyBinding(_ source: Binding<String>) -> Binding<String> {
        Binding(
            get: { source.wrappedValue },
            set: { newValue in
                let digits = newValue.filter(\.isNumber)
                if digits != source.wrappedValue {
                    source.wrappedValue = digits
                }
            }
        )
    }
}
