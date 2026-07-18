import Foundation
import UIKit

@Observable
final class DiscoverViewModel {
    var sessions = Loadable<[PickupSession]>.idle
    var selectedSport: SportType?
    var selectedTimeWindow: DiscoverTimeWindow = .next48h
    var selectedSkillLevel: SkillLevel = .any
    var searchText = ""
    var joiningSessionId: UUID?
    var leavingSessionId: UUID?
    var joinErrorMessage: String?
    /// Active join/waitlist status for the signed-in user per session id.
    private(set) var participantStatusBySessionId: [UUID: ParticipantStatus] = [:]

    private let repository: SessionRepositoryProtocol
    private let blockRepository: BlockRepositoryProtocol
    private var loadTask: Task<Void, Never>?

    init(
        repository: SessionRepositoryProtocol = SessionRepository(),
        blockRepository: BlockRepositoryProtocol = BlockRepository()
    ) {
        self.repository = repository
        self.blockRepository = blockRepository
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

    func load(currentUserId: UUID?) {
        loadTask?.cancel()
        loadTask = Task { await fetchSessions(currentUserId: currentUserId) }
    }

    func participantStatus(for sessionId: UUID) -> ParticipantStatus? {
        participantStatusBySessionId[sessionId]
    }

    func isParticipating(in sessionId: UUID) -> Bool {
        switch participantStatus(for: sessionId) {
        case .joined, .waitlist:
            return true
        case .left, .none:
            return false
        }
    }

    func cardActionTitle(for session: PickupSession) -> String? {
        switch participantStatus(for: session.id) {
        case .joined:
            return "Leave"
        case .waitlist:
            return "Leave waitlist"
        case .left, .none:
            return nil
        }
    }

    func isDestructiveCardAction(for session: PickupSession) -> Bool {
        isParticipating(in: session.id)
    }

    @MainActor
    func fetchSessions(currentUserId: UUID?) async {
        let previous = sessions
        let previousStatuses = participantStatusBySessionId
        sessions = .loading
        do {
            let skillFilter = selectedSkillLevel == .any ? nil : selectedSkillLevel
            var items = try await repository.fetchUpcoming(
                sport: selectedSport,
                timeWindow: selectedTimeWindow,
                skillLevel: skillFilter
            )
            if currentUserId != nil {
                let blockedHostIds = try await blockRepository.fetchBlockedUserIds()
                items = SessionRepository.filterBlockedHosts(items, blockedHostIds: blockedHostIds)
            }
            if Task.isCancelled {
                sessions = previous
                participantStatusBySessionId = previousStatuses
                return
            }

            var statuses: [UUID: ParticipantStatus] = [:]
            if let userId = currentUserId, !items.isEmpty {
                statuses = try await repository.fetchParticipantStatuses(
                    userId: userId,
                    sessionIds: items.map(\.id)
                )
            }

            if Task.isCancelled {
                sessions = previous
                participantStatusBySessionId = previousStatuses
                return
            }

            participantStatusBySessionId = statuses
            sessions = .loaded(items)
        } catch {
            if Task.isCancelled {
                sessions = previous
                participantStatusBySessionId = previousStatuses
                return
            }
            participantStatusBySessionId = [:]
            sessions = .failed(AppErrorMapper.message(for: error))
        }
    }

    @MainActor
    func quickJoin(session: PickupSession, currentUserId: UUID?) async {
        joinErrorMessage = nil
        joiningSessionId = session.id
        defer { joiningSessionId = nil }

        do {
            let status = try await repository.joinSession(id: session.id)
            participantStatusBySessionId[session.id] = status
            await fetchSessions(currentUserId: currentUserId)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } catch {
            joinErrorMessage = AppErrorMapper.message(for: error)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    @MainActor
    func quickLeave(session: PickupSession, currentUserId: UUID?) async {
        joinErrorMessage = nil
        leavingSessionId = session.id
        defer { leavingSessionId = nil }

        do {
            try await repository.leaveSession(id: session.id)
            participantStatusBySessionId.removeValue(forKey: session.id)
            await fetchSessions(currentUserId: currentUserId)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } catch {
            joinErrorMessage = AppErrorMapper.message(for: error)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}
