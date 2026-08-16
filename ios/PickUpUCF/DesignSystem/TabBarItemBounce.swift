import UIKit

enum TabBarItemBounce {
    static func bounceItem(at index: Int) {
        DispatchQueue.main.async {
            guard let tabBar = findTabBar(),
                  let item = tabBarButton(at: index, in: tabBar) else { return }

            item.transform = CGAffineTransform(scaleX: 0.82, y: 0.82)
            UIView.animate(springDuration: 0.42, bounce: 0.45) {
                item.transform = .identity
            }
        }
    }

    private static func tabBarButton(at index: Int, in tabBar: UITabBar) -> UIView? {
        let buttons = tabBar.subviews
            .filter { $0 is UIControl }
            .sorted { $0.frame.minX < $1.frame.minX }
        guard index >= 0, index < buttons.count else { return nil }
        return buttons[index]
    }

    private static func findTabBar() -> UITabBar? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        guard let window = scene?.windows.first(where: \.isKeyWindow) ?? scene?.windows.first else {
            return nil
        }
        return findTabBar(in: window)
    }

    private static func findTabBar(in view: UIView) -> UITabBar? {
        if let tabBar = view as? UITabBar { return tabBar }
        for subview in view.subviews {
            if let found = findTabBar(in: subview) { return found }
        }
        return nil
    }
}
