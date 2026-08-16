import Foundation

enum DiscoverTimeWindow: String, CaseIterable, Identifiable {
    case next48h
    case today
    case thisWeekend

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .next48h: return "Next 48 hours"
        case .today: return "Today"
        case .thisWeekend: return "This weekend"
        }
    }

    /// Short label for compact filter chips.
    var chipLabel: String {
        switch self {
        case .next48h: return "48 hours"
        case .today: return "Today"
        case .thisWeekend: return "Weekend"
        }
    }

    static var campusCalendar: Calendar {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }

    /// Whether `date` falls inside this window relative to `now` (campus timezone).
    func contains(_ date: Date, relativeTo now: Date = .now, calendar: Calendar = campusCalendar) -> Bool {
        let range = queryRange(relativeTo: now, calendar: calendar)
        return date >= range.lowerBound && date <= range.upperBound
    }

    /// Bounds for server-side `starts_at` filtering.
    func queryRange(relativeTo now: Date = .now, calendar: Calendar = campusCalendar) -> ClosedRange<Date> {
        switch self {
        case .next48h:
            let end = calendar.date(byAdding: .hour, value: 48, to: now) ?? now
            return now...end
        case .today:
            let start = calendar.startOfDay(for: now)
            let end = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: start) ?? start
            return start...end
        case .thisWeekend:
            return Self.weekendRange(relativeTo: now, calendar: calendar)
        }
    }

    private static func weekendRange(relativeTo now: Date, calendar: Calendar) -> ClosedRange<Date> {
        let weekday = calendar.component(.weekday, from: now)
        let todayStart = calendar.startOfDay(for: now)

        let saturdayStart: Date
        switch weekday {
        case 7: // Saturday
            saturdayStart = todayStart
        case 1: // Sunday — same weekend as yesterday
            saturdayStart = calendar.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart
        default:
            let daysUntilSaturday = 7 - weekday
            saturdayStart = calendar.date(byAdding: .day, value: daysUntilSaturday, to: todayStart) ?? todayStart
        }

        let sundayStart = calendar.date(byAdding: .day, value: 1, to: saturdayStart) ?? saturdayStart
        let sundayEnd = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: sundayStart) ?? sundayStart
        return saturdayStart...sundayEnd
    }
}
