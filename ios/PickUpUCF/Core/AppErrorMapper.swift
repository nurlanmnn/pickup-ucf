import Foundation

enum AppErrorMapper {
    static func message(for error: Error) -> String {
        if let localized = error as? LocalizedError,
           let description = localized.errorDescription,
           !description.isEmpty {
            return description
        }

        let text = String(describing: error).lowercased()

        if text.contains("offline")
            || text.contains("not connected to the internet")
            || text.contains("network connection was lost") {
            return "No internet connection. Check your network and try again."
        }
        if text.contains("timed out") || text.contains("could not connect") {
            return "Could not reach the server. Try again in a moment."
        }
        if text.contains("invalid api key") || text.contains("invalid jwt") {
            return "Supabase configuration error. Check Config.xcconfig in Xcode."
        }
        if text.contains("placeholder") || text.contains("your_project") {
            return "Supabase is not configured. Add your project URL and anon key."
        }
        if text.contains("user already registered") || text.contains("already been registered") {
            return "An account with this email already exists. Try signing in."
        }
        if text.contains("invalid login credentials")
            || (text.contains("invalid") && text.contains("credential")) {
            return "Invalid email or password."
        }
        if text.contains("email not confirmed") || text.contains("email_not_confirmed") {
            return "Please verify your email before signing in."
        }
        if text.contains("hook") || text.contains("email service") || text.contains("failed to send email") {
            return "We couldn't send the verification email. Tap Resend code or try again in a few minutes."
        }
        if text.contains("otp_expired") || text.contains("expired") && text.contains("otp") {
            return "That code expired. Tap Resend code for a new one."
        }
        if text.contains("otp") && (text.contains("invalid") || text.contains("incorrect")) {
            return "That code is incorrect. Check your email and try again."
        }
        if text.contains("session_not_found") {
            return "This session is no longer available."
        }
        if text.contains("session_not_joinable") {
            return "This session is no longer open for new players."
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
        if text.contains("participant_status") && text.contains("invalid input value") {
            return "Could not join this session. Apply the latest database migration (fix_join_session_status_type) in Supabase, then try again."
        }
        if text.contains("username") && (text.contains("unique") || text.contains("duplicate")) {
            return "That username is already taken."
        }
        if text.contains("not_authenticated") {
            return "Your session expired. Please sign in again."
        }
        if text.contains("rate limit") || text.contains("too many requests") {
            return "Too many attempts. Please wait a moment and try again."
        }
        if text.contains("column") && text.contains("does not exist") {
            return "The server database is missing a recent update. Apply the latest Supabase migrations (see supabase/migrations), or ask your project admin to run them."
        }
        if text.contains("schema cache"), text.contains("column") || text.contains("sessions") {
            return "The server hasn’t picked up the latest database schema yet. In Supabase: run migrations, then Database → API → Reload schema (or wait a minute and try again)."
        }

        return "Something went wrong. Please try again."
    }
}
