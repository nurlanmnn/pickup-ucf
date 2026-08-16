import SwiftUI

private struct StaggeredAppearModifier: ViewModifier {
    let index: Int
    var perItemDelay: Double = 0.05
    var maxDelay: Double = 0.25

    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 12)
            .onAppear {
                let delay = min(Double(index) * perItemDelay, maxDelay)
                withAnimation(.easeOut(duration: 0.32).delay(delay)) {
                    isVisible = true
                }
            }
    }
}

extension View {
    func staggeredAppear(index: Int) -> some View {
        modifier(StaggeredAppearModifier(index: index))
    }
}
