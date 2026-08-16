import Foundation
import UIKit

@Observable
final class MyGamesViewModel {
    var upcomingSessions = Loadable<[PickupSession]>.idle
    var pastSessions = Loadable<[PickupSession]>.idle
    var isPastSectionExpanded = false
    var hasMorePastSessions = false
    var isLoadingMorePast = false

    var leavingSessionId: UUID?
    var actionError: String?

    private let repository: SessionRepositoryProtocol
    private let userId: UUID
    private var upcomingLoadTask: Task<Void, Never>?
    private var pastLoadTask: Task<Void, Never>?
    private var pastLoadedOnce = false
    private var pastOffset = 0

    init(userId: UUID, repository: SessionRepositoryProtocol = SessionRepository()) {
        self.userId = userId
        self.repository = repository
    }

    func loadUpcoming() {
        upcomingLoadTask?.cancel()
        upcomingLoadTask = Task { await fetchUpcoming() }
    }

    func loadPastIfNeeded() {
        guard !pastLoadedOnce else { return }
        pastLoadTask?.cancel()
        pastLoadTask = Task { await fetchPast(reset: true) }
    }

    func loadMorePast() {
        guard hasMorePastSessions, !isLoadingMorePast else { return }
        pastLoadTask?.cancel()
        pastLoadTask = Task { await fetchPast(reset: false) }
    }

    @MainActor
    func fetchUpcoming() async {
        let previous = upcomingSessions
        upcomingSessions = .loading
        do {
            let items = try await repository.fetchMySessions(userId: userId)
            if Task.isCancelled {
                upcomingSessions = previous
                return
            }
            upcomingSessions = .loaded(items)
            GameLiveActivityCoordinator.refresh(upcomingSessions: items)
        } catch {
            if Task.isCancelled {
                upcomingSessions = previous
                return
            }
            upcomingSessions = .failed(AppErrorMapper.message(for: error))
        }
    }

    @MainActor
    func fetchPast(reset: Bool) async {
        if reset {
            pastOffset = 0
            hasMorePastSessions = false
            pastSessions = .loading
        } else {
            isLoadingMorePast = true
        }

        let previousItems = pastSessions.value ?? []

        do {
            let page = try await repository.fetchMyPastSessions(
                limit: AppPagination.myGamesPastPage,
                offset: pastOffset
            )
            if Task.isCancelled { return }

            let merged = reset ? page : previousItems + page
            pastOffset = merged.count
            hasMorePastSessions = page.count == AppPagination.myGamesPastPage
            pastSessions = .loaded(merged)
            pastLoadedOnce = true
        } catch {
            if Task.isCancelled { return }
            if reset {
                pastSessions = .failed(AppErrorMapper.message(for: error))
            } else {
                actionError = AppErrorMapper.message(for: error)
            }
        }

        isLoadingMorePast = false
    }

    @MainActor
    func leave(session: PickupSession) async {
        actionError = nil
        leavingSessionId = session.id
        defer { leavingSessionId = nil }

        do {
            try await repository.leaveSession(id: session.id)
            GameLiveActivityCoordinator.end(forSessionId: session.id)
            await fetchUpcoming()
            if pastLoadedOnce {
                await fetchPast(reset: true)
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } catch {
            actionError = AppErrorMapper.message(for: error)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}
