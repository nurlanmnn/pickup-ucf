import Foundation
import Supabase

/// Reject all HTTP from the shared isolated test client; explicit repository fixtures
/// supply their own URLSession and synthetic host.
private final class IsolatedBackendBlocker: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
    }
    override func stopLoading() {}
}

/// Discards isolated auth state rather than touching Keychain (including SDK startup).
private struct IsolatedAuthStorage: AuthLocalStorage {
    func store(key: String, value: Data) throws {}
    func retrieve(key: String) throws -> Data? { nil }
    func remove(key: String) throws {}
}

enum SupabaseManager {
    static let isUnitTestMode = AppTestMode.current == .unit

    static let shared = makeClient(testMode: AppTestMode.current)

    static func makeClient(testMode: AppTestMode) -> SupabaseClient {
        let session: URLSession
        if testMode.isIsolated {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [IsolatedBackendBlocker.self]
            session = URLSession(configuration: configuration)
        } else {
            session = .shared
        }
        return SupabaseClient(
            supabaseURL: testMode.isIsolated ? URL(string: "https://unit-tests.invalid")! : AppConfig.supabaseURL,
            supabaseKey: testMode.isIsolated ? "synthetic-unit-test-key" : AppConfig.supabaseAnonKey,
            options: SupabaseClientOptions(
                auth: testMode.isIsolated
                    ? SupabaseClientOptions.AuthOptions(storage: IsolatedAuthStorage(), autoRefreshToken: false,
                                                        emitLocalSessionAsInitialSession: true)
                    : SupabaseClientOptions.AuthOptions(emitLocalSessionAsInitialSession: true),
                // SDK HTTP descriptions include user content. Keep raw payload logging disabled.
                global: SupabaseClientOptions.GlobalOptions(session: session, logger: nil)
            )
        )
    }
}
