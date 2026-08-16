import SwiftUI

/// ButtonStyle for `NavigationLink` wrappers around `SessionCard`.
/// Handles scale + sport-accent shadow on press without stealing the tap gesture.
struct GameCardButtonStyle: ButtonStyle {
    var sport: SportType

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .shadow(
                color: configuration.isPressed
                    ? AppColor.sportAccent(sport).opacity(0.20)
                    : Color.clear,
                radius: configuration.isPressed ? 10 : 0,
                x: 0, y: 3
            )
            .animation(.spring(duration: 0.22, bounce: 0.25), value: configuration.isPressed)
    }
}
