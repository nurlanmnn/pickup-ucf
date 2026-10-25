import Foundation

/// UI isolation is opt-in and unavailable in Release or physical-device builds.
enum AppTestMode: Equatable {
    case normal, unit, uiSmoke

    static let current: AppTestMode = {
        #if DEBUG && targetEnvironment(simulator)
        let supportsUISmoke = true
        #else
        let supportsUISmoke = false
        #endif
        return resolve(arguments: ProcessInfo.processInfo.arguments,
                       environment: ProcessInfo.processInfo.environment,
                       supportsUISmoke: supportsUISmoke)
    }()

    static func resolve(arguments: [String], environment: [String: String], supportsUISmoke: Bool) -> Self {
        if supportsUISmoke && arguments.contains("--pickup-ui-smoke") { return .uiSmoke }
        return environment["PICKUP_UNIT_TESTS"] == "1" ? .unit : .normal
    }

    var isIsolated: Bool { self != .normal }

    func preparePreferences(_ defaults: UserDefaults = .standard) {
        guard self == .uiSmoke else { return }
        defaults.removeObject(forKey: "welcomeIntroCompleted")
    }
}
