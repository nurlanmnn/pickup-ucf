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
