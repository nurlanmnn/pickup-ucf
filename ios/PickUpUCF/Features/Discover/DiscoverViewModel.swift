import Foundation
import UIKit

@Observable
final class DiscoverViewModel {
    var sessions = Loadable<[PickupSession]>.idle
    var selectedSport: SportType?
    var searchText = ""
    var joiningSessionId: UUID?
    var joinErrorMessage: String?

    private let repository: SessionRepositoryProtocol
    private var loadTask: Task<Void, Never>?

    init(repository: SessionRepositoryProtocol = SessionRepository()) {
        self.repository = repository
    }

    var filteredSessions: [PickupSession] {
        guard let items = sessions.value else { return [] }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return items }
        return items.filter { session in
            session.locationName.lowercased().contains(query)
                || session.sportDisplayName.lowercased().contains(query)
                || (session.notesForDisplay?.lowercased().contains(query) ?? false)
                || (session.host?.displayName.lowercased().contains(query) ?? false)
        }
    }

    /// Drops sessions whose start time is in the past (updates every minute via `TimelineView` in Discover).
    func discoverList(at referenceDate: Date) -> [PickupSession] {
        filteredSessions.filter { $0.startsAt > referenceDate }
    }

    func load() {
        loadTask?.cancel()
        loadTask = Task { await fetchSessions() }
    }

    @MainActor
    func fetchSessions() async {
        let previous = sessions
        sessions = .loading
        do {
            let items = try await repository.fetchUpcoming(sport: selectedSport)
            if Task.isCancelled {
                sessions = previous
                return
            }
            sessions = .loaded(items)
        } catch {
            if Task.isCancelled {
                sessions = previous
                return
            }
            sessions = .failed(AppErrorMapper.message(for: error))
        }
    }

    @MainActor
    func quickJoin(session: PickupSession) async {
        joinErrorMessage = nil
        joiningSessionId = session.id
        defer { joiningSessionId = nil }

        do {
            _ = try await repository.joinSession(id: session.id)
            await fetchSessions()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } catch {
            joinErrorMessage = AppErrorMapper.message(for: error)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}
