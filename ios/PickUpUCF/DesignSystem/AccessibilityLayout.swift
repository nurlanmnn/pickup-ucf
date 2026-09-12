import SwiftUI

enum AccessibilityLayout {
    static let minimumTouchTarget: CGFloat = 44
    static let controlVerticalPadding: CGFloat = 12

    static func usesVerticalActions(at size: DynamicTypeSize) -> Bool {
        size.isAccessibilitySize
    }
}
