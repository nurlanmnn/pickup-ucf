import SwiftUI

struct KeyboardDismissModifier: ViewModifier {
    @FocusState.Binding var focusedField: Bool?

    func body(content: Content) -> some View {
        content
            .onTapGesture {
                focusedField = nil
            }
    }
}

extension View {
    func dismissKeyboardOnTap(focused: FocusState<Bool?>.Binding) -> some View {
        modifier(KeyboardDismissModifier(focusedField: focused))
    }

    func dismissKeyboardOnBackgroundTap() -> some View {
        simultaneousGesture(
            TapGesture().onEnded { _ in
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil,
                    from: nil,
                    for: nil
                )
            }
        )
    }
}
