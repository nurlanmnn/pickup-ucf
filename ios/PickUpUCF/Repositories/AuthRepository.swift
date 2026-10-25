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
    private let diagnostics: AuthOperationDiagnostics

    init(client: SupabaseClient = SupabaseManager.shared, diagnostics: AuthOperationDiagnostics = .init()) {
        self.client = client
        self.diagnostics = diagnostics
    }

    func signUp(email: String, password: String, displayName: String) async throws {
        let safeDisplayName = try UserContentPolicy.validate(displayName, field: .displayName)
        let metadata: [String: AnyJSON] = ["display_name": .string(safeDisplayName)]
        try await diagnostics.record(.signUp) {
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
    }

    func signIn(email: String, password: String) async throws -> AppSession {
        return try await diagnostics.record(.signIn) {
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
    }

    func signOut() async throws {
        try await diagnostics.record(.signOut) {
            try await client.auth.signOut()
        }
    }

    func resendVerificationEmail(email: String) async throws {
        try await resendVerificationOTP(email: email)
    }

    func resendVerificationOTP(email: String) async throws {
        try await diagnostics.record(.resendVerification) {
            try await client.auth.resend(
                email: email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
                type: .signup,
                emailRedirectTo: nil
            )
        }
    }

    func verifyEmailOTP(email: String, token: String) async throws -> AppSession {
        let normalizedEmail = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)

        return try await diagnostics.record(.verifyOTP) {
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
    }

    func requestPasswordReset(email: String) async throws {
        try await diagnostics.record(.passwordReset) {
            try await client.auth.resetPasswordForEmail(
                email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
                redirectTo: DeepLinkRouter.passwordResetURL
            )
        }
    }

    func updatePassword(_ newPassword: String) async throws {
        try await diagnostics.record(.passwordUpdate) {
            _ = try await client.auth.update(user: UserAttributes(password: newPassword))
        }
    }

    func changePassword(email: String, currentPassword: String, newPassword: String) async throws {
        let normalizedEmail = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let attempt = AuthOperationDiagnostics.Attempt()
        try await diagnostics.record(.changePasswordReauthenticate, attempt: attempt) {
            _ = try await client.auth.signIn(email: normalizedEmail, password: currentPassword)
        }
        try await diagnostics.record(.changePasswordUpdate, attempt: attempt) {
            _ = try await client.auth.update(user: UserAttributes(password: newPassword))
        }
    }

    func handleAuthDeepLink(url: URL) async throws {
        switch DeepLinkRouter.destination(from: url) {
        case .confirmEmail, .resetPassword:
            break
        default:
            throw AuthRepositoryError.invalidCallback
        }
        try await diagnostics.record(.callbackExchange) {
            _ = try await client.auth.session(from: url)
        }
    }

    func currentSession() async -> AppSession? {
        guard let session = try? await client.auth.session,
              let cached = try? mapSession(session) else { return nil }
        guard cached.isEmailConfirmed else {
            try? await client.auth.signOut(scope: .local)
            return nil
        }
        do {
            // A persisted JWT can outlive account deletion. Check the current
            // server user before restoring it, without treating offline as deletion.
            let user = try await client.auth.user(jwt: session.accessToken)
            guard client.auth.currentUser?.id == session.user.id else { return nil }
            let current = try mapUser(user)
            guard current.userId == cached.userId, current.isEmailConfirmed else {
                try? await client.auth.signOut(scope: .local)
                return nil
            }
            return current
        } catch let error as AuthError where [ErrorCode.userNotFound, .sessionNotFound, .sessionExpired, .badJWT, .refreshTokenNotFound].contains(error.errorCode) {
            guard client.auth.currentUser?.id == session.user.id else { return nil }
            try? await client.auth.signOut(scope: .local)
            return nil
        } catch {
            guard client.auth.currentUser?.id == session.user.id else { return nil }
            return cached
        }
    }

    private func mapSession(_ session: Session) throws -> AppSession {
        try mapUser(session.user)
    }

    private func mapUser(_ user: User) throws -> AppSession {
        let confirmed = user.emailConfirmedAt != nil || user.confirmedAt != nil
        guard let email = user.email else {
            throw AuthRepositoryError.missingEmail
        }
        return AppSession(userId: user.id, email: email, isEmailConfirmed: confirmed)
    }
}

enum AuthRepositoryError: LocalizedError {
    case invalidCallback
    case missingEmail
    case emailNotConfirmed

    var errorDescription: String? {
        switch self {
        case .invalidCallback: return "This sign-in link is invalid. Request a new link from the app."
        case .missingEmail: return "Account email is missing."
        case .emailNotConfirmed: return "Please verify your email before signing in."
        }
    }
}
