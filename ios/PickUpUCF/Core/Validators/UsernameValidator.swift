import Foundation

enum UsernameValidator {
    private static let pattern = #"^[a-z0-9_]{3,20}$"#
    private static let reserved: Set<String> = ["admin", "ucf", "pickup", "support", "help"]

    static func normalized(_ input: String) -> String {
        input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func validationMessage(for username: String) -> String? {
        let value = normalized(username)
        guard !value.isEmpty else { return "Username is required" }
        guard value.range(of: pattern, options: .regularExpression) != nil else {
            return "Use 3–20 characters: letters, numbers, underscore"
        }
        guard !reserved.contains(value) else { return "This username is not available" }
        return nil
    }
}
