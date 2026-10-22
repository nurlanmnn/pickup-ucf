import Foundation
import Supabase

/// Reject all HTTP from the shared unit-test client; explicit repository fixtures
/// supply their own URLSession and synthetic host.
private final class UnitTestBackendBlocker: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
    }
    override func stopLoading() {}
}

enum SupabaseManager {
    static let isUnitTestMode = ProcessInfo.processInfo.environment["PICKUP_UNIT_TESTS"] == "1"

    static let shared: SupabaseClient = {
        let session: URLSession
        if isUnitTestMode {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [UnitTestBackendBlocker.self]
            session = URLSession(configuration: configuration)
        } else {
            session = .shared
        }
        return SupabaseClient(
            supabaseURL: isUnitTestMode ? URL(string: "https://unit-tests.invalid")! : AppConfig.supabaseURL,
            supabaseKey: isUnitTestMode ? "synthetic-unit-test-key" : AppConfig.supabaseAnonKey,
            options: SupabaseClientOptions(
                auth: SupabaseClientOptions.AuthOptions(emitLocalSessionAsInitialSession: true),
                // SDK HTTP descriptions include user content. Keep raw payload logging disabled.
                global: SupabaseClientOptions.GlobalOptions(session: session, logger: nil)
            )
        )
    }()
}
