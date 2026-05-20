import Foundation

enum SessionDateFormatter {
    private static let campusTimeZone = TimeZone(identifier: "America/New_York")!

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeZone = campusTimeZone
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeZone = campusTimeZone
        formatter.dateFormat = "EEEE"
        return formatter
    }()

    static func cardLabel(for date: Date, relativeTo now: Date = .now) -> String {
        var calendar = Calendar.current
        calendar.timeZone = campusTimeZone

        if calendar.isDateInToday(date) {
            return "Today · \(timeFormatter.string(from: date))"
        }
        if calendar.isDateInTomorrow(date) {
            return "Tomorrow · \(timeFormatter.string(from: date))"
        }
        let day = weekdayFormatter.string(from: date)
        return "\(day) · \(timeFormatter.string(from: date))"
    }
}
