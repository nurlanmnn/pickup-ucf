import SwiftUI

enum AppFont {
    /// 34pt system bold — screen hero titles (splash screens, empty states, step headers).
    static func display(_ weight: Font.Weight = .bold) -> Font {
        .system(.largeTitle, design: .default, weight: weight)
    }

    /// Maps to `.largeTitle` — nav bar large title, welcome headline.
    static func largeTitle(_ weight: Font.Weight = .bold) -> Font {
        .system(.largeTitle, design: .default, weight: weight)
    }

    /// Maps to `.title2` (system) — section headers, sheet titles.
    static func title(_ weight: Font.Weight = .semibold) -> Font {
        .system(.title2, design: .default, weight: weight)
    }

    /// Maps to `.headline` (system) — card primary lines, list row titles.
    static func headline(_ weight: Font.Weight = .semibold) -> Font {
        .system(.headline, design: .default, weight: weight)
    }

    static func body(_ weight: Font.Weight = .regular) -> Font {
        .system(.body, design: .default, weight: weight)
    }

    /// Maps to `.caption` (system) — timestamps, badges, secondary metadata.
    static func caption(_ weight: Font.Weight = .regular) -> Font {
        .system(.caption, design: .default, weight: weight)
    }

    /// Maps to `.caption2` (system) — smallest helper text, fine print.
    static func caption2(_ weight: Font.Weight = .regular) -> Font {
        .system(.caption2, design: .default, weight: weight)
    }
}
