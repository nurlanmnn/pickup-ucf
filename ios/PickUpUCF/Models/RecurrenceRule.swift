import Foundation

struct RecurrenceRule: Codable, Equatable {
    enum Frequency: String, Codable {
        case weekly
    }

    let frequency: Frequency
    let count: Int

    static func weekly(count: Int) -> RecurrenceRule {
        RecurrenceRule(frequency: .weekly, count: min(4, max(2, count)))
    }

    var jsonString: String {
        get throws {
            let data = try JSONEncoder().encode(self)
            guard let string = String(data: data, encoding: .utf8) else {
                throw RecurrenceRuleError.encodingFailed
            }
            return string
        }
    }
}

enum RecurrenceRuleError: Error {
    case encodingFailed
}
