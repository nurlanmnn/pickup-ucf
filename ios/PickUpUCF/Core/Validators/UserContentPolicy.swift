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
            "Use no more than \(maximum) characters."
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
        guard !containsDisallowedControlCharacter(rawValue) else { throw UserContentPolicyError.prohibited }
        let normalized = normalize(rawValue)
        guard !normalized.isEmpty else { throw UserContentPolicyError.required }
        guard normalized.unicodeScalars.count <= field.maximumLength else {
            throw UserContentPolicyError.tooLong(maximum: field.maximumLength)
        }
        guard !containsProhibitedContent(normalized) else {
            throw UserContentPolicyError.prohibited
        }
        return normalized
    }

    static func validateOptional(_ rawValue: String?, field: UserContentField) throws -> String? {
        guard let rawValue else { return nil }
        guard !containsDisallowedControlCharacter(rawValue) else { throw UserContentPolicyError.prohibited }
        guard !normalize(rawValue).isEmpty else { return nil }
        return try validate(rawValue, field: field)
    }

    // Explicit White_Space set shared with PostgreSQL; forbidden C0/C1 controls
    // are checked before whitespace is collapsed. NFC keeps equivalent accents equal.
    private static let whitespace = CharacterSet(charactersIn:
        "\t\n\r \u{00A0}\u{1680}\u{2000}\u{2001}\u{2002}\u{2003}\u{2004}\u{2005}\u{2006}\u{2007}\u{2008}\u{2009}\u{200A}\u{2028}\u{2029}\u{202F}\u{205F}\u{3000}"
    )

    static func normalize(_ value: String) -> String {
        value.precomposedStringWithCanonicalMapping
            .components(separatedBy: whitespace)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    static func length(_ value: String) -> Int {
        normalize(value).unicodeScalars.count
    }

    static func validationMessage(_ value: String, field: UserContentField, optional: Bool = false) -> String? {
        do {
            if optional { _ = try validateOptional(value, field: field) }
            else { _ = try validate(value, field: field) }
            return nil
        } catch {
            return AppErrorMapper.message(for: error)
        }
    }

    private static func containsDisallowedControlCharacter(_ value: String) -> Bool {
        value.unicodeScalars.contains { scalar in
            (scalar.value < 32 || (127...159).contains(scalar.value))
                && scalar != "\n" && scalar != "\r" && scalar != "\t"
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
