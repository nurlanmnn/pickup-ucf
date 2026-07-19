import XCTest
@testable import PickUpUCF

final class VenueFilterTests: XCTestCase {
    @MainActor
    func testInitialLoadSnapshotsMySportsAfterPreferredSportsInitialization() async {
        let storageKey = "discoverSportFilterMode"
        let previousFilter = DiscoverSportFilterStorage.load()
        UserDefaults.standard.removeObject(forKey: storageKey)
        defer {
            if let previousFilter {
                DiscoverSportFilterStorage.save(previousFilter)
            } else {
                UserDefaults.standard.removeObject(forKey: storageKey)
            }
        }

        let repository = VenueSessionRepositorySpy()
        repository.fetchUpcomingHandler = { _ in
            [
                self.makeSession(venueId: UUID(), sport: .basketball),
                self.makeSession(venueId: UUID(), sport: .soccer),
            ]
        }
        let profileRepository = PreferredSportsProfileRepositoryStub(
            preferredSports: [.basketball]
        )
        let viewModel = DiscoverViewModel(
            repository: repository,
            blockRepository: EmptyBlockRepositoryStub(),
            profileRepository: profileRepository
        )

        await viewModel.fetchSessions(currentUserId: UUID())

        XCTAssertEqual(viewModel.filterMode, .mySports)
        XCTAssertEqual(viewModel.sessions.value?.map(\.sport), [.basketball])
    }

    func testActiveVenueUsesFilteredEmptyStateWhenServerReturnsNoRows() {
        let viewModel = DiscoverViewModel()
        viewModel.selectedVenueId = UUID()

        let emptyState = viewModel.emptyStateContent(serverItemsAreEmpty: true)

        XCTAssertEqual(emptyState.title, "No upcoming games")
        XCTAssertEqual(emptyState.message, "Try another venue, sport, or search term.")
    }

    @MainActor
    func testStalePullToRefreshCannotOverwriteLatestVenueSelection() async {
        let repository = VenueSessionRepositorySpy()
        let responses = ControlledVenueResponses()
        repository.fetchUpcomingHandler = { venueId in
            await responses.response(for: venueId)
        }
        let viewModel = DiscoverViewModel(repository: repository)
        let initialVenueId = UUID()
        let selectedVenueId = UUID()
        let staleSession = makeSession(venueId: initialVenueId)
        let selectedSession = makeSession(venueId: selectedVenueId)
        viewModel.selectedVenueId = initialVenueId

        let refreshStarted = expectation(description: "Pull to refresh started")
        repository.onFetchUpcoming = { venueId in
            if venueId == initialVenueId { refreshStarted.fulfill() }
        }
        let refreshTask = Task {
            await viewModel.fetchSessions(currentUserId: nil)
        }
        await fulfillment(of: [refreshStarted], timeout: 1)

        let selectionStarted = expectation(description: "Venue selection started")
        repository.onFetchUpcoming = { venueId in
            if venueId == selectedVenueId { selectionStarted.fulfill() }
        }
        viewModel.setVenueFilter(selectedVenueId, currentUserId: nil)
        await fulfillment(of: [selectionStarted], timeout: 1)

        await responses.complete(venueId: selectedVenueId, sessions: [selectedSession])
        await waitUntil {
            viewModel.sessions.value?.first?.id == selectedSession.id
        }

        await responses.complete(venueId: initialVenueId, sessions: [staleSession])
        await refreshTask.value

        XCTAssertEqual(viewModel.selectedVenueId, selectedVenueId)
        XCTAssertEqual(viewModel.sessions.value?.map(\.id), [selectedSession.id])
    }

    @MainActor
    func testVenueLoadingRetriesAfterCancelledInitialAttempt() async {
        let repository = VenueSessionRepositorySpy()
        let firstVenueLoad = ControlledVenueLoad()
        let officialVenue = Venue(
            id: UUID(),
            name: "IM Fields",
            lat: 28.6,
            lng: -81.2,
            campusZone: nil,
            isOfficial: true
        )
        repository.fetchVenuesHandler = { attempt in
            if attempt == 1 {
                return try await firstVenueLoad.response()
            }
            return [officialVenue]
        }
        let viewModel = DiscoverViewModel(repository: repository)

        let firstLoadStarted = expectation(description: "Initial venue load started")
        repository.onFetchVenues = { attempt in
            if attempt == 1 { firstLoadStarted.fulfill() }
        }
        viewModel.setVenueFilter(UUID(), currentUserId: nil)
        await fulfillment(of: [firstLoadStarted], timeout: 1)

        viewModel.setVenueFilter(UUID(), currentUserId: nil)
        await firstVenueLoad.cancel()

        await waitUntil {
            repository.fetchVenuesCallCount == 2
                && viewModel.officialVenues == [officialVenue]
        }

        XCTAssertEqual(repository.fetchVenuesCallCount, 2)
        XCTAssertEqual(viewModel.officialVenues, [officialVenue])
    }

    @MainActor
    func testVenueSetterRefreshesForSelectionAndAllVenuesWithoutReloadingVenues() async {
        let repository = VenueSessionRepositorySpy()
        let viewModel = DiscoverViewModel(repository: repository)
        let venueId = UUID()

        let selectionRefresh = expectation(description: "Selected venue refresh")
        repository.onFetchUpcoming = { receivedVenueId in
            XCTAssertEqual(receivedVenueId, venueId)
            selectionRefresh.fulfill()
        }
        viewModel.setVenueFilter(venueId, currentUserId: nil)
        await fulfillment(of: [selectionRefresh], timeout: 1)

        let allVenuesRefresh = expectation(description: "All venues refresh")
        repository.onFetchUpcoming = { receivedVenueId in
            XCTAssertNil(receivedVenueId)
            allVenuesRefresh.fulfill()
        }
        viewModel.setVenueFilter(nil, currentUserId: nil)
        await fulfillment(of: [allVenuesRefresh], timeout: 1)

        XCTAssertEqual(repository.fetchVenuesCallCount, 1)
    }

    func testVenueFilterKeepsOnlySessionsAtSelectedVenue() {
        let imFieldsId = UUID()
        let sessions = [
            makeSession(venueId: imFieldsId),
            makeSession(venueId: UUID()),
            makeSession(venueId: nil),
        ]

        let filtered = DiscoverViewModel.applyVenueFilter(
            sessions,
            selectedVenueId: imFieldsId
        )

        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.venueId, imFieldsId)
    }

    private func makeSession(
        venueId: UUID?,
        sport: SportType = .soccer
    ) -> PickupSession {
        PickupSession(
            id: UUID(),
            hostId: UUID(),
            sport: sport,
            customSportName: nil,
            venueId: venueId,
            customLocation: venueId == nil ? "Memory Mall" : nil,
            customLat: venueId == nil ? 28.6 : nil,
            customLng: venueId == nil ? -81.2 : nil,
            startsAt: Date(timeIntervalSince1970: 0),
            endsAt: Date(timeIntervalSince1970: 3600),
            capacity: 10,
            playerCount: 1,
            skillLevel: .any,
            notes: nil,
            status: .open,
            venue: nil,
            host: nil,
            weatherSnapshot: nil
        )
    }

    @MainActor
    private func waitUntil(
        timeoutIterations: Int = 100,
        condition: @escaping @MainActor () -> Bool
    ) async {
        for _ in 0..<timeoutIterations {
            if condition() { return }
            try? await Task.sleep(nanoseconds: 1_000_000)
        }
        XCTFail("Condition was not met before timeout")
    }
}

private final class EmptyBlockRepositoryStub: BlockRepositoryProtocol {
    func block(userId: UUID) async throws {
        throw StubError.unimplemented
    }

    func unblock(userId: UUID) async throws {
        throw StubError.unimplemented
    }

    func fetchBlockedUserIds() async throws -> Set<UUID> {
        []
    }

    func fetchBlockedUsers() async throws -> [BlockedUser] {
        throw StubError.unimplemented
    }

    private enum StubError: Error {
        case unimplemented
    }
}

private final class PreferredSportsProfileRepositoryStub: ProfileRepositoryProtocol {
    private let profile: Profile

    init(preferredSports: [SportType]) {
        profile = Profile(
            id: UUID(),
            displayName: "Knight",
            preferredSports: preferredSports
        )
    }

    func fetchCurrentProfile() async throws -> Profile {
        profile
    }

    func ensureProfileForCurrentUser() async throws {
        throw StubError.unimplemented
    }

    func ensureProfile(userId: UUID, displayName: String) async throws {
        throw StubError.unimplemented
    }

    func fetchProfile(userId: UUID) async throws -> Profile {
        throw StubError.unimplemented
    }

    func completeOnboarding(sports: [SportType]) async throws {
        throw StubError.unimplemented
    }

    func updatePreferredSports(_ sports: [SportType]) async throws {
        throw StubError.unimplemented
    }

    func updateUsername(_ username: String) async throws {
        throw StubError.unimplemented
    }

    func deleteAccount() async throws {
        throw StubError.unimplemented
    }

    private enum StubError: Error {
        case unimplemented
    }
}

private final class VenueSessionRepositorySpy: SessionRepositoryProtocol {
    var onFetchUpcoming: ((UUID?) -> Void)?
    var fetchUpcomingHandler: ((UUID?) async -> [PickupSession])?
    var onFetchVenues: ((Int) -> Void)?
    var fetchVenuesHandler: ((Int) async throws -> [Venue])?
    private(set) var fetchVenuesCallCount = 0

    func fetchUpcoming(
        sport: SportType?,
        timeWindow: DiscoverTimeWindow,
        skillLevel: SkillLevel?,
        venueId: UUID?
    ) async throws -> [PickupSession] {
        onFetchUpcoming?(venueId)
        if let fetchUpcomingHandler {
            return await fetchUpcomingHandler(venueId)
        }
        return []
    }

    func fetchVenues() async throws -> [Venue] {
        fetchVenuesCallCount += 1
        onFetchVenues?(fetchVenuesCallCount)
        if let fetchVenuesHandler {
            return try await fetchVenuesHandler(fetchVenuesCallCount)
        }
        return []
    }

    func fetchMySessions(userId: UUID) async throws -> [PickupSession] {
        throw StubError.unimplemented
    }

    func fetchMyPastSessions(limit: Int, offset: Int) async throws -> [PickupSession] {
        throw StubError.unimplemented
    }

    func fetchSession(id: UUID) async throws -> PickupSession {
        throw StubError.unimplemented
    }

    func fetchParticipantStatus(sessionId: UUID, userId: UUID) async throws -> ParticipantStatus? {
        throw StubError.unimplemented
    }

    func fetchParticipantStatuses(
        userId: UUID,
        sessionIds: [UUID]
    ) async throws -> [UUID: ParticipantStatus] {
        [:]
    }

    func createSession(_ input: CreateSessionInput) async throws -> PickupSession {
        throw StubError.unimplemented
    }

    func updateSession(id: UUID, input: UpdateSessionInput) async throws -> PickupSession {
        throw StubError.unimplemented
    }

    func cancelSession(id: UUID) async throws {
        throw StubError.unimplemented
    }

    func joinSession(id: UUID) async throws -> ParticipantStatus {
        throw StubError.unimplemented
    }

    func leaveSession(id: UUID) async throws {
        throw StubError.unimplemented
    }

    func fetchRoster(sessionId: UUID) async throws -> SessionRoster {
        throw StubError.unimplemented
    }

    private enum StubError: Error {
        case unimplemented
    }
}

private actor ControlledVenueLoad {
    private var continuation: CheckedContinuation<[Venue], Error>?

    func response() async throws -> [Venue] {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    func cancel() {
        continuation?.resume(throwing: CancellationError())
        continuation = nil
    }
}

private actor ControlledVenueResponses {
    private enum RequestKey: Hashable {
        case allVenues
        case venue(UUID)
    }

    private var continuations: [
        RequestKey: CheckedContinuation<[PickupSession], Never>
    ] = [:]

    func response(for venueId: UUID?) async -> [PickupSession] {
        await withCheckedContinuation { continuation in
            continuations[key(for: venueId)] = continuation
        }
    }

    func complete(venueId: UUID?, sessions: [PickupSession]) {
        continuations.removeValue(forKey: key(for: venueId))?.resume(returning: sessions)
    }

    private func key(for venueId: UUID?) -> RequestKey {
        if let venueId {
            return .venue(venueId)
        }
        return .allVenues
    }
}
