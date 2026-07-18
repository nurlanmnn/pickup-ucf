import Foundation
import Supabase

protocol ProfileRepositoryProtocol {
    func ensureProfileForCurrentUser() async throws
    func ensureProfile(userId: UUID, displayName: String) async throws
    func fetchCurrentProfile() async throws -> Profile
    func completeOnboarding(sports: [SportType]) async throws
    func updatePreferredSports(_ sports: [SportType]) async throws
    func updateUsername(_ username: String) async throws
    func deleteAccount() async throws
}

final class ProfileRepository: ProfileRepositoryProtocol {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseManager.shared) {
        self.client = client
    }

    func ensureProfileForCurrentUser() async throws {
        let session = try await client.auth.session
        let displayName = Self.displayName(from: session.user)
        try await ensureProfile(userId: session.user.id, displayName: displayName)
    }

    func ensureProfile(userId: UUID, displayName: String) async throws {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ProfileRepositoryError.missingDisplayName
        }

        let row = ProfileUpsert(id: userId, displayName: trimmed)
        try await client
            .from("profiles")
            .upsert(row, onConflict: "id")
            .execute()
    }

    func fetchCurrentProfile() async throws -> Profile {
        let userId = try await client.auth.session.user.id
        return try await client
            .from("profiles")
            .select(
                "id, display_name, username, games_played, show_up_streak, preferred_sports, onboarding_completed_at"
            )
            .eq("id", value: userId.uuidString)
            .single()
            .execute()
            .value
    }

    func completeOnboarding(sports: [SportType]) async throws {
        try await client
            .rpc(
                "complete_onboarding",
                params: CompleteOnboardingParams(pPreferredSports: sports)
            )
            .execute()
    }

    func updatePreferredSports(_ sports: [SportType]) async throws {
        guard !sports.isEmpty else {
            throw ProfileRepositoryError.preferredSportsRequired
        }

        let userId = try await client.auth.session.user.id
        let update = ProfilePreferredSportsUpdate(preferredSports: sports)
        try await client
            .from("profiles")
            .update(update)
            .eq("id", value: userId.uuidString)
            .execute()
    }

    func updateUsername(_ username: String) async throws {
        let normalized = username.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let userId = try await client.auth.session.user.id
        try await client
            .from("profiles")
            .update(["username": normalized])
            .eq("id", value: userId.uuidString)
            .execute()
    }

    func deleteAccount() async throws {
        try await client.rpc("delete_own_account").execute()
    }

    static func displayName(from user: User) -> String {
        if case let .string(name)? = user.userMetadata["display_name"],
           !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return name.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let email = user.email,
           let local = email.split(separator: "@").first,
           !local.isEmpty {
            return String(local)
        }
        return "Student"
    }
}

struct ProfilePreferredSportsUpdate: Encodable {
    let preferredSports: [SportType]

    enum CodingKeys: String, CodingKey {
        case preferredSports = "preferred_sports"
    }
}

struct CompleteOnboardingParams: Encodable {
    let pPreferredSports: [SportType]

    enum CodingKeys: String, CodingKey {
        case pPreferredSports = "p_preferred_sports"
    }
}

enum ProfileRepositoryError: LocalizedError {
    case missingDisplayName
    case preferredSportsRequired

    var errorDescription: String? {
        switch self {
        case .missingDisplayName:
            return "Display name is required for your profile."
        case .preferredSportsRequired:
            return "Select at least one sport."
        }
    }
}

