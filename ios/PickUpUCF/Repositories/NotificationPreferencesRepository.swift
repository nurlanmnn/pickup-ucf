import Foundation
import Supabase

protocol NotificationPreferencesRepositoryProtocol {
    func fetch() async throws -> NotificationPreferences
    func save(_ preferences: NotificationPreferences) async throws
}

final class NotificationPreferencesRepository: NotificationPreferencesRepositoryProtocol {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseManager.shared) {
        self.client = client
    }

    func fetch() async throws -> NotificationPreferences {
        let userId = try await client.auth.session.user.id

        let rows: [NotificationPreferences] = try await client
            .from("notification_preferences")
            .select()
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value

        return rows.first ?? .defaults(userId: userId)
    }

    func save(_ preferences: NotificationPreferences) async throws {
        try await client
            .from("notification_preferences")
            .upsert(preferences)
            .execute()
    }
}
