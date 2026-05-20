import Foundation
import Supabase

protocol AuthRepositoryProtocol {
    func signUp(email: String, password: String, displayName: String) async throws
    func signIn(email: String, password: String) async throws -> AppSession
    func signOut() async throws
    func resendVerificationEmail(email: String) async throws
    func resendVerificationOTP(email: String) async throws
    func verifyEmailOTP(email: String, token: String) async throws -> AppSession
    func requestPasswordReset(email: String) async throws
    func updatePassword(_ newPassword: String) async throws
    func changePassword(email: String, currentPassword: String, newPassword: String) async throws
    func handleAuthDeepLink(url: URL) async throws
    func currentSession() async -> AppSession?
}

final class AuthRepository: AuthRepositoryProtocol {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseManager.shared) {
        self.client = client
    }

    func signUp(email: String, password: String, displayName: String) async throws {
        let metadata: [String: AnyJSON] = ["display_name": .string(displayName)]
        let response = try await client.auth.signUp(
            email: email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
            password: password,
            data: metadata
        )
        if let session = response.session {
            let user = session.user
            let confirmed = user.emailConfirmedAt != nil || user.confirmedAt != nil
            if !confirmed {
                try await client.auth.signOut()
            }
        }
    }

    func signIn(email: String, password: String) async throws -> AppSession {
        let session = try await client.auth.signIn(
            email: email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
            password: password
        )
        let mapped = try mapSession(session)
        guard mapped.isEmailConfirmed else {
            // Clear persisted JWT so unverified users cannot use the API from this install.
            try await client.auth.signOut()
            throw AuthRepositoryError.emailNotConfirmed
        }
        return mapped
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    func resendVerificationEmail(email: String) async throws {
        try await resendVerificationOTP(email: email)
    }

    func resendVerificationOTP(email: String) async throws {
        try await client.auth.resend(
            email: email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
            type: .signup,
            emailRedirectTo: nil
        )
    }

    func verifyEmailOTP(email: String, token: String) async throws -> AppSession {
        let normalizedEmail = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)

        let response = try await client.auth.verifyOTP(
            email: normalizedEmail,
            token: normalizedToken,
            type: .signup
        )

        guard let session = response.session else {
            throw AuthRepositoryError.emailNotConfirmed
        }

        return try mapSession(session)
    }

    func requestPasswordReset(email: String) async throws {
        try await client.auth.resetPasswordForEmail(
            email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
            redirectTo: URL(string: "pickupucf://auth/reset-password")
        )
    }

    func updatePassword(_ newPassword: String) async throws {
        try await client.auth.update(user: UserAttributes(password: newPassword))
    }

    func changePassword(email: String, currentPassword: String, newPassword: String) async throws {
        let normalizedEmail = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        _ = try await client.auth.signIn(email: normalizedEmail, password: currentPassword)
        try await client.auth.update(user: UserAttributes(password: newPassword))
    }

    func handleAuthDeepLink(url: URL) async throws {
        try await client.auth.session(from: url)
    }

    func currentSession() async -> AppSession? {
        guard let session = try? await client.auth.session else { return nil }
        guard let mapped = try? mapSession(session) else { return nil }
        guard mapped.isEmailConfirmed else {
            try? await client.auth.signOut()
            return nil
        }
        return mapped
    }

    private func mapSession(_ session: Session) throws -> AppSession {
        let user = session.user
        let confirmed = user.emailConfirmedAt != nil || user.confirmedAt != nil
        guard let email = user.email else {
            throw AuthRepositoryError.missingEmail
        }
        return AppSession(userId: user.id, email: email, isEmailConfirmed: confirmed)
    }
}

enum AuthRepositoryError: LocalizedError {
    case missingEmail
    case emailNotConfirmed

    var errorDescription: String? {
        switch self {
        case .missingEmail: return "Account email is missing."
        case .emailNotConfirmed: return "Please verify your email before signing in."
        }
    }
}
