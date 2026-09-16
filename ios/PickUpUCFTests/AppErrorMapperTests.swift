import Foundation
import Supabase
import XCTest
@testable import PickUpUCF

final class AppErrorMapperTests: XCTestCase {
    func testMapsStructuredAuthErrorsBeforeLocalizedDescription() {
        let cases: [(ErrorCode, String)] = [
            (.invalidCredentials, "Invalid email or password."),
            (.emailExists, "An account with this email already exists. Try signing in."),
            (.userAlreadyExists, "An account with this email already exists. Try signing in."),
            (.emailNotConfirmed, "Please verify your email before signing in."),
            (.otpExpired, "That code expired. Request a new one and try again."),
            (.flowStateExpired, "This verification or reset link has expired. Request a new one."),
            (.flowStateNotFound, "This verification or reset link is invalid. Request a new one."),
            (.badCodeVerifier, "This verification or reset link is invalid. Request a new one."),
            (.sessionExpired, "Your session expired. Please sign in again."),
            (.refreshTokenAlreadyUsed, "Your session changed on another device. Please sign in again."),
            (.conflict, "Your session changed on another device. Please sign in again."),
            (.noAuthorization, "You don’t have permission to do that."),
            (.emailAddressNotAuthorized, "This email address isn’t authorized to sign up."),
            (.overRequestRateLimit, "Too many attempts. Please wait a moment and try again."),
            (.requestTimeout, "Could not reach the server. Try again in a moment."),
        ]

        for (code, expected) in cases {
            let error = makeAuthError(code: code, message: "server detail token=secret")
            XCTAssertEqual(AppErrorMapper.message(for: error), expected, "Expected mapping for \(code.rawValue)")
        }
    }

    func testMapsAuthWeakPasswordWithoutReturningServerReasons() {
        let error = AuthError.weakPassword(
            message: "Password leaked in breach internal-rule-42",
            reasons: ["characters", "pwned"]
        )

        XCTAssertEqual(
            AppErrorMapper.message(for: error),
            "Choose a stronger password with a mix of letters, numbers, and symbols."
        )
    }

    func testUnknownAuthServerMessageReturnsGenericMessage() {
        let error = makeAuthError(
            code: .unexpectedFailure,
            message: "SQL SELECT secret_token FROM auth.users stack trace 123e4567-e89b-12d3-a456-426614174000"
        )

        XCTAssertEqual(AppErrorMapper.message(for: error), "Something went wrong. Please try again.")
    }

    func testMapsPostgrestRpcDomainErrors() {
        let cases: [(String, String)] = [
            ("not_host", "Only the host can mark attendance."),
            ("session_not_started", "Attendance opens when the game starts."),
            ("attendance_window_closed", "The attendance window has closed."),
            ("session_cancelled", "This session was cancelled."),
            ("session_not_found", "This session is no longer available."),
            ("session_not_joinable", "This session is no longer open for new players."),
            ("session_full", "This game is full. Join the waitlist to be notified if a spot opens."),
            ("waitlist_full", "The waitlist is full. Please check again later."),
            ("user_blocked", "You can’t join this host’s sessions."),
            ("not_authenticated", "Your session expired. Please sign in again."),
            ("preferred_sports_required", "Select at least one sport."),
            ("invalid_block_target", "You can’t block this account."),
            ("user_not_found", "This user is no longer available."),
        ]

        for (rpcCode, expected) in cases {
            let error = PostgrestError(
                detail: "internal detail token=secret",
                hint: "SELECT * FROM private_table",
                code: "P0001",
                message: rpcCode
            )
            XCTAssertEqual(AppErrorMapper.message(for: error), expected, "Expected mapping for \(rpcCode)")
        }
    }

    func testMapsPostgrestDatabaseCodesWithoutLeakingDetails() {
        let cases: [(code: String, message: String, expected: String)] = [
            ("23505", "duplicate key violates profiles_username_key", "That username is already taken."),
            ("23505", "duplicate key value=(private-id)", "That information is already in use."),
            ("23514", "new row violates check constraint private_constraint", "Check the information you entered and try again."),
            ("42501", "permission denied for table auth.users", "You don’t have permission to do that."),
            ("40001", "could not serialize access", "Someone else updated this information. Refresh and try again."),
            ("40P01", "deadlock detected", "Someone else updated this information. Refresh and try again."),
        ]

        for testCase in cases {
            let error = PostgrestError(
                detail: "SQL SELECT api_key FROM vault",
                hint: "internal-id=123e4567-e89b-12d3-a456-426614174000",
                code: testCase.code,
                message: testCase.message
            )
            XCTAssertEqual(AppErrorMapper.message(for: error), testCase.expected)
        }
    }

    func testUnknownPostgrestErrorReturnsGenericMessage() {
        let error = PostgrestError(
            detail: "stack trace password=hunter2",
            hint: "run ALTER TABLE private_schema.users",
            code: "XX000",
            message: "internal database failure request-id=private-id"
        )

        XCTAssertEqual(AppErrorMapper.message(for: error), "Something went wrong. Please try again.")
    }

    func testGenericLocalizedErrorCannotSwallowKnownCompatibilityMapping() {
        let error = StubLocalizedError(
            errorDescription: "PostgrestError(message: invalid login credentials; access_token=secret)"
        )

        XCTAssertEqual(AppErrorMapper.message(for: error), "Invalid email or password.")
    }

    func testUnknownLocalizedErrorCannotReachUser() {
        let sensitive = "SQL SELECT * FROM auth.users WHERE email='student@ucf.edu'; bearer secret-token"
        XCTAssertEqual(
            AppErrorMapper.message(for: StubLocalizedError(errorDescription: sensitive)),
            "Something went wrong. Please try again."
        )
    }

    func testMapsWrappedStructuredError() {
        let underlying = PostgrestError(
            detail: nil,
            hint: nil,
            code: "P0001",
            message: "not_host"
        )
        let wrapped = NSError(
            domain: "RepositoryWrapper",
            code: 1,
            userInfo: [
                NSLocalizedDescriptionKey: "Raw wrapper stack trace",
                NSUnderlyingErrorKey: underlying,
            ]
        )

        XCTAssertEqual(AppErrorMapper.message(for: wrapped), "Only the host can mark attendance.")
    }

    func testMapsNestedNetworkError() {
        let wrapped = NSError(
            domain: "RepositoryWrapper",
            code: 2,
            userInfo: [NSUnderlyingErrorKey: URLError(.notConnectedToInternet)]
        )

        XCTAssertEqual(
            AppErrorMapper.message(for: wrapped),
            "No internet connection. Check your network and try again."
        )
    }

    func testWrappedUnknownErrorReturnsGenericMessage() {
        let underlying = StubLocalizedError(
            errorDescription: "SQL SELECT refresh_token FROM auth.sessions password=secret"
        )
        let wrapped = NSError(
            domain: "RepositoryWrapper",
            code: 3,
            userInfo: [
                NSLocalizedDescriptionKey: "stack trace internal-id=private-id",
                NSUnderlyingErrorKey: underlying,
            ]
        )

        XCTAssertEqual(
            AppErrorMapper.message(for: wrapped),
            "Something went wrong. Please try again."
        )
    }

    func testMapsNetworkAndCancellationErrors() {
        let cases: [(Error, String)] = [
            (URLError(.notConnectedToInternet), "No internet connection. Check your network and try again."),
            (URLError(.networkConnectionLost), "No internet connection. Check your network and try again."),
            (URLError(.timedOut), "Could not reach the server. Try again in a moment."),
            (URLError(.cannotConnectToHost), "Could not reach the server. Try again in a moment."),
            (URLError(.cancelled), "The request was cancelled."),
            (CancellationError(), "The request was cancelled."),
        ]

        for (error, expected) in cases {
            XCTAssertEqual(AppErrorMapper.message(for: error), expected)
        }
    }

    func testPreservesTrustedDomainMessages() {
        let cases: [(Error, String)] = [
            (AuthRepositoryError.missingEmail, "Account email is missing."),
            (AuthRepositoryError.emailNotConfirmed, "Please verify your email before signing in."),
            (SessionRepositoryError.locationRequired, "Choose a venue or pick a custom location on the map."),
            (SessionRepositoryError.customLocationPinRequired, "Search on the map and choose where you're playing."),
            (SessionRepositoryError.scheduleTooFarAhead, "Sessions can only be scheduled up to 7 days ahead."),
            (SessionRepositoryError.scheduleInPast, "Start time must be in the future."),
            (SessionRepositoryError.capacityBelowSignups, "Capacity can’t be lower than the number of players already signed up."),
            (SessionRepositoryError.customSportNameRequired, "Enter a name for your sport (e.g. pickleball, badminton)."),
            (ChatRepositoryError.emptyMessage, "Type a message before sending."),
            (ChatRepositoryError.notParticipant, "Join this session to chat with other players."),
            (ReportRepositoryError.contextTooShort, "Add at least 10 characters of context or leave it blank."),
            (ReportRepositoryError.contextTooLong, "Keep your report context under 500 characters."),
            (ReportRepositoryError.alreadyReported, "You already have an open report for this item."),
            (ReportRepositoryError.rateLimited, "You’ve submitted several reports. Please wait before sending another."),
            (ReportRepositoryError.invalidTarget, "This item can’t be reported or is no longer available."),
            (ProfileRepositoryError.missingDisplayName, "Display name is required for your profile."),
            (ProfileRepositoryError.preferredSportsRequired, "Select at least one sport."),
            (CalendarExportError.accessDenied, "Calendar access is required to save this game."),
            (CalendarExportError.alreadyAdded, "This game is already in your calendar."),
            (CalendarExportError.saveFailed, "Could not save this game to your calendar."),
            (CalendarExportError.removeFailed, "Could not remove this cancelled game from your calendar."),
        ]

        for (error, expected) in cases {
            XCTAssertEqual(AppErrorMapper.message(for: error), expected)
        }
    }

    func testLegacyCompatibilityMappingsReturnOnlyFixedSafeCopy() {
        let cases: [(String, String)] = [
            ("user already registered email=student@ucf.edu", "An account with this email already exists. Try signing in."),
            ("email_not_confirmed jwt=secret", "Please verify your email before signing in."),
            ("otp invalid internal-id=123", "That code is incorrect. Check your email and try again."),
            ("failed to send email api_key=secret", "We couldn’t send the verification email. Request a new code or try again in a few minutes."),
            ("invalid api key secret-value", "The service is temporarily unavailable. Please try again later."),
            ("column private_column does not exist", "The service is temporarily unavailable. Please try again later."),
        ]

        for (description, expected) in cases {
            XCTAssertEqual(
                AppErrorMapper.message(for: DescribedError(description: description)),
                expected
            )
        }
    }

    func testUnknownErrorReturnsGenericMessage() {
        XCTAssertEqual(
            AppErrorMapper.message(for: DescribedError(description: "unexpected_failure")),
            "Something went wrong. Please try again."
        )
    }

    private func makeAuthError(code: ErrorCode, message: String) -> AuthError {
        .api(
            message: message,
            errorCode: code,
            underlyingData: Data(),
            underlyingResponse: HTTPURLResponse(
                url: URL(string: "https://example.invalid/auth")!,
                statusCode: 400,
                httpVersion: nil,
                headerFields: nil
            )!
        )
    }
}

private struct StubLocalizedError: LocalizedError {
    let errorDescription: String?
}

private struct DescribedError: Error, CustomStringConvertible {
    let description: String
}
