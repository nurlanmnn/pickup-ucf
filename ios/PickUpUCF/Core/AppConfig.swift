import Foundation

struct SupabaseConfiguration {
    let url: URL
    let anonKey: String
}

enum AppLaunchMode {
    case ready
    case serviceUnavailable
}

enum AppConfig {
    /// Keep in sync with Supabase Auth → Email → OTP expiration (300 seconds).
    static let emailOTPExpirySeconds = 300

    /// How far ahead a session can be scheduled (in hours).
    static let sessionScheduleWindowHours = 168  // 7 days

    static var emailOTPExpiryDescription: String {
        let minutes = emailOTPExpirySeconds / 60
        return minutes == 1 ? "1 minute" : "\(minutes) minutes"
    }

    private static var supabaseConfiguration: SupabaseConfiguration? {
        validatedSupabaseConfiguration(
            urlString: Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            anonKey: Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String
        )
    }

    static var supabaseURL: URL {
        guard let configuration = supabaseConfiguration else {
            preconditionFailure("Supabase configuration is unavailable.")
        }
        return configuration.url
    }

    static var supabaseAnonKey: String {
        guard let configuration = supabaseConfiguration else {
            preconditionFailure("Supabase configuration is unavailable.")
        }
        return configuration.anonKey
    }

    static var isConfigured: Bool {
        supabaseConfiguration != nil
    }

    static var currentLaunchMode: AppLaunchMode {
        launchMode(isConfigured: isConfigured)
    }

    static func launchMode(isConfigured: Bool) -> AppLaunchMode {
        isConfigured ? .ready : .serviceUnavailable
    }

    static func validatedSupabaseConfiguration(
        urlString: String?,
        anonKey: String?
    ) -> SupabaseConfiguration? {
        guard let urlString = urlString?.trimmingCharacters(in: .whitespacesAndNewlines),
              let anonKey = anonKey?.trimmingCharacters(in: .whitespacesAndNewlines),
              !urlString.isEmpty,
              !anonKey.isEmpty,
              !urlString.lowercased().contains("placeholder"),
              !urlString.lowercased().contains("your_project"),
              !anonKey.lowercased().contains("placeholder"),
              !anonKey.lowercased().contains("your_anon"),
              anonKey.hasPrefix("eyJ"),
              let url = URL(string: urlString),
              url.scheme?.lowercased() == "https",
              let host = url.host?.lowercased(),
              host.hasSuffix(".supabase.co"),
              url.user == nil,
              url.password == nil,
              url.port == nil,
              url.query == nil,
              url.fragment == nil,
              url.path.isEmpty || url.path == "/"
        else {
            return nil
        }

        return SupabaseConfiguration(url: url, anonKey: anonKey)
    }
}
