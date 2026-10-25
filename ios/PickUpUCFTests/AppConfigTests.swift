import XCTest
@testable import PickUpUCF

final class AppConfigTests: XCTestCase {
    func testUnitTestSchemeUsesSyntheticSharedClientAndBlocksHTTP() async {
        XCTAssertEqual(ProcessInfo.processInfo.environment["PICKUP_UNIT_TESTS"], "1")
        XCTAssertTrue(SupabaseManager.isUnitTestMode)
        do {
            _ = try await SupabaseManager.shared.from("profiles").select().execute()
            XCTFail("The shared unit-test client must block backend access")
        } catch {
            XCTAssertEqual((error as? URLError)?.code, .unsupportedURL)
        }
    }

    func testAuthenticatedUISmokeSelectsIsolationWithoutOtherFlags() {
        let mode = AppTestMode.resolve(arguments: ["--pickup-ui-smoke-authenticated"], environment: [:], supportsUISmoke: true)
        XCTAssertTrue(mode.isIsolated, "Authenticated navigation must select isolation before launch")
        XCTAssertEqual(AppConfig.launchMode(isConfigured: false, testMode: mode), .ready)
        XCTAssertEqual(AppTestMode.resolve(arguments: ["--pickup-ui-smoke-authenticated"], environment: [:], supportsUISmoke: false), .normal)
        XCTAssertEqual(AppTestMode.resolve(arguments: ["--pickup-ui-smoke-authenticated=yes"], environment: [:], supportsUISmoke: true), .normal)
    }

    #if DEBUG && targetEnvironment(simulator)
    func testAuthenticatedUIFixtureUsesRealSDKAndRepositories() async throws {
        let client = SupabaseManager.makeClient(testMode: .uiSmokeAuthenticated)
        let session = try await client.auth.session
        XCTAssertEqual(session.user.id, AuthenticatedUISmokeFixture.userID)
        XCTAssertFalse(session.isExpired)
        let profile = try await ProfileRepository(client: client).fetchCurrentProfile()
        XCTAssertEqual(profile.displayName, "UI Smoke Student")
        XCTAssertEqual(profile.gamesPlayed, 7)
        XCTAssertEqual(profile.preferredSports, [.basketball])
        let repository = SessionRepository(client: client)
        let upcoming = try await repository.fetchUpcoming(sport: nil)
        XCTAssertEqual(upcoming.map(\.id), [AuthenticatedUISmokeFixture.gameID])
        XCTAssertEqual(upcoming.first?.locationName, "UI Smoke Court")
        let own = try await repository.fetchMySessions(userId: session.user.id)
        XCTAssertEqual(own, upcoming)
        let statuses = try await repository.fetchParticipantStatuses(userId: session.user.id, sessionIds: own.map(\.id))
        XCTAssertEqual(statuses, [AuthenticatedUISmokeFixture.gameID: .joined])
        let past = try await repository.fetchMyPastSessions(limit: 10, offset: 0)
        XCTAssertEqual(past.map(\.id), [AuthenticatedUISmokeFixture.pastGameID])
        let venues = try await repository.fetchVenues()
        let blocked = try await BlockRepository(client: client).fetchBlockedUserIds()
        XCTAssertTrue(venues.isEmpty)
        XCTAssertTrue(blocked.isEmpty)
    }

    func testAuthenticatedUITransportDeniesWritesAuthAndUnrecognizedRequests() async throws {
        let client = SupabaseManager.makeClient(testMode: .uiSmokeAuthenticated)
        do {
            try await ProfileRepository(client: client).updateUsername("should-not-write")
            XCTFail("Fixture transport must deny mutations")
        } catch { XCTAssertEqual((error as? URLError)?.code, .unsupportedURL) }
        do {
            _ = try await client.auth.user()
            XCTFail("Fixture transport must deny real auth validation")
        } catch { XCTAssertEqual((error as? URLError)?.code, .unsupportedURL) }
        for (method, url) in [
            ("GET", "https://foreign.invalid/rest/v1/venues"),
            ("GET", "http://ui-smoke.invalid/rest/v1/venues"),
            ("GET", "https://ui-smoke.invalid:444/rest/v1/venues"),
            ("GET", "https://ui-smoke.invalid/rest/v1/unknown"),
            ("POST", "https://ui-smoke.invalid/rest/v1/profiles"),
            ("DELETE", "https://ui-smoke.invalid/rest/v1/sessions"),
            ("POST", "https://ui-smoke.invalid/rest/v1/rpc/delete_own_account"),
            ("GET", "https://ui-smoke.invalid/rest/v1/profiles?id=eq.00000000-0000-0000-0000-000000000099")
        ] {
            var request = URLRequest(url: try XCTUnwrap(URL(string: url)))
            request.httpMethod = method
            request.setValue("Bearer \(AuthenticatedUISmokeFixture.accessToken)", forHTTPHeaderField: "Authorization")
            XCTAssertThrowsError(try AuthenticatedUISmokeFixture.response(for: request)) {
                XCTAssertEqual(($0 as? URLError)?.code, .unsupportedURL)
            }
        }
        let other = SupabaseManager.makeClient(testMode: .uiSmokeAuthenticated)
        do {
            try await client.auth.signOut(scope: .local)
            XCTFail("Even local-scope SDK logout must not reach a backend")
        } catch { XCTAssertEqual((error as? URLError)?.code, .unsupportedURL) }
        let removedSession = try? await client.auth.session
        XCTAssertNil(removedSession)
        let independent = try await other.auth.session
        XCTAssertEqual(independent.user.id, AuthenticatedUISmokeFixture.userID)
        let original = SupabaseManager.makeClient(testMode: .uiSmoke)
        let unauthenticated = try? await original.auth.session
        XCTAssertNil(unauthenticated)
    }

    #endif

    func testUISmokeArgumentSelectsIsolationWithoutUnitEnvironment() async {
        let mode = AppTestMode.resolve(arguments: ["app", "--pickup-ui-smoke"], environment: [:], supportsUISmoke: true)
        XCTAssertEqual(mode, .uiSmoke)
        XCTAssertTrue(mode.isIsolated)
        XCTAssertEqual(AppConfig.launchMode(isConfigured: false, testMode: mode), .ready)
        let client = SupabaseManager.makeClient(testMode: mode)
        do {
            _ = try await client.from("profiles").select().execute()
            XCTFail("UI mode must block SDK HTTP without any other flag")
        } catch {
            XCTAssertEqual((error as? URLError)?.code, .unsupportedURL)
        }
        let restoredSession = try? await client.auth.session
        XCTAssertNil(restoredSession)
    }

    func testUISmokeFlagIsExactAndDisabledOutsideSupportedBuilds() {
        XCTAssertEqual(AppTestMode.resolve(arguments: [], environment: [:], supportsUISmoke: true), .normal)
        XCTAssertEqual(AppTestMode.resolve(arguments: ["--pickup-ui-smoke=yes"], environment: [:], supportsUISmoke: true), .normal)
        XCTAssertEqual(AppTestMode.resolve(arguments: ["--pickup-ui-smoke"], environment: [:], supportsUISmoke: false), .normal)
        XCTAssertEqual(AppTestMode.resolve(arguments: [], environment: ["PICKUP_UNIT_TESTS": "1"], supportsUISmoke: false), .unit)
        XCTAssertEqual(AppConfig.launchMode(isConfigured: false, testMode: .normal), .serviceUnavailable)
        XCTAssertEqual(AppConfig.launchMode(isConfigured: false, testMode: .unit), .serviceUnavailable)
    }

    func testUISmokeResetsOnlyWelcomePreference() throws {
        let name = "ui-smoke-preferences-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(true, forKey: "welcomeIntroCompleted")
        defaults.set("preserve", forKey: "unrelated")
        AppTestMode.normal.preparePreferences(defaults)
        XCTAssertTrue(defaults.bool(forKey: "welcomeIntroCompleted"))
        AppTestMode.uiSmoke.preparePreferences(defaults)
        XCTAssertFalse(defaults.bool(forKey: "welcomeIntroCompleted"))
        XCTAssertEqual(defaults.string(forKey: "unrelated"), "preserve")
    }

    func testLaunchModePreventsBackendAccessWhenConfigurationIsUnavailable() {
        XCTAssertEqual(
            AppConfig.launchMode(isConfigured: false),
            .serviceUnavailable
        )
        XCTAssertEqual(
            AppConfig.launchMode(isConfigured: true),
            .ready
        )
    }

    func testAcceptsCompleteProductionSupabaseConfiguration() {
        let configuration = AppConfig.validatedSupabaseConfiguration(
            urlString: "https://project-ref.supabase.co",
            anonKey: "eyJ" + "fixture"
        )

        XCTAssertEqual(configuration?.url.host, "project-ref.supabase.co")
        XCTAssertEqual(configuration?.anonKey, "eyJ" + "fixture")
    }

    func testRejectsPlaceholderOrIncompleteSupabaseConfiguration() {
        XCTAssertNil(AppConfig.validatedSupabaseConfiguration(
            urlString: "https://placeholder.supabase.co",
            anonKey: "eyJ" + "fixture"
        ))
        XCTAssertNil(AppConfig.validatedSupabaseConfiguration(
            urlString: "https://project-ref.supabase.co",
            anonKey: "placeholder"
        ))
        XCTAssertNil(AppConfig.validatedSupabaseConfiguration(
            urlString: nil,
            anonKey: nil
        ))
    }

    func testRejectsInsecureOrUnexpectedSupabaseHosts() {
        XCTAssertNil(AppConfig.validatedSupabaseConfiguration(
            urlString: "http://project-ref.supabase.co",
            anonKey: "eyJ" + "fixture"
        ))
        XCTAssertNil(AppConfig.validatedSupabaseConfiguration(
            urlString: "https://supabase.invalid",
            anonKey: "eyJ" + "fixture"
        ))
    }
}
