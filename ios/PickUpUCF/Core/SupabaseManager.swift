import Foundation
import Supabase

private struct SupabaseConsoleLogger: SupabaseLogger {
    func log(message: SupabaseLogMessage) {
        #if DEBUG
        let level: String
        switch message.level {
        case .debug: level = "DEBUG"
        case .verbose: level = "VERBOSE"
        case .warning: level = "WARN"
        case .error: level = "ERROR"
        }
        print("[Supabase:\(level)] \(message.description)")
        #endif
    }
}

enum SupabaseManager {
    static let shared: SupabaseClient = {
        SupabaseClient(
            supabaseURL: AppConfig.supabaseURL,
            supabaseKey: AppConfig.supabaseAnonKey,
            options: SupabaseClientOptions(
                auth: SupabaseClientOptions.AuthOptions(
                    emitLocalSessionAsInitialSession: true
                ),
                global: SupabaseClientOptions.GlobalOptions(
                    logger: SupabaseConsoleLogger()
                )
            )
        )
    }()
}
