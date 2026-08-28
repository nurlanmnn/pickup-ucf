import Foundation

enum CreateSessionScrollAnchor: String, Hashable {
    case sport
    case schedule
    case location
    case customLocationMap
}

enum CreateSessionStep: Int, CaseIterable, Identifiable {
    case sportAndTime = 0
    case location = 1
    case details = 2

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .sportAndTime: return "Sport & time"
        case .location: return "Location"
        case .details: return "Details"
        }
    }

    var next: CreateSessionStep? {
        CreateSessionStep(rawValue: rawValue + 1)
    }

    var previous: CreateSessionStep? {
        CreateSessionStep(rawValue: rawValue - 1)
    }

    func accessibilityLabel(isCurrent: Bool) -> String {
        if isCurrent {
            return "Step \(rawValue + 1) of \(CreateSessionStep.allCases.count), \(title), current step"
        }
        return "Step \(rawValue + 1) of \(CreateSessionStep.allCases.count), \(title)"
    }
}
