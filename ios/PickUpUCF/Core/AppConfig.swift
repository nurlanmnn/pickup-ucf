import Foundation

enum AppConfig {
    /// Keep in sync with Supabase Auth → Email → OTP expiration (300 seconds).
    static let emailOTPExpirySeconds = 300

    static var emailOTPExpiryDescription: String {
        let minutes = emailOTPExpirySeconds / 60
        return minutes == 1 ? "1 minute" : "\(minutes) minutes"
    }

    static var supabaseURL: URL {
        guard let urlString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              let url = URL(string: urlString),
              !urlString.contains("YOUR_PROJECT")
        else {
            return URL(string: "https://placeholder.supabase.co")!
        }
        return url
    }

    static var supabaseAnonKey: String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
              !key.contains("your_anon")
        else {
            return "placeholder"
        }
        return key
    }

    static var isConfigured: Bool {
        guard let urlString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
              let url = URL(string: urlString),
              url.host?.contains("supabase.co") == true
        else { return false }
        return !urlString.contains("YOUR_PROJECT")
            && !key.contains("your_anon")
            && key.hasPrefix("eyJ")
    }
}
