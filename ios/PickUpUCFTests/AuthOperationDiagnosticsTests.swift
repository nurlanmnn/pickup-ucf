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

    func testAccountDeletionRPCPreservesEmptyPayloadAndFreshAttempts() async throws {
        let repo = makeProfileRepository { _ in (204, Data()) }
        try await repo.deleteAccount()
        try await repo.deleteAccount()
        XCTAssertEqual(requests.map { $0.url!.path }, ["/rest/v1/rpc/delete_own_account", "/rest/v1/rpc/delete_own_account"])
        XCTAssertEqual(requests.map(\.httpMethod), ["POST", "POST"])
        for request in requests {
            XCTAssertNil(request.httpBody)
            XCTAssertNil(request.httpBodyStream)
            XCTAssertNil(request.url?.query)
        }
        XCTAssertEqual(records.map(\.operation), [.deleteOwnAccountRPC, .deleteOwnAccountRPC])
        XCTAssertEqual(records.map(\.result), [.succeeded, .succeeded])
        XCTAssertEqual(records.map(\.failure), [.none, .none])
        XCTAssertEqual(Set(records.map(\.attemptID)).count, 2)
        for record in records { try assertPrivateRecord(record) }
    }

    func testAccountDeletionBackendErrorsRetainExactSDKErrorWithoutFallback() async throws {
        for code in ["42501", "PGRST202"] {
            records.removeAll(); requests.removeAll()
            let repo = makeProfileRepository { _ in
                (400, Data("{\"code\":\"\(code)\",\"message\":\"private-server-message\",\"details\":\"private-detail\",\"hint\":\"private-hint\"}".utf8))
            }
            do { try await repo.deleteAccount(); XCTFail() }
            catch let error as PostgrestError {
                XCTAssertEqual(error.code, code)
                XCTAssertEqual(error.message, "private-server-message")
                // The pinned SDK leaves the server's plural `details` field unmapped.
                XCTAssertNil(error.detail)
                XCTAssertEqual(error.hint, "private-hint")
            }
            XCTAssertEqual(requests.map { $0.url!.path }, ["/rest/v1/rpc/delete_own_account"])
            XCTAssertEqual(requests.map(\.httpMethod), ["POST"])
            XCTAssertEqual(records.map(\.operation), [.deleteOwnAccountRPC])
            XCTAssertEqual(records.map(\.result), [.failed])
            XCTAssertEqual(records.map(\.failure), [.backend])
            for record in records {
                try assertPrivateRecord(record)
            }
        }
    }

    func testAccountDeletionTransportAndCancellationRetainErrors() async throws {
        for code in [URLError.notConnectedToInternet, .cancelled] {
            records.removeAll(); requests.removeAll()
            let repo = makeProfileRepository { _ in throw URLError(code, userInfo: [NSLocalizedDescriptionKey: "private-error"]) }
            do { try await repo.deleteAccount(); XCTFail() }
            catch let error as URLError { XCTAssertEqual(error.code, code) }
            XCTAssertEqual(requests.map { $0.url!.path }, ["/rest/v1/rpc/delete_own_account"])
            XCTAssertEqual(records.map(\.operation), [.deleteOwnAccountRPC])
            XCTAssertEqual(records.map(\.result), [code == .cancelled ? .cancelled : .failed])
            XCTAssertEqual(records.map(\.failure), [code == .cancelled ? .cancelled : .transport])
            for record in records { try assertPrivateRecord(record) }
        }
    }

    func testAccountDeletionDefaultLoggerSmokeWithRealSDK() async throws {
        for rejected in [false, true] {
            let repo = makeProfileRepository(capture: false) { _ in
                rejected ? (403, Data(#"{"code":"42501","message":"private-server-message"}"#.utf8)) : (204, Data())
            }
            do { try await repo.deleteAccount(); XCTAssertFalse(rejected) }
            catch { XCTAssertTrue(rejected); XCTAssertTrue(error is PostgrestError) }
        }
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
        let client = makeClient(responder: responder)
        return AuthRepository(client: client, diagnostics: capture ? .init { self.records.append($0) } : .init())
    }

    private func makeProfileRepository(capture: Bool = true, responder: @escaping (URLRequest) throws -> (Int, Data)) -> ProfileRepository {
        let client = makeClient(responder: responder)
        return ProfileRepository(client: client, diagnostics: capture ? .init { self.records.append($0) } : .init())
    }

    private func makeClient(responder: @escaping (URLRequest) throws -> (Int, Data)) -> SupabaseClient {
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
        return client
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

final class AuthRestorationDiagnosticsTests: XCTestCase {
    private var records: [AuthOperationDiagnostics.Record] = []
    private var requests: [URLRequest] = []
    private let userID = UUID()

    override func tearDown() {
        RestorationRequest.respond = nil
        super.tearDown()
    }

    func testVerifiedRestoreMapsRemoteUserAndRetriesGetFreshAttempts() async throws {
        let client = makeClient { _ in (200, try self.userData(email: "remote@ucf.edu")) }
        try await seed(client)
        let repository = repository(client)
        for _ in 0..<2 {
            let restored = await repository.currentSession()
            XCTAssertEqual(restored?.userId, userID)
            XCTAssertEqual(restored?.email, "remote@ucf.edu")
            XCTAssertEqual(restored?.isEmailConfirmed, true)
        }
        XCTAssertEqual(requests.map { $0.url!.lastPathComponent }, ["user", "user"])
        XCTAssertTrue(requests.allSatisfy { $0.value(forHTTPHeaderField: "Authorization") == "Bearer private-token" })
        XCTAssertEqual(records.map { $0.result.rawValue }, ["verified", "verified"])
        XCTAssertEqual(records.map(\.failure), [.none, .none])
        if records.count == 2 { XCTAssertNotEqual(records[0].attemptID, records[1].attemptID) }
        try assertRecords()
    }

    func testExpiredSessionRefreshFailureReturnsNilAndRecordsUnavailable() async throws {
        let client = makeClient { request in
            XCTAssertEqual(request.url?.lastPathComponent, "token")
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems
            XCTAssertEqual(query?.first(where: { $0.name == "grant_type" })?.value, "refresh_token")
            throw URLError(.notConnectedToInternet)
        }
        try await seed(client, expired: true)
        let result = await repository(client).currentSession()
        XCTAssertNil(result)
        XCTAssertFalse(requests.isEmpty)
        XCTAssertEqual(records.map { $0.result.rawValue }, ["unavailable"])
        XCTAssertEqual(records.map(\.failure), [.transport])
        try assertRecords()
    }

    func testExpiredSessionInvalidationReportsSDKMissingWithoutInventingAbsenceCause() async throws {
        let client = makeClient { request in
            XCTAssertEqual(request.url?.lastPathComponent, "token")
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems
            XCTAssertEqual(query?.first(where: { $0.name == "grant_type" })?.value, "refresh_token")
            return (401, Data(#"{"code":"session_expired","msg":"private-token"}"#.utf8))
        }
        try await seed(client, expired: true)
        XCTAssertNotNil(client.auth.currentSession)
        let result = await repository(client).currentSession()
        XCTAssertNil(result)
        XCTAssertNil(client.auth.currentSession)
        XCTAssertEqual(requests.map { $0.url!.lastPathComponent }, ["token"])
        XCTAssertEqual(records.map { $0.result.rawValue }, ["session_missing"])
        XCTAssertEqual(records.map(\.failure), [.none])
        try assertRecords()
    }

    func testNoCachedSessionReturnsNilWithoutHTTPAndNeverLogsSuccess() async throws {
        let client = makeClient { _ in XCTFail("No HTTP expected"); return (500, Data()) }
        let result = await repository(client).currentSession()
        XCTAssertNil(result)
        XCTAssertTrue(requests.isEmpty)
        XCTAssertEqual(records.map { $0.result.rawValue }, ["session_missing"])
        XCTAssertEqual(records.map(\.failure), [.none])
        try assertRecords()
    }

    func testCachedRejectionKeepsMappingAndConfirmationCleanupDistinct() async throws {
        for missingEmail in [true, false] {
            records.removeAll(); requests.removeAll()
            let client = makeClient { request in
                XCTAssertEqual(request.url?.lastPathComponent, "logout")
                return (204, Data())
            }
            try await seed(client, confirmed: missingEmail, email: missingEmail ? nil : "private@ucf.edu")
            let result = await repository(client).currentSession()
            XCTAssertNil(result)
            XCTAssertEqual(records.map { $0.result.rawValue }, ["rejected_cached"])
            XCTAssertEqual(records.map(\.failure), [.localPolicy])
            if missingEmail {
                XCTAssertTrue(requests.isEmpty)
                XCTAssertNotNil(client.auth.currentSession, "Original mapping rejection does not sign out")
            } else {
                XCTAssertNil(client.auth.currentSession)
                XCTAssertEqual(requests.map { $0.url!.lastPathComponent }, ["logout"])
            }
            try assertRecords()
        }
    }

    func testRemoteIdentityOrConfirmationRejectionClearsSessionEvenWhenLogoutFails() async throws {
        for wrongIdentity in [true, false] {
            records.removeAll(); requests.removeAll()
            let client = makeClient { request in
                if request.url?.lastPathComponent == "logout" { throw URLError(.notConnectedToInternet) }
                return (200, try self.userData(id: wrongIdentity ? UUID() : self.userID, confirmed: wrongIdentity))
            }
            try await seed(client)
            let result = await repository(client).currentSession()
            XCTAssertNil(result)
            XCTAssertNil(client.auth.currentSession)
            XCTAssertEqual(records.map { $0.result.rawValue }, ["rejected_remote"])
            XCTAssertEqual(records.map(\.failure), [.localPolicy])
            XCTAssertTrue(requests.contains { $0.url?.lastPathComponent == "logout" })
            try assertRecords()
        }
    }

    func testKnownInvalidationCodesRejectAndCleanUpWithoutLoggingCode() async throws {
        for code in ["user_not_found", "session_not_found", "session_expired", "bad_jwt", "refresh_token_not_found"] {
            records.removeAll(); requests.removeAll()
            let client = makeClient { request in
                if request.url?.lastPathComponent == "logout" { return (204, Data()) }
                return (401, Data("{\"code\":\"\(code)\",\"msg\":\"private-token private@ucf.edu\"}".utf8))
            }
            try await seed(client)
            let result = await repository(client).currentSession()
            XCTAssertNil(result)
            XCTAssertNil(client.auth.currentSession)
            let sdkClearsSession = ["session_not_found", "session_expired", "refresh_token_not_found"].contains(code)
            XCTAssertEqual(records.map { $0.result.rawValue }, [sdkClearsSession ? "superseded" : "invalidated"], code)
            XCTAssertEqual(records.map(\.failure), [.backend])
            XCTAssertEqual(requests.filter { $0.url?.lastPathComponent == "logout" }.count, sdkClearsSession ? 0 : 1, code)
            XCTAssertFalse(records.contains { $0.json.contains(code) })
            try assertRecords()
        }
    }

    func testInvalidationPreservesPrimaryOutcomeWhenLocalLogoutRequestFails() async throws {
        let client = makeClient { request in
            if request.url?.lastPathComponent == "logout" { throw URLError(.notConnectedToInternet) }
            return (401, Data(#"{"code":"user_not_found","msg":"private-token"}"#.utf8))
        }
        try await seed(client)
        let result = await repository(client).currentSession()
        XCTAssertNil(result)
        XCTAssertNil(client.auth.currentSession)
        XCTAssertEqual(records.map { $0.result.rawValue }, ["invalidated"])
        XCTAssertEqual(records.map(\.failure), [.backend])
        XCTAssertTrue(requests.contains { $0.url?.lastPathComponent == "logout" })
        try assertRecords()
    }

    func testVerificationFailuresPreserveCachedFallbackIncludingCancellationAndMapping() async throws {
        let cases: [(String, AuthOperationDiagnostics.Failure)] = [
            ("offline", .transport), ("backend", .backend), ("decode", .decoding),
            ("cancel", .cancelled), ("map", .localPolicy)]
        for (kind, failure) in cases {
            records.removeAll(); requests.removeAll()
            let client = makeClient { request in
                XCTAssertEqual(request.url?.lastPathComponent, "user", "Fallback must not sign out")
                switch kind {
                case "offline": throw URLError(.notConnectedToInternet)
                case "cancel": throw URLError(.cancelled)
                case "backend": return (403, Data(#"{"code":"unexpected_failure","msg":"private-token"}"#.utf8))
                case "decode": return (200, Data("{}".utf8))
                default: return (200, try self.userData(email: nil))
                }
            }
            try await seed(client)
            let result = await repository(client).currentSession()
            XCTAssertEqual(result?.email, "private@ucf.edu")
            XCTAssertEqual(result?.userId, userID)
            XCTAssertNotNil(client.auth.currentSession)
            XCTAssertEqual(records.map { $0.result.rawValue }, ["cached_fallback"])
            XCTAssertEqual(records.map(\.failure), [failure])
            try assertRecords()
        }
    }

    func testAccountSwitchDuringSuccessInvalidationOrFallbackNeverRestoresOrClearsNewAccount() async throws {
        for mode in ["success", "invalid", "offline"] {
            records.removeAll(); requests.removeAll()
            let newID = UUID()
            var activeClient: SupabaseClient!
            activeClient = makeClient { request in
                XCTAssertEqual(request.url?.lastPathComponent, "user")
                // Replace the SDK cache while the original verification is in flight.
                try await self.seed(activeClient, id: newID)
                switch mode {
                case "invalid": return (401, Data(#"{"code":"user_not_found","msg":"private-token"}"#.utf8))
                case "offline": throw URLError(.notConnectedToInternet)
                default: return (200, try self.userData())
                }
            }
            try await seed(activeClient)
            let result = await repository(activeClient).currentSession()
            XCTAssertNil(result)
            XCTAssertEqual(activeClient.auth.currentUser?.id, newID)
            XCTAssertEqual(records.map { $0.result.rawValue }, ["superseded"])
            XCTAssertEqual(records.map(\.failure), [mode == "success" ? .none : mode == "invalid" ? .backend : .transport])
            try assertRecords()
        }
    }

    func testDefaultLoggerRecordsRealRestoreBoundary() async throws {
        let client = makeClient { _ in throw URLError(.notConnectedToInternet) }
        try await seed(client)
        let result = await AuthRepository(client: client).currentSession()
        XCTAssertEqual(result?.userId, userID)
    }

    private func repository(_ client: SupabaseClient) -> AuthRepository {
        AuthRepository(client: client, diagnostics: .init { self.records.append($0) })
    }

    private func assertRecords() throws {
        XCTAssertFalse(records.isEmpty)
        for record in records {
            XCTAssertEqual(record.operation.rawValue, "restore")
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(record.json.utf8)) as? [String: Any])
            XCTAssertEqual(Set(json.keys), Set(["event", "operation", "result", "failure", "attempt_id", "duration_ms", "version", "build", "configuration", "environment"]))
            XCTAssertEqual(json["event"] as? String, "auth_operation")
            XCTAssertEqual(json["environment"] as? String, "unit_test")
            XCTAssertNotNil(UUID(uuidString: record.attemptID))
            XCTAssertGreaterThanOrEqual(record.durationMS, 0)
            for secret in ["private", "remote@", userID.uuidString, "https:", "user_not_found", "bad_jwt"] {
                XCTAssertFalse(record.json.contains(secret))
            }
        }
    }

    private func makeClient(responder: @escaping (URLRequest) async throws -> (Int, Data)) -> SupabaseClient {
        RestorationRequest.respond = { request in
            XCTAssertEqual(request.url?.host, "restore-diagnostics.invalid")
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems
            if request.url?.lastPathComponent == "token",
               query?.first(where: { $0.name == "grant_type" })?.value == "password" {
                return (200, RestorationRequest.tokenData)
            }
            self.requests.append(request)
            return try await responder(request)
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [RestorationRequest.self]
        return SupabaseClient(supabaseURL: URL(string: "https://restore-diagnostics.invalid")!, supabaseKey: "synthetic-key",
            options: .init(auth: .init(storage: MemoryAuthDiagnosticStorage(), autoRefreshToken: false),
                           global: .init(session: URLSession(configuration: config), logger: nil)))
    }

    private func seed(_ client: SupabaseClient, id: UUID? = nil, confirmed: Bool = true, email: String? = "private@ucf.edu", expired: Bool = false) async throws {
        RestorationRequest.tokenData = try JSONSerialization.data(withJSONObject: [
            "access_token": "private-token", "refresh_token": "private-refresh", "token_type": "bearer",
            "expires_in": 3600, "expires_at": Date().timeIntervalSince1970 + (expired ? -3600 : 3600),
            "user": JSONSerialization.jsonObject(with: userData(id: id, confirmed: confirmed, email: email))])
        _ = try await client.auth.signIn(email: "private@ucf.edu", password: "private-password")
    }

    private func userData(id: UUID? = nil, confirmed: Bool = true, email: String? = "private@ucf.edu") throws -> Data {
        var user: [String: Any] = ["id": (id ?? userID).uuidString, "aud": "authenticated", "role": "authenticated",
            "app_metadata": [:], "user_metadata": [:], "created_at": "2026-01-01T00:00:00Z",
            "updated_at": "2026-01-01T00:00:00Z", "is_anonymous": false]
        user["email"] = email
        if confirmed { user["email_confirmed_at"] = "2026-01-01T00:00:00Z" }
        return try JSONSerialization.data(withJSONObject: user)
    }
}

private final class RestorationRequest: URLProtocol {
    static var tokenData = Data()
    static var respond: ((URLRequest) async throws -> (Int, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Task {
            do {
                let responder = try XCTUnwrap(Self.respond)
                let (status, data) = try await responder(request)
                let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil,
                    headerFields: ["Content-Type": "application/json", "X-Supabase-Api-Version": "2024-01-01"])!
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            } catch { client?.urlProtocol(self, didFailWithError: error) }
        }
    }
    override func stopLoading() {}
}
