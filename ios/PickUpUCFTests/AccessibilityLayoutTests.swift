import SwiftUI
import XCTest
@testable import PickUpUCF

final class AccessibilityLayoutTests: XCTestCase {
    func testCustomControlsMeetMinimumTouchTarget() {
        XCTAssertGreaterThanOrEqual(AccessibilityLayout.minimumTouchTarget, 44)
    }

    func testPrimaryControlsHaveVerticalGrowthPadding() {
        XCTAssertGreaterThanOrEqual(AccessibilityLayout.controlVerticalPadding, 8)
    }

    func testStandardContentSizesPreferHorizontalActions() {
        let standardSizes: [DynamicTypeSize] = [
            .xSmall, .small, .medium, .large, .xLarge, .xxLarge, .xxxLarge,
        ]

        XCTAssertTrue(standardSizes.allSatisfy { !AccessibilityLayout.usesVerticalActions(at: $0) })
    }

    func testAccessibilityContentSizesUseVerticalActions() {
        let accessibilitySizes: [DynamicTypeSize] = [
            .accessibility1, .accessibility2, .accessibility3, .accessibility4, .accessibility5,
        ]

        XCTAssertTrue(accessibilitySizes.allSatisfy(AccessibilityLayout.usesVerticalActions))
    }
}
