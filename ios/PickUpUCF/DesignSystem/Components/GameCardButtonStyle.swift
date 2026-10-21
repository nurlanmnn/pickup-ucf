import SwiftUI

/// ButtonStyle for `NavigationLink` wrappers around `SessionCard`.
/// Uses the same restrained press feedback as other controls.
struct GameCardButtonStyle: ButtonStyle {
    var sport: SportType
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.9 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: configuration.isPressed)
    }
}
