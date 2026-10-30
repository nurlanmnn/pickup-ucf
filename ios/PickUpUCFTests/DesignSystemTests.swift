import XCTest
import SwiftUI
@testable import PickUpUCF

@MainActor
final class DesignSystemTests: XCTestCase {
    func testBodyTextAndActionContrastInBothAppearances() {
        for scheme in [ColorScheme.light, .dark] {
            for surface in [AppColor.background(scheme), AppColor.surface(scheme), AppColor.mutedSurface(scheme)] {
                for text in [AppColor.textPrimary(scheme), AppColor.textSecondary(scheme), AppColor.accent(scheme)] {
                    XCTAssertGreaterThanOrEqual(contrast(text, surface), 4.5, "Readable body text in \(scheme)")
                }
            }
        }
        XCTAssertGreaterThanOrEqual(contrast(.black, AppColor.gold), 4.5)
        XCTAssertGreaterThanOrEqual(contrast(.white, AppTheme.badgeSoon(.light)), 4.5)
        XCTAssertGreaterThanOrEqual(contrast(.white, AppTheme.badgeSoon(.dark)), 4.5)
    }

    /// Attach native renders so the shared design can be inspected without a real account.
    func testSharedSurfacesAtCompactAndAccessibleSizes() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousWindow = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        defer { window.isHidden = true; window.rootViewController = nil; previousWindow?.makeKey() }
        let session = PickupSession(
            id: UUID(), hostId: UUID(), sport: .basketball,
            customLocation: "Recreation and Wellness Center", startsAt: .now.addingTimeInterval(3600),
            endsAt: .now.addingTimeInterval(7200), capacity: 10, playerCount: 6,
            skillLevel: .any, status: .open
        )
        for (name, width, scheme, typeSize) in [
            ("compact-light", 320.0, ColorScheme.light, DynamicTypeSize.large),
            ("phone-light", 402.0, .light, .large),
            ("phone-dark", 402.0, .dark, .large),
            ("accessible", 402.0, .light, .accessibility5)
        ] {
            let host = UIHostingController(rootView:
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.l) {
                        SessionWeatherView(weather: WeatherSnapshot(
                            summary: "Clear", tempF: 82, precipPct: 30, fetchedAt: .now
                        ))
                        AuthHeaderView(title: "Find your next game", subtitle: "A little time outside. A few new faces.")
                        SessionCard(session: session, onJoin: {})
                        FormCard(label: "Your details") {
                            FormFieldRow { TextField("UCF email", text: .constant("")) }
                        }
                        SportPickerGrid(selectedSports: [.basketball, .tennis], onToggle: { _ in })
                        SettingsCardGroup(label: "Account") {
                            SettingsRow(systemImage: "at", iconColor: .blue, title: "Edit username")
                        }
                        PrimaryButton(title: "Continue", action: {})
                        SecondaryButton(title: "Go back", action: {})
                    }
                    .padding(Spacing.l)
                }
                .appScreenBackground()
                .environment(\.colorScheme, scheme)
                .environment(\.dynamicTypeSize, typeSize)
            )
            window.frame = CGRect(x: 0, y: 0, width: width, height: 874)
            window.rootViewController = host
            window.makeKeyAndVisible()
            host.view.setNeedsLayout()
            host.view.layoutIfNeeded()
            try await Task.sleep(for: .milliseconds(350))
            host.view.layoutIfNeeded()
            let image = UIGraphicsImageRenderer(bounds: host.view.bounds).image { _ in
                host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
            }
            let attachment = XCTAttachment(image: image)
            attachment.name = "UI refresh \(name)"
            attachment.lifetime = .keepAlways
            add(attachment)
            for scroll in scrollViews(in: host.view) where scroll.bounds.width > 0 {
                XCTAssertLessThanOrEqual(scroll.contentSize.width, scroll.bounds.width + 1,
                                         "No horizontal overflow at \(name)")
            }
        }
    }

    private func scrollViews(in view: UIView) -> [UIScrollView] {
        ((view as? UIScrollView).map { [$0] } ?? []) + view.subviews.flatMap { scrollViews(in: $0) }
    }

    private func contrast(_ first: Color, _ second: Color) -> Double {
        let values = [first, second].map { color -> Double in
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
            let linear = [r, g, b].map { value -> Double in
                let v = Double(value)
                return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
            }
            return linear[0] * 0.2126 + linear[1] * 0.7152 + linear[2] * 0.0722
        }
        return (max(values[0], values[1]) + 0.05) / (min(values[0], values[1]) + 0.05)
    }
}
