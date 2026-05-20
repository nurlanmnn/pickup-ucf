import Foundation

/// When `custom_sport_name` is not deployed yet, we store the "Other" sport label at the start of `notes`.
enum OtherSportNotes {
    private static let opener = "[[OTHER_SPORT="
    private static let closer = "]]"

    static func sanitizedName(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "]", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Packs the display name for `.other` into `notes` (legacy / no-migration path).
    static func composedNotes(sport: SportType, customOtherName: String?, userNotes: String?) -> String? {
        guard sport == .other else {
            return userNotesStrippingEmbeddedTag(userNotes)
        }
        let user = userNotesStrippingEmbeddedTag(userNotes)
        let trimmed = customOtherName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return user }
        let safe = sanitizedName(trimmed)
        guard !safe.isEmpty else { return user }
        let tag = "\(opener)\(safe)\(closer)"
        guard let user, !user.isEmpty else { return tag }
        return "\(tag)\n\n\(user)"
    }

    /// Notes text without a leading `[[OTHER_SPORT=…]]` block (e.g. after switching away from Other).
    private static func userNotesStrippingEmbeddedTag(_ userNotes: String?) -> String? {
        guard let raw = userNotes?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        let parsed = parse(raw)
        if parsed.embeddedName != nil {
            return parsed.userNotes.flatMap { $0.isEmpty ? nil : $0 }
        }
        return raw
    }

    static func parse(_ notes: String?) -> (embeddedName: String?, userNotes: String?) {
        guard let raw = notes?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return (nil, nil)
        }
        guard raw.hasPrefix(opener) else { return (nil, raw) }
        guard let end = raw.range(of: closer) else { return (nil, raw) }
        let inner = String(raw[opener.endIndex ..< end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        let after = raw[end.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
        return (inner.nilIfEmpty, after.nilIfEmpty)
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
