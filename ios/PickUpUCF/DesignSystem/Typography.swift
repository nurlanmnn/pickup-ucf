import SwiftUI

enum AppFont {
    /// 34pt rounded bold — screen hero titles (splash screens, empty states, step headers).
    static func display(_ weight: Font.Weight = .bold) -> Font {
        .system(size: 34, weight: weight, design: .rounded)
    }

    /// Maps to `.largeTitle` — nav bar large title, welcome headline.
    static func largeTitle(_ weight: Font.Weight = .bold) -> Font {
        .system(.largeTitle, design: .rounded, weight: weight)
    }

    /// Maps to `.title2` (rounded) — section headers, sheet titles.
    static func title(_ weight: Font.Weight = .semibold) -> Font {
        .system(.title2, design: .rounded, weight: weight)
    }

    /// Maps to `.headline` (rounded) — card primary lines, list row titles.
    static func headline(_ weight: Font.Weight = .semibold) -> Font {
        .system(.headline, design: .rounded, weight: weight)
    }

    static func body(_ weight: Font.Weight = .regular) -> Font {
        .system(.body, design: .default, weight: weight)
    }

    /// Maps to `.caption` (rounded) — timestamps, badges, secondary metadata.
    static func caption(_ weight: Font.Weight = .regular) -> Font {
        .system(.caption, design: .rounded, weight: weight)
    }

    /// Maps to `.caption2` (rounded) — smallest helper text, fine print.
    static func caption2(_ weight: Font.Weight = .regular) -> Font {
        .system(.caption2, design: .rounded, weight: weight)
    }
}
