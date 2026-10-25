import XCTest
import Supabase
@testable import PickUpUCF

final class AuthOperationDiagnosticsTests: XCTestCase {
    private var records: [AuthOperationDiagnostics.Record] = []
    private var requests: [URLRequest] = []
    private let userID = UUID()

    override func tearDown() {
        AuthDiagnosticRequest.respond = nil
        super.tearDown()
    }

    func testSignInPreservesNormalizedRequestMappedResultAndClosedLog() async throws {
        let repo = makeRepository { _ in (200, try self.sessionData()) }
        let session = try await repo.signIn(email: "  PRIVATE@UCF.EDU \n", password: "private-password")
        XCTAssertEqual(session.userId, userID)
        XCTAssertTrue(session.isEmailConfirmed)
        XCTAssertEqual(try body(requests[0])["email"] as? String, "private@ucf.edu")
        XCTAssertEqual(try body(requests[0])["password"] as? String, "private-password")
        XCTAssertEqual(records.map(\.operation), [.signIn])
        XCTAssertEqual(records[0].result, .succeeded)
        try assertPrivateRecord(records[0])
    }

    func testBackendFailureRetainsSDKErrorAndRetriesHaveFreshAttemptIDs() async throws {
        let repo = makeRepository { _ in
            (400, Data(#"{"code":"invalid_credentials","msg":"private@ucf.edu private-password private-token"}"#.utf8))
        }
        for _ in 0..<2 {
            do { _ = try await repo.signIn(email: "private@ucf.edu", password: "private-password"); XCTFail() }
            catch let error as AuthError { XCTAssertEqual(error.errorCode, .invalidCredentials) }
        }
        XCTAssertEqual(records.count, 2)
        XCTAssertEqual(records.map(\.failure), [.backend, .backend])
        XCTAssertNotEqual(records[0].attemptID, records[1].attemptID)
        for record in records { try assertPrivateRecord(record) }
    }

    func testUnconfirmedSignInPreservesCleanupAndLocalError() async throws {
        let repo = makeRepository { request in
            request.url!.path.hasSuffix("/logout") ? (204, Data()) : (200, try self.sessionData(confirmed: false))
        }
        do { _ = try await repo.signIn(email: "private@ucf.edu", password: "private-password"); XCTFail() }
        catch let error as AuthRepositoryError { XCTAssertEqual(error, .emailNotConfirmed) }
        XCTAssertEqual(requests.map { $0.url!.lastPathComponent }, ["token", "logout"])
        XCTAssertEqual(records.map(\.failure), [.localPolicy])
        XCTAssertEqual(records[0].result, .failed)
    }

    func testVerifyOTPNormalizesTokenAndPreservesResult() async throws {
        let repo = makeRepository { _ in (200, try self.sessionData()) }
        let session = try await repo.verifyEmailOTP(email: " PRIVATE@UCF.EDU ", token: " private-otp \n")
        XCTAssertEqual(session.userId, userID)
        XCTAssertEqual(try body(requests[0])["token"] as? String, "private-otp")
        XCTAssertEqual(records.map(\.operation), [.verifyOTP])
        try assertPrivateRecord(records[0])
    }

    func testPasswordResetRetainsRedirectAndResendAliasEmitsOnce() async throws {
        let repo = makeRepository { _ in (200, Data("{}".utf8)) }
        try await repo.requestPasswordReset(email: " PRIVATE@UCF.EDU ")
        try await repo.resendVerificationEmail(email: " PRIVATE@UCF.EDU ")
        XCTAssertEqual(requests.map { $0.url!.lastPathComponent }, ["recover", "resend"])
        let query = URLComponents(url: requests[0].url!, resolvingAgainstBaseURL: false)?.queryItems
        XCTAssertEqual(query?.first(where: { $0.name == "redirect_to" })?.value, DeepLinkRouter.passwordResetURL.absoluteString)
        XCTAssertEqual(try body(requests[0])["email"] as? String, "private@ucf.edu")
        XCTAssertEqual(records.map(\.operation), [.passwordReset, .resendVerification])
        for record in records { try assertPrivateRecord(record) }
    }

    func testChangePasswordCorrelatesReauthenticationAndWriteWithoutChangingRequests() async throws {
        let repo = makeRepository { request in
            request.url!.path.hasSuffix("/token") ? (200, try self.sessionData()) : (200, try self.userData())
        }
        try await repo.changePassword(email: " PRIVATE@UCF.EDU ", currentPassword: "private-old", newPassword: "private-new")
        XCTAssertEqual(requests.map { $0.url!.lastPathComponent }, ["token", "user"])
        XCTAssertEqual(try body(requests[0])["password"] as? String, "private-old")
        XCTAssertEqual(try body(requests[1])["password"] as? String, "private-new")
        XCTAssertEqual(records.map(\.operation), [.changePasswordReauthenticate, .changePasswordUpdate])
        XCTAssertEqual(records[0].attemptID, records[1].attemptID)
        XCTAssertEqual(records.map(\.result), [.succeeded, .succeeded])
    }

    func testChangePasswordStopsAfterFailedReauthentication() async throws {
        let repo = makeRepository { _ in throw URLError(.notConnectedToInternet) }
        do { try await repo.changePassword(email: "private@ucf.edu", currentPassword: "private-old", newPassword: "private-new"); XCTFail() }
        catch let error as URLError { XCTAssertEqual(error.code, .notConnectedToInternet) }
        XCTAssertFalse(requests.isEmpty)
        XCTAssertTrue(requests.allSatisfy { $0.url!.lastPathComponent == "token" })
        XCTAssertEqual(records.map(\.operation), [.changePasswordReauthenticate])
        XCTAssertEqual(records[0].failure, .transport)
    }

    func testPasswordWriteFailureIsDistinctFromSuccessfulReauthentication() async throws {
        let repo = makeRepository { request in
            request.url!.path.hasSuffix("/token") ? (200, try self.sessionData()) :
                (422, Data(#"{"code":"same_password","msg":"private-new"}"#.utf8))
        }
        do { try await repo.changePassword(email: "private@ucf.edu", currentPassword: "private-old", newPassword: "private-new"); XCTFail() }
        catch let error as AuthError { XCTAssertEqual(error.errorCode, .samePassword) }
        XCTAssertEqual(records.map(\.result), [.succeeded, .failed])
        XCTAssertEqual(records.map(\.failure), [.none, .backend])
        XCTAssertEqual(records[0].attemptID, records[1].attemptID)
    }

    func testSignUpSignOutAndPasswordUpdateAreInstrumented() async throws {
        let repo = makeRepository { request in
            if request.url!.path.hasSuffix("/logout") { return (204, Data()) }
            if request.url!.path.hasSuffix("/user") { return (200, try self.userData()) }
            return (200, try self.sessionData())
        }
        try await repo.signUp(email: " PRIVATE@UCF.EDU ", password: "private-password", displayName: "Private Name")
        try await repo.updatePassword("private-new")
        try await repo.signOut()
        XCTAssertEqual(records.map(\.operation), [.signUp, .passwordUpdate, .signOut])
        XCTAssertTrue(records.allSatisfy { $0.result == .succeeded })
        for record in records { try assertPrivateRecord(record) }
    }

    func testRejectedCallbackAndDisplayNameDoNotAttemptBackendOrEmitExchange() async throws {
        let repo = makeRepository { _ in XCTFail("Unexpected HTTP"); return (500, Data()) }
        do { try await repo.handleAuthDeepLink(url: URL(string: "https://private.invalid/#access_token=private-token")!); XCTFail() }
        catch let error as AuthRepositoryError { XCTAssertEqual(error, .invalidCallback) }
        do { try await repo.signUp(email: "private@ucf.edu", password: "private-password", displayName: ""); XCTFail() }
        catch { }
        XCTAssertTrue(requests.isEmpty)
        XCTAssertTrue(records.isEmpty)
    }

    func testDiagnosticWrapperPreservesErrorIdentityAndCoarseClasses() async throws {
        final class PrivateError: Error {}
        let privateError = PrivateError()
        let errors: [Error] = [CancellationError(), URLError(.cancelled), URLError(.timedOut),
            DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "private-token")), privateError]
        let diagnostics = AuthOperationDiagnostics { self.records.append($0) }
        for error in errors {
            do { try await diagnostics.record(.callbackExchange) { throw error }; XCTFail() }
            catch { if error is PrivateError { XCTAssertTrue((error as AnyObject) === privateError) } }
        }
        XCTAssertEqual(records.map(\.failure), [.cancelled, .cancelled, .transport, .decoding, .unknown])
        XCTAssertEqual(records.map(\.result), [.cancelled, .cancelled, .failed, .failed, .failed])
        for record in records { try assertPrivateRecord(record) }
    }

    func testAcceptedCallbackPreservesCodeExchangeAndLogsNoURL() async throws {
        let repo = makeRepository { _ in (200, try self.sessionData()) }
        try await repo.handleAuthDeepLink(url: URL(string: "https://\(DeepLinkRouter.webHost)/auth/reset-password?code=private-code")!)
        XCTAssertEqual(requests.map { $0.url!.lastPathComponent }, ["token"])
        XCTAssertEqual(try body(requests[0])["auth_code"] as? String, "private-code")
        XCTAssertEqual(records.map(\.operation), [.callbackExchange])
        XCTAssertEqual(records[0].result, .succeeded)
        try assertPrivateRecord(records[0])
    }

    func testMissingOTPSessionPreservesLocalRejection() async throws {
        let repo = makeRepository { _ in (200, try self.userData()) }
        do { _ = try await repo.verifyEmailOTP(email: "private@ucf.edu", token: "private-otp"); XCTFail() }
        catch let error as AuthRepositoryError { XCTAssertEqual(error, .emailNotConfirmed) }
        XCTAssertEqual(records.map(\.failure), [.localPolicy])
    }

    func testUnconfirmedOTPAndChangePasswordDoNotGainSignInGuard() async throws {
        let repo = makeRepository { request in
            request.url!.path.hasSuffix("/user") ? (200, try self.userData(confirmed: false)) :
                (200, try self.sessionData(confirmed: false))
        }
        let session = try await repo.verifyEmailOTP(email: "private@ucf.edu", token: "private-otp")
        XCTAssertFalse(session.isEmailConfirmed)
        try await repo.changePassword(email: "private@ucf.edu", currentPassword: "private-old", newPassword: "private-new")
        XCTAssertEqual(requests.map { $0.url!.lastPathComponent }, ["verify", "token", "user"])
        XCTAssertTrue(records.allSatisfy { $0.result == .succeeded })
    }

    func testSignInAndSignUpCleanupFailureNeverLogsSuccess() async throws {
        for signUp in [false, true] {
            records.removeAll(); requests.removeAll()
            let repo = makeRepository { request in
                if request.url!.path.hasSuffix("/logout") { throw URLError(.notConnectedToInternet) }
                return (200, try self.sessionData(confirmed: false))
            }
            do {
                if signUp { try await repo.signUp(email: "private@ucf.edu", password: "private-password", displayName: "Private Name") }
                else { _ = try await repo.signIn(email: "private@ucf.edu", password: "private-password") }
                XCTFail()
            } catch let error as URLError { XCTAssertEqual(error.code, .notConnectedToInternet) }
            XCTAssertEqual(records.count, 1)
            XCTAssertEqual(records[0].operation, signUp ? .signUp : .signIn)
            XCTAssertEqual(records[0].failure, .transport)
            XCTAssertEqual(records[0].result, .failed)
        }
    }

    func testDefaultLoggerEmitsSyntheticSDKFailure() async throws {
        let repo = makeRepository(capture: false) { _ in throw URLError(.notConnectedToInternet) }
        do { _ = try await repo.signIn(email: "private@ucf.edu", password: "private-password"); XCTFail() }
        catch { XCTAssertTrue(error is URLError) }
    }

    private func assertPrivateRecord(_ record: AuthOperationDiagnostics.Record) throws {
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(record.json.utf8)) as? [String: Any])
        XCTAssertEqual(Set(json.keys), Set(["event", "operation", "result", "failure", "attempt_id", "duration_ms", "version", "build", "configuration", "environment"]))
        XCTAssertEqual(json["event"] as? String, "auth_operation")
        XCTAssertEqual(json["environment"] as? String, "unit_test")
        XCTAssertNotNil(UUID(uuidString: record.attemptID))
        XCTAssertGreaterThanOrEqual(record.durationMS, 0)
        for secret in ["private", "Private Name", userID.uuidString, "invalid_credentials", "same_password", "https:"] {
            XCTAssertFalse(record.json.contains(secret))
        }
    }

    private func makeRepository(capture: Bool = true, responder: @escaping (URLRequest) throws -> (Int, Data)) -> AuthRepository {
        AuthDiagnosticRequest.respond = { request in
            XCTAssertEqual(request.url?.host, "auth-diagnostics.invalid")
            self.requests.append(request)
            return try responder(request)
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [AuthDiagnosticRequest.self]
        let client = SupabaseClient(supabaseURL: URL(string: "https://auth-diagnostics.invalid")!, supabaseKey: "synthetic-key",
            options: .init(auth: .init(storage: MemoryAuthDiagnosticStorage(), autoRefreshToken: false),
                           global: .init(session: URLSession(configuration: config), logger: nil)))
        return AuthRepository(client: client, diagnostics: capture ? .init { self.records.append($0) } : .init())
    }

    private func userData(confirmed: Bool = true) throws -> Data {
        var user: [String: Any] = ["id": userID.uuidString, "aud": "authenticated", "role": "authenticated",
            "email": "private@ucf.edu", "app_metadata": [:], "user_metadata": [:],
            "created_at": "2026-01-01T00:00:00Z", "updated_at": "2026-01-01T00:00:00Z", "is_anonymous": false]
        if confirmed { user["email_confirmed_at"] = "2026-01-01T00:00:00Z" }
        return try JSONSerialization.data(withJSONObject: user)
    }

    private func sessionData(confirmed: Bool = true) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["access_token": "private-token", "refresh_token": "private-refresh",
            "token_type": "bearer", "expires_in": 3600, "expires_at": Date().timeIntervalSince1970 + 3600,
            "user": JSONSerialization.jsonObject(with: userData(confirmed: confirmed))])
    }

    private func body(_ request: URLRequest) throws -> [String: Any] {
        var data = request.httpBody ?? Data()
        if let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 2048)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                data.append(contentsOf: buffer.prefix(count))
            }
        }
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}

private final class MemoryAuthDiagnosticStorage: AuthLocalStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Data] = [:]
    func store(key: String, value: Data) throws { lock.lock(); defer { lock.unlock() }; values[key] = value }
    func retrieve(key: String) throws -> Data? { lock.lock(); defer { lock.unlock() }; return values[key] }
    func remove(key: String) throws { lock.lock(); defer { lock.unlock() }; values.removeValue(forKey: key) }
}

private final class AuthDiagnosticRequest: URLProtocol {
    static var respond: ((URLRequest) throws -> (Int, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let responder = try XCTUnwrap(Self.respond)
            let (status, data) = try responder(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil,
                headerFields: ["Content-Type": "application/json", "X-Supabase-Api-Version": "2024-01-01"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}
