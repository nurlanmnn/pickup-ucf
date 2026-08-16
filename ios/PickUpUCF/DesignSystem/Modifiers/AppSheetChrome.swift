import SwiftUI

extension View {
    /// Shared sheet chrome: visible drag indicator and 20pt corners.
    func appSheetChrome(detents: Set<PresentationDetent> = [.large]) -> some View {
        self
            .presentationDetents(detents)
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(20)
    }
}
