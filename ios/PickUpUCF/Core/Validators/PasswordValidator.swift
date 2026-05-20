import Foundation

enum PasswordValidator {
    static let minimumLength = 8

    static func validationMessage(for password: String) -> String? {
        guard password.count >= minimumLength else {
            return "Password must be at least \(minimumLength) characters"
        }
        return nil
    }

    static func confirmationMessage(password: String, confirm: String) -> String? {
        guard password == confirm else { return "Passwords do not match" }
        return nil
    }
}
