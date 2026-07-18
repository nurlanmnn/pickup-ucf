import XCTest
@testable import PickUpUCF

final class AppErrorMapperTests: XCTestCase {
    func testMapsAttendanceRpcErrors() {
        let cases: [(code: String, expected: String)] = [
            ("not_host", "Only the host can mark attendance."),
            ("session_not_started", "Attendance opens when the game starts."),
            ("attendance_window_closed", "The attendance window has closed."),
            ("session_cancelled", "This session was cancelled."),
            ("session_not_found", "This session is no longer available."),
            ("not_authenticated", "Your session expired. Please sign in again."),
        ]

        for testCase in cases {
            let error = RpcError(code: testCase.code)
            XCTAssertEqual(
                AppErrorMapper.message(for: error),
                testCase.expected,
                "Expected mapping for \(testCase.code)"
            )
        }
    }

    func testMapsWrappedPostgrestErrorText() {
        let error = RpcError(code: "not_host", prefix: "PostgrestError")
        XCTAssertEqual(
            AppErrorMapper.message(for: error),
            "Only the host can mark attendance."
        )
    }

    func testUnknownErrorReturnsGenericMessage() {
        let error = RpcError(code: "unexpected_failure")
        XCTAssertEqual(
            AppErrorMapper.message(for: error),
            "Something went wrong. Please try again."
        )
    }
}

private struct RpcError: Error, CustomStringConvertible {
    let code: String
    var prefix: String = "RpcError"

    var description: String { "\(prefix)(message: \(code))" }
}
