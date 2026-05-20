import Foundation
import UIKit

@Observable
final class MyGamesViewModel {
    var sessions = Loadable<[PickupSession]>.idle
    var leavingSessionId: UUID?
    var actionError: String?

    private let repository: SessionRepositoryProtocol
    private let userId: UUID
    private var loadTask: Task<Void, Never>?

    init(userId: UUID, repository: SessionRepositoryProtocol = SessionRepository()) {
        self.userId = userId
        self.repository = repository
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
            let items = try await repository.fetchMySessions(userId: userId)
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
    func leave(session: PickupSession) async {
        actionError = nil
        leavingSessionId = session.id
        defer { leavingSessionId = nil }

        do {
            try await repository.leaveSession(id: session.id)
            await fetchSessions()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } catch {
            actionError = AppErrorMapper.message(for: error)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}
