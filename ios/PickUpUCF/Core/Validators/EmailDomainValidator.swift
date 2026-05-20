import Foundation

enum EmailDomainValidator {
    private static let allowedSuffixes = ["@ucf.edu", "@knights.ucf.edu"]

    static func isUCFEmail(_ email: String) -> Bool {
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return allowedSuffixes.contains { normalized.hasSuffix($0) }
    }

    static func validationMessage(for email: String) -> String? {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Email is required" }
        guard trimmed.contains("@") else { return "Enter a valid email address" }
        guard isUCFEmail(trimmed) else {
            return "Use your @knights.ucf.edu or @ucf.edu email"
        }
        return nil
    }
}
