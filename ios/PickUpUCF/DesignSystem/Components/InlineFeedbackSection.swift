import SwiftUI

/// Standard form feedback: show validation/API errors and optional success copy.
struct InlineFeedbackSection: View {
    var error: String?
    var success: String?

    var body: some View {
        if let error, !error.isEmpty {
            Section {
                ErrorBanner(message: error, tone: Self.tone(for: error))
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }

        if let success, !success.isEmpty {
            Section {
                SuccessBanner(message: success)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    /// Softer banner for long “ops / schema” messages; red for everything else.
    private static func tone(for message: String) -> ErrorBanner.Tone {
        let lower = message.lowercased()
        if lower.contains("migration")
            || lower.contains("schema")
            || lower.contains("project admin")
            || lower.contains("reload schema") {
            return .warning
        }
        return .critical
    }
}
