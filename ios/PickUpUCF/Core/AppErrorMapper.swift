import Foundation
import Supabase

enum AppErrorMapper {
    static let genericMessage = "Something went wrong. Please try again."

    static func message(for error: Error) -> String {
        let errors = errorChain(startingAt: error)

        for candidate in errors {
            if let message = structuredMessage(for: candidate) {
                return message
            }
        }

        for candidate in errors {
            if let message = compatibilityMessage(for: searchableText(for: candidate)) {
                return message
            }
        }

        return genericMessage
    }

    private static func structuredMessage(for error: Error) -> String? {
        if error is CancellationError {
            return "The request was cancelled."
        }

        if let urlError = error as? URLError {
            return networkMessage(for: urlError)
        }

        if let authError = error as? AuthError {
            return authMessage(for: authError)
        }

        if let postgrestError = error as? PostgrestError {
            return postgrestMessage(for: postgrestError)
        }

        return trustedDomainMessage(for: error)
    }

    private static func authMessage(for error: AuthError) -> String? {
        if case .weakPassword = error {
            return "Choose a stronger password with a mix of letters, numbers, and symbols."
        }

        switch error.errorCode.rawValue {
        case "invalid_credentials", "user_not_found":
            return "Invalid email or password."
        case "email_exists", "user_already_exists", "identity_already_exists":
            return "An account with this email already exists. Try signing in."
        case "email_not_confirmed", "provider_email_needs_verification":
            return "Please verify your email before signing in."
        case "otp_expired":
            return "That code expired. Request a new one and try again."
        case "flow_state_expired", "saml_relay_state_expired":
            return "This verification or reset link has expired. Request a new one."
        case "flow_state_not_found", "bad_code_verifier", "bad_oauth_state", "bad_oauth_callback", "invite_not_found":
            return "This verification or reset link is invalid. Request a new one."
        case "session_not_found", "session_expired", "refresh_token_not_found", "invalid_jwt", "bad_jwt":
            return "Your session expired. Please sign in again."
        case "refresh_token_already_used", "conflict":
            return "Your session changed on another device. Please sign in again."
        case "reauthentication_needed", "reauthentication_not_valid":
            return "Please sign in again to continue."
        case "no_authorization", "not_admin", "insufficient_aal", "user_banned":
            return "You don’t have permission to do that."
        case "email_address_not_authorized":
            return "This email address isn’t authorized to sign up."
        case "over_request_rate_limit", "over_email_send_rate_limit", "over_sms_send_rate_limit":
            return "Too many attempts. Please wait a moment and try again."
        case "request_timeout":
            return "Could not reach the server. Try again in a moment."
        case "hook_timeout", "hook_timeout_after_retry", "sms_send_failed":
            return "We couldn’t send the verification email. Request a new code or try again in a few minutes."
        case "validation_failed", "weak_password":
            return "Check the information you entered and try again."
        case "same_password":
            return "Choose a password you haven’t used for this account."
        case "signup_disabled", "email_provider_disabled", "provider_disabled":
            return "Sign-up is temporarily unavailable. Please try again later."
        default:
            return nil
        }
    }

    private static func postgrestMessage(for error: PostgrestError) -> String? {
        let text = [error.code, error.message, error.detail, error.hint]
            .compactMap { $0 }
            .joined(separator: " ")
            .lowercased()

        if let domainMessage = compatibilityMessage(for: text) {
            return domainMessage
        }

        switch error.code?.uppercased() {
        case "23505":
            return text.contains("username")
                ? "That username is already taken."
                : "That information is already in use."
        case "23514", "22000", "22001", "22P02":
            return "Check the information you entered and try again."
        case "42501":
            return "You don’t have permission to do that."
        case "40001", "40P01":
            return "Someone else updated this information. Refresh and try again."
        case "57014":
            return "The request was cancelled."
        default:
            return nil
        }
    }

    private static func networkMessage(for error: URLError) -> String? {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .internationalRoamingOff, .dataNotAllowed:
            return "No internet connection. Check your network and try again."
        case .timedOut, .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
            return "Could not reach the server. Try again in a moment."
        case .cancelled:
            return "The request was cancelled."
        default:
            return nil
        }
    }

    private static func trustedDomainMessage(for error: Error) -> String? {
        switch error {
        case let error as AuthRepositoryError:
            return error.errorDescription
        case let error as SessionRepositoryError:
            return error.errorDescription
        case let error as ChatRepositoryError:
            return error.errorDescription
        case let error as ReportRepositoryError:
            return error.errorDescription
        case let error as ProfileRepositoryError:
            return error.errorDescription
        case let error as CalendarExportError:
            return error.errorDescription
        default:
            return nil
        }
    }

    private static func compatibilityMessage(for text: String) -> String? {
        let text = text.lowercased()

        if text.contains("offline")
            || text.contains("not connected to the internet")
            || text.contains("network connection was lost") {
            return "No internet connection. Check your network and try again."
        }
        if text.contains("timed out") || text.contains("could not connect") {
            return "Could not reach the server. Try again in a moment."
        }
        if text.contains("user already registered")
            || text.contains("already been registered")
            || text.contains("email_exists")
            || text.contains("user_already_exists") {
            return "An account with this email already exists. Try signing in."
        }
        if text.contains("invalid login credentials")
            || text.contains("invalid_credentials")
            || (text.contains("invalid") && text.contains("credential")) {
            return "Invalid email or password."
        }
        if text.contains("email not confirmed") || text.contains("email_not_confirmed") {
            return "Please verify your email before signing in."
        }
        if text.contains("failed to send email")
            || text.contains("email service")
            || text.contains("hook_timeout") {
            return "We couldn’t send the verification email. Request a new code or try again in a few minutes."
        }
        if text.contains("otp_expired") || (text.contains("expired") && text.contains("otp")) {
            return "That code expired. Request a new one and try again."
        }
        if text.contains("otp") && (text.contains("invalid") || text.contains("incorrect")) {
            return "That code is incorrect. Check your email and try again."
        }
        if text.contains("flow_state_expired") || text.contains("reset link expired") {
            return "This verification or reset link has expired. Request a new one."
        }
        if text.contains("flow_state_not_found")
            || text.contains("bad_code_verifier")
            || text.contains("invalid reset link") {
            return "This verification or reset link is invalid. Request a new one."
        }
        if text.contains("session_full") {
            return "This game is full. Join the waitlist to be notified if a spot opens."
        }
        if text.contains("waitlist_full") {
            return "The waitlist is full. Please check again later."
        }
        if text.contains("session_not_joinable") {
            return "This session is no longer open for new players."
        }
        if text.contains("session_not_found") {
            return "This session is no longer available."
        }
        if text.contains("not_host") {
            return "Only the host can mark attendance."
        }
        if text.contains("session_not_started") {
            return "Attendance opens when the game starts."
        }
        if text.contains("attendance_window_closed") {
            return "The attendance window has closed."
        }
        if text.contains("session_cancelled") {
            return "This session was cancelled."
        }
        if text.contains("user_blocked") {
            return "You can’t join this host’s sessions."
        }
        if text.contains("preferred_sports_required") {
            return "Select at least one sport."
        }
        if text.contains("invalid_block_target") {
            return "You can’t block this account."
        }
        if text.contains("user_not_found") {
            return "This user is no longer available."
        }
        if text.contains("username") && (text.contains("unique") || text.contains("duplicate")) {
            return "That username is already taken."
        }
        if text.contains("not_authenticated") {
            return "Your session expired. Please sign in again."
        }
        if text.contains("permission denied")
            || text.contains("not authorized")
            || text.contains("unauthorized")
            || text.contains("forbidden") {
            return "You don’t have permission to do that."
        }
        if text.contains("rate limit") || text.contains("too many requests") {
            return "Too many attempts. Please wait a moment and try again."
        }
        if text.contains("invalid api key")
            || text.contains("placeholder")
            || text.contains("your_project")
            || (text.contains("column") && text.contains("does not exist"))
            || text.contains("schema cache") {
            return "The service is temporarily unavailable. Please try again later."
        }

        return nil
    }

    private static func searchableText(for error: Error) -> String {
        if let authError = error as? AuthError {
            return "\(authError.errorCode.rawValue) \(authError.message)"
        }
        if let postgrestError = error as? PostgrestError {
            return [postgrestError.code, postgrestError.message, postgrestError.detail, postgrestError.hint]
                .compactMap { $0 }
                .joined(separator: " ")
        }
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription {
            return "\(String(describing: error)) \(description)"
        }
        return String(describing: error)
    }

    private static func errorChain(startingAt error: Error) -> [Error] {
        var chain: [Error] = []
        var visitedNSErrors: [NSError] = []
        var current: Error? = error

        for _ in 0 ..< 8 {
            guard let candidate = current else { break }
            let nsError = candidate as NSError
            guard !visitedNSErrors.contains(where: { $0 === nsError }) else { break }

            chain.append(candidate)
            visitedNSErrors.append(nsError)

            guard let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error,
                  (underlying as NSError) !== nsError else {
                break
            }
            current = underlying
        }

        return chain
    }
}
