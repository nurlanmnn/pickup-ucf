import Foundation
import UIKit

struct DiscoverEmptyStateContent: Equatable {
    let title: String
    let message: String
}

struct QuickCreatePreset: Equatable, Identifiable {
    let sport: SportType
    let venueId: UUID?

    var id: String { sport.rawValue }
}

private struct DiscoverFilterSnapshot {
    let sportMode: DiscoverSportFilterMode
    let timeWindow: DiscoverTimeWindow
    let skillLevel: SkillLevel
    let venueId: UUID?
}

private enum VenueLoadState {
    case notStarted
    case loading(id: Int, task: Task<[Venue], Error>)
    case finished
}

@Observable
final class DiscoverViewModel {
    var sessions = Loadable<[PickupSession]>.idle
    var filterMode: DiscoverSportFilterMode
    var selectedTimeWindow: DiscoverTimeWindow = .next48h
    var selectedSkillLevel: SkillLevel = .any
    var selectedVenueId: UUID?
    var searchText = ""
    var joiningSessionId: UUID?
    var leavingSessionId: UUID?
    var joinErrorMessage: String?
    private(set) var preferredSports: [SportType] = []
    private(set) var venues: [Venue] = []
    /// Active join/waitlist status for the signed-in user per session id.
    private(set) var participantStatusBySessionId: [UUID: ParticipantStatus] = [:]

    private let repository: SessionRepositoryProtocol
    private let blockRepository: BlockRepositoryProtocol
    private let profileRepository: ProfileRepositoryProtocol
    private var loadTask: Task<Void, Never>?
    private var hasLoadedPreferredSports = false
    private var preferredSportsLoadTask: Task<Profile?, Never>?
    private var venueLoadState = VenueLoadState.notStarted
    private var venueLoadGeneration = 0
    private var requestGeneration = 0
    private var lastSettledSessions = Loadable<[PickupSession]>.idle
    private var lastSettledStatuses: [UUID: ParticipantStatus] = [:]

    init(
        repository: SessionRepositoryProtocol = SessionRepository(),
        blockRepository: BlockRepositoryProtocol = BlockRepository(),
        profileRepository: ProfileRepositoryProtocol = ProfileRepository()
    ) {
        self.repository = repository
        self.blockRepository = blockRepository
        self.profileRepository = profileRepository
        self.filterMode = DiscoverSportFilterStorage.load() ?? .single(nil)
    }

    var showMySportsChip: Bool {
        !preferredSports.isEmpty
    }

    var officialVenues: [Venue] {
        venues.filter(\.isOfficial)
    }

    var filteredSessions: [PickupSession] {
        guard let items = sessions.value else { return [] }
        let venueFiltered = Self.applyVenueFilter(items, selectedVenueId: selectedVenueId)
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return venueFiltered }
        return venueFiltered.filter { session in
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

    /// True when the feed likely truncated at the server cap and the user can still see games.
    static func shouldShowSessionListCapHint(
        loadedCount: Int,
        visibleCount: Int,
        searchText: String
    ) -> Bool {
        let hasSearch = !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return visibleCount > 0
            && !hasSearch
            && loadedCount >= AppPagination.discoverSessions
    }

    static var sessionListCapHint: String {
        "Showing the next \(AppPagination.discoverSessions). Narrow sport, venue, or time to see more."
    }

    func hostNudgeCTATitle() -> String {
        Self.hostNudgeCTATitle(filterMode: filterMode)
    }

    func hostNudgePrefill() -> CreateSessionPrefill {
        Self.hostNudgePrefill(
            filterMode: filterMode,
            preferredSports: preferredSports,
            selectedVenueId: selectedVenueId,
            officialVenues: officialVenues
        )
    }

    func emptyStateSymbol() -> String {
        Self.emptyStateSymbol(filterMode: filterMode)
    }

    func quickCreatePresets() -> [QuickCreatePreset] {
        Self.quickCreatePresets(
            filterMode: filterMode,
            preferredSports: preferredSports,
            selectedVenueId: selectedVenueId,
            officialVenues: officialVenues
        )
    }

    static func hostNudgeCTATitle(filterMode: DiscoverSportFilterMode) -> String {
        if case .single(let sport?) = filterMode {
            return "Host \(sport.displayName.lowercased()) game"
        }
        return "Host a game"
    }

    static func hostNudgePrefill(
        filterMode: DiscoverSportFilterMode,
        preferredSports: [SportType],
        selectedVenueId: UUID? = nil,
        officialVenues: [Venue] = [],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> CreateSessionPrefill {
        let venueId = selectedVenueId ?? officialVenues.first?.id
        let sport: SportType
        if case .single(let selected?) = filterMode {
            sport = selected
        } else if case .mySports = filterMode, let firstPreferred = preferredSports.first {
            sport = firstPreferred
        } else {
            sport = .basketball
        }
        return CreateSessionPrefill(sport: sport, venueId: venueId, now: now, calendar: calendar)
    }

    static func emptyStateSymbol(filterMode: DiscoverSportFilterMode) -> String {
        if case .single(let sport?) = filterMode {
            return sport.systemImage
        }
        return "sportscourt"
    }

    static let defaultQuickCreateSports: [SportType] = [
        .basketball, .soccer, .volleyball, .flagFootball,
    ]

    static func quickCreatePresets(
        filterMode: DiscoverSportFilterMode,
        preferredSports: [SportType],
        selectedVenueId: UUID?,
        officialVenues: [Venue]
    ) -> [QuickCreatePreset] {
        if case .single(.some(_)) = filterMode {
            return []
        }

        let sports: [SportType]
        if case .mySports = filterMode {
            let preferred = preferredSports.filter { $0 != .other }
            sports = preferred.isEmpty
                ? defaultQuickCreateSports
                : Array(preferred.prefix(4))
        } else {
            sports = defaultQuickCreateSports
        }

        let venueId = selectedVenueId ?? officialVenues.first?.id
        return sports.map { QuickCreatePreset(sport: $0, venueId: venueId) }
    }

    func emptyStateContent(serverItemsAreEmpty: Bool) -> DiscoverEmptyStateContent {
        let hasSearch = !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasActiveFilter = selectedVenueId != nil
            || filterMode != .single(nil)
            || selectedSkillLevel != .any
            || selectedTimeWindow != .next48h
            || hasSearch

        if serverItemsAreEmpty, !hasActiveFilter {
            return DiscoverEmptyStateContent(
                title: "No games yet",
                message: "Be the first to host a pickup session on campus."
            )
        }

        return DiscoverEmptyStateContent(
            title: "No upcoming games",
            message: hasActiveFilter
                ? "Try another venue, sport, or search term."
                : "Check back soon for new sessions."
        )
    }

    @MainActor
    func load(currentUserId: UUID?) {
        startSessionRequest(currentUserId: currentUserId)
    }

    @MainActor
    func setFilterMode(_ mode: DiscoverSportFilterMode, currentUserId: UUID?) {
        filterMode = mode
        DiscoverSportFilterStorage.save(mode)
        UISelectionFeedbackGenerator().selectionChanged()
        load(currentUserId: currentUserId)
    }

    @MainActor
    func setVenueFilter(_ venueId: UUID?, currentUserId: UUID?) {
        selectedVenueId = venueId
        UISelectionFeedbackGenerator().selectionChanged()
        load(currentUserId: currentUserId)
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

    static func applySportFilter(
        _ sessions: [PickupSession],
        mode: DiscoverSportFilterMode,
        preferredSports: [SportType]
    ) -> [PickupSession] {
        guard case .mySports = mode else { return sessions }
        let preferred = Set(preferredSports)
        return sessions.filter { preferred.contains($0.sport) }
    }

    static func applyVenueFilter(
        _ sessions: [PickupSession],
        selectedVenueId: UUID?
    ) -> [PickupSession] {
        guard let selectedVenueId else { return sessions }
        return sessions.filter { $0.venueId == selectedVenueId }
    }

    @MainActor
    func fetchSessions(currentUserId: UUID?) async {
        let task = startSessionRequest(currentUserId: currentUserId)
        await task.value
    }

    @MainActor
    @discardableResult
    private func startSessionRequest(currentUserId: UUID?) -> Task<Void, Never> {
        loadTask?.cancel()
        requestGeneration += 1
        let generation = requestGeneration
        sessions = .loading

        let task = Task { [weak self] in
            guard let self else { return }
            await self.performSessionRequest(
                currentUserId: currentUserId,
                generation: generation
            )
        }
        loadTask = task
        return task
    }

    @MainActor
    private func performSessionRequest(
        currentUserId: UUID?,
        generation: Int
    ) async {
        do {
            await ensureVenues()
            await ensurePreferredSports(currentUserId: currentUserId)

            guard generation == requestGeneration else { return }

            let filters = DiscoverFilterSnapshot(
                sportMode: filterMode,
                timeWindow: selectedTimeWindow,
                skillLevel: selectedSkillLevel,
                venueId: selectedVenueId
            )
            let skillFilter = filters.skillLevel == .any ? nil : filters.skillLevel
            let sportFilter: SportType? = {
                if case .single(let sport) = filters.sportMode { return sport }
                return nil
            }()

            var items = try await repository.fetchUpcoming(
                sport: sportFilter,
                timeWindow: filters.timeWindow,
                skillLevel: skillFilter,
                venueId: filters.venueId
            )
            items = Self.applySportFilter(items, mode: filters.sportMode, preferredSports: preferredSports)
            items = Self.applyVenueFilter(items, selectedVenueId: filters.venueId)

            if currentUserId != nil {
                let blockedHostIds = try await blockRepository.fetchBlockedUserIds()
                items = SessionRepository.filterBlockedHosts(items, blockedHostIds: blockedHostIds)
            }
            guard generation == requestGeneration else { return }
            if Task.isCancelled {
                sessions = lastSettledSessions
                participantStatusBySessionId = lastSettledStatuses
                return
            }

            var statuses: [UUID: ParticipantStatus] = [:]
            if let userId = currentUserId, !items.isEmpty {
                statuses = try await repository.fetchParticipantStatuses(
                    userId: userId,
                    sessionIds: items.map(\.id)
                )
            }

            guard generation == requestGeneration else { return }
            if Task.isCancelled {
                sessions = lastSettledSessions
                participantStatusBySessionId = lastSettledStatuses
                return
            }

            participantStatusBySessionId = statuses
            sessions = .loaded(items)
            lastSettledStatuses = statuses
            lastSettledSessions = sessions
        } catch {
            guard generation == requestGeneration else { return }
            if Task.isCancelled {
                sessions = lastSettledSessions
                participantStatusBySessionId = lastSettledStatuses
                return
            }
            participantStatusBySessionId = [:]
            sessions = .failed(AppErrorMapper.message(for: error))
            lastSettledStatuses = [:]
            lastSettledSessions = sessions
        }
    }

    @MainActor
    private func ensureVenues() async {
        while true {
            let loadId: Int
            let task: Task<[Venue], Error>

            switch venueLoadState {
            case .finished:
                return
            case .loading(let existingId, let existingTask):
                loadId = existingId
                task = existingTask
            case .notStarted:
                venueLoadGeneration += 1
                loadId = venueLoadGeneration
                task = Task { try await repository.fetchVenues() }
                venueLoadState = .loading(id: loadId, task: task)
            }

            do {
                let fetchedVenues = try await task.value
                guard isCurrentVenueLoad(loadId) else { continue }
                venues = fetchedVenues
                venueLoadState = .finished
                return
            } catch is CancellationError {
                if isCurrentVenueLoad(loadId) {
                    venueLoadState = .notStarted
                }
                if Task.isCancelled { return }
            } catch {
                guard isCurrentVenueLoad(loadId) else { continue }
                venueLoadState = .finished
                return
            }
        }
    }

    @MainActor
    private func isCurrentVenueLoad(_ id: Int) -> Bool {
        guard case .loading(let currentId, _) = venueLoadState else { return false }
        return currentId == id
    }

    @MainActor
    private func ensurePreferredSports(currentUserId: UUID?) async {
        guard !hasLoadedPreferredSports, currentUserId != nil else { return }

        let task: Task<Profile?, Never>
        if let preferredSportsLoadTask {
            task = preferredSportsLoadTask
        } else {
            task = Task { try? await profileRepository.fetchCurrentProfile() }
            preferredSportsLoadTask = task
        }

        let profile = await task.value
        guard !hasLoadedPreferredSports else { return }
        hasLoadedPreferredSports = true
        preferredSportsLoadTask = nil

        if let profile {
            preferredSports = profile.preferredSports
            if DiscoverSportFilterStorage.load() == nil {
                filterMode = preferredSports.isEmpty ? .single(nil) : .mySports
                DiscoverSportFilterStorage.save(filterMode)
            }
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
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } catch {
            joinErrorMessage = AppErrorMapper.message(for: error)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}
