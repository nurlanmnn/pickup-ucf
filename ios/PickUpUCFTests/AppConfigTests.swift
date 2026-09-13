import XCTest
@testable import PickUpUCF

final class AppConfigTests: XCTestCase {
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
