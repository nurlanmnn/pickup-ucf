import Foundation

enum AccountTransitionOutcome: Equatable {
    case completed
    case completedWithWarning
}

enum AccountTransitionCoordinator {
    @MainActor
    static func signOut(
        appState: AppState,
        unregisterToken: () async throws -> Void,
        signOut: () async throws -> Void
    ) async -> AccountTransitionOutcome {
        var needsWarning = false

        do {
            try await unregisterToken()
        } catch {
            needsWarning = true
        }

        do {
            try await signOut()
        } catch {
            // Supabase Swift removes the persisted local session before its
            // remote logout request, so a network failure is safe to finish locally.
            needsWarning = true
        }

        appState.session = nil
        return needsWarning ? .completedWithWarning : .completed
    }

    @MainActor
    static func deleteAccount(
        appState: AppState,
        unregisterToken: () async throws -> Void,
        deleteAccount: () async throws -> Void,
        signOut: () async throws -> Void,
        restoreNotifications: () async -> Void
    ) async throws -> AccountTransitionOutcome {
        var needsWarning = false

        do {
            try await unregisterToken()
        } catch {
            needsWarning = true
        }

        do {
            try await deleteAccount()
        } catch {
            // The account still exists. Restore registration from the retained
            // token so a failed deletion does not silently disable notifications.
            await restoreNotifications()
            throw error
        }

        do {
            try await signOut()
        } catch {
            needsWarning = true
        }

        appState.session = nil
        return needsWarning ? .completedWithWarning : .completed
    }
}
