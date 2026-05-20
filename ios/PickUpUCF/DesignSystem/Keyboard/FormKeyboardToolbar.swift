import SwiftUI

struct FormKeyboardToolbar: ToolbarContent {
    var canGoPrevious: Bool = false
    var canGoNext: Bool = false
    var onPrevious: () -> Void = {}
    var onNext: () -> Void = {}
    var onDone: () -> Void = {}

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .keyboard) {
            Button("Previous", action: onPrevious)
                .disabled(!canGoPrevious)
                .accessibilityLabel("Previous field")
            Button("Next", action: onNext)
                .disabled(!canGoNext)
                .accessibilityLabel("Next field")
            Spacer()
            Button("Done", action: onDone)
                .fontWeight(.semibold)
                .accessibilityLabel("Done")
        }
    }
}
