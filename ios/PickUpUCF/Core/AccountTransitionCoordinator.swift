import Foundation

enum AccountTransitionFailure: Equatable, Hashable {
    case deviceTokenCleanup
    case remoteSignOut
}

enum AccountTransitionOutcome: Equatable {
    case completed
    case completedWithWarning(Set<AccountTransitionFailure>)

    var hasWarning: Bool {
        if case .completedWithWarning = self { return true }
        return false
    }
}

enum AccountTransitionCoordinator {
    @MainActor
    static func signOut(
        appState: AppState,
        unregisterToken: () async throws -> Void,
        signOut: () async throws -> Void
    ) async -> AccountTransitionOutcome {
        var failures: Set<AccountTransitionFailure> = []

        do {
            try await unregisterToken()
        } catch {
            failures.insert(.deviceTokenCleanup)
        }

        do {
            try await signOut()
        } catch {
            // Supabase Swift removes the persisted local session before its
            // remote logout request, so a network failure is safe to finish locally.
            failures.insert(.remoteSignOut)
        }

        appState.session = nil
        return failures.isEmpty ? .completed : .completedWithWarning(failures)
    }

    @MainActor
    static func deleteAccount(
        appState: AppState,
        unregisterToken: () async throws -> Void,
        deleteAccount: () async throws -> Void,
        signOut: () async throws -> Void,
        restoreNotifications: () async -> Void
    ) async throws -> AccountTransitionOutcome {
        var failures: Set<AccountTransitionFailure> = []

        do {
            try await unregisterToken()
        } catch {
            failures.insert(.deviceTokenCleanup)
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
            failures.insert(.remoteSignOut)
        }

        appState.session = nil
        return failures.isEmpty ? .completed : .completedWithWarning(failures)
    }
}
