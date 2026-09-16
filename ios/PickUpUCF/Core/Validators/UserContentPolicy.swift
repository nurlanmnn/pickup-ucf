import Foundation

enum UserContentField {
    case displayName
    case sessionNotes
    case customSport
    case customLocation
    case chatMessage
    case reportContext

    var maximumLength: Int {
        switch self {
        case .displayName: 80
        case .sessionNotes: 1_000
        case .customSport: 40
        case .customLocation: 120
        case .chatMessage, .reportContext: 500
        }
    }
}

enum UserContentPolicyError: LocalizedError {
    case required
    case tooLong(maximum: Int)
    case prohibited

    var errorDescription: String? {
        switch self {
        case .required:
            "Enter text before continuing."
        case .tooLong(let maximum):
            "Keep this text under \(maximum) characters."
        case .prohibited:
            "This text may violate the community rules. Edit it and try again."
        }
    }
}

enum UserContentPolicy {
    private static let foldedProhibitedPatterns = [
        #"\b(i|we)\s+(will|am going to|are going to|gonna)\s+(kill|hurt|shoot|stab)\s+(you|u|him|her|them)\b"#,
        #"\b(send|show)\s+(me\s+)?(nudes?|explicit\s+photos?)\b"#,
        #"\b(n[i1]gg+[e3]r|f[a@]gg+[o0]t|k[i1]k[e3])s?\b"#,
    ]

    private static let literalProhibitedPatterns = [
        #"https?://|www\."#,
        #"\b(text|call)\s+me\s+(at\s+)?\+?\d[\d\s().-]{8,}\d\b"#,
    ]

    static func validate(_ rawValue: String, field: UserContentField) throws -> String {
        let normalized = normalize(rawValue)
        guard !normalized.isEmpty else { throw UserContentPolicyError.required }
        guard normalized.count <= field.maximumLength else {
            throw UserContentPolicyError.tooLong(maximum: field.maximumLength)
        }
        guard !containsDisallowedControlCharacter(rawValue), !containsProhibitedContent(normalized) else {
            throw UserContentPolicyError.prohibited
        }
        return normalized
    }

    static func validateOptional(_ rawValue: String?, field: UserContentField) throws -> String? {
        guard let rawValue else { return nil }
        let normalized = normalize(rawValue)
        guard !normalized.isEmpty else { return nil }
        return try validate(normalized, field: field)
    }

    static func normalize(_ value: String) -> String {
        value
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func containsDisallowedControlCharacter(_ value: String) -> Bool {
        value.unicodeScalars.contains { scalar in
            CharacterSet.controlCharacters.contains(scalar)
                && scalar != "\n"
                && scalar != "\r"
                && scalar != "\t"
        }
    }

    private static func containsProhibitedContent(_ value: String) -> Bool {
        let folded = value.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .replacingOccurrences(of: "1", with: "i")
            .replacingOccurrences(of: "3", with: "e")
            .replacingOccurrences(of: "0", with: "o")

        let literal = value.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: .current
        )

        return foldedProhibitedPatterns.contains { pattern in
            folded.range(of: pattern, options: .regularExpression) != nil
        } || literalProhibitedPatterns.contains { pattern in
            literal.range(of: pattern, options: .regularExpression) != nil
        }
    }
}
