import XCTest
import SwiftUI
@testable import PickUpUCF

@MainActor
final class UXFlowTests: XCTestCase {
    func testAccountSwitchesReplaceTheScreenInsteadOfStackingForms() async throws {
        let previous = UserDefaults.standard.object(forKey: "welcomeIntroCompleted")
        UserDefaults.standard.set(true, forKey: "welcomeIntroCompleted")
        defer { UserDefaults.standard.set(previous, forKey: "welcomeIntroCompleted") }
        let host = UIHostingController(rootView: WelcomeView().environment(AppState()))
        let window = try makeWindow(host)
        defer { window.isHidden = true; window.rootViewController = nil }
        try await settle(host)
        try activate("welcome-sign-up", in: host)
        try await settle(host)
        for _ in 0..<3 {
            try activate("sign-up-switch-to-sign-in", in: host)
            try await settle(host)
            XCTAssertNotNil(element(in: host.view, id: "sign-in-switch-to-sign-up"))
            try activate("sign-in-switch-to-sign-up", in: host)
            try await settle(host)
        }
        let navigation = try XCTUnwrap(navigationControllers(in: host).first)
        XCTAssertEqual(navigation.viewControllers.count, 2, "Only welcome and the current account screen belong in the stack")
        navigation.popViewController(animated: false)
        try await settle(host)
        XCTAssertNotNil(element(in: host.view, id: "welcome-sign-up"), "One Back returns to welcome")
    }

    func testAccountSwitchActionsCarryTheEmail() async throws {
        let email = "synthetic@knights.ucf.edu"
        var receivedEmail: String?
        let signup = UIHostingController(rootView: NavigationStack {
            SignUpView(email: email) { receivedEmail = $0 }
        })
        let window = try makeWindow(signup)
        defer { window.isHidden = true; window.rootViewController = nil }
        try await settle(signup)
        try activate("sign-up-switch-to-sign-in", in: signup)
        XCTAssertEqual(receivedEmail, email)
        receivedEmail = nil
        let signin = UIHostingController(rootView: NavigationStack {
            SignInView(email: email) { receivedEmail = $0 }.environment(AppState())
        })
        window.rootViewController = signin
        try await settle(signin)
        try activate("sign-in-switch-to-sign-up", in: signin)
        XCTAssertEqual(receivedEmail, email)
    }

    func testCreateVenueFailureStopsLoadingAndCanRecover() async {
        let repository = UXSessionRepository()
        repository.venueError = URLError(.notConnectedToInternet)
        let model = CreateSessionViewModel(repository: repository)
        model.applyPrefill(CreateSessionPrefill(sport: .tennis, venueId: UUID()))
        await model.loadVenues()
        XCTAssertFalse(model.isLoadingVenues)
        XCTAssertNotNil(model.venueLoadError)
        model.selectCustomLocation()
        XCTAssertTrue(model.showsCustomLocationField, "A stale prefill must not block custom-location recovery")
        repository.venueError = nil
        await model.loadVenues()
        XCTAssertNil(model.venueLoadError)
        XCTAssertTrue(model.showsCustomLocationField)
    }

    func testEditVenueFailureKeepsExistingVenueAndCustomLocationIsAvailableWithoutVenues() async {
        let repository = UXSessionRepository()
        repository.venueError = URLError(.notConnectedToInternet)
        let venueId = UUID()
        let session = PickupSession(id: UUID(), hostId: UUID(), sport: .tennis, venueId: venueId,
                                    startsAt: .now.addingTimeInterval(7200), endsAt: .now.addingTimeInterval(10800),
                                    capacity: 4, playerCount: 2, skillLevel: .any, status: .open)
        let model = EditSessionViewModel(session: session, repository: repository)
        await model.loadVenues()
        XCTAssertFalse(model.isLoadingVenues)
        XCTAssertNotNil(model.venueLoadError)
        XCTAssertEqual(model.selectedVenueId, venueId)
        model.venuePickerOptionId = EditSessionViewModel.customVenuePickerTag
        XCTAssertTrue(model.showsCustomLocationField)
    }

    func testVerificationAndResendCannotOverlapOrIgnoreCooldown() async {
        let repository = UXAuthRepository()
        let model = VerifyEmailViewModel(email: "synthetic@ucf.edu", repository: repository)
        model.otpCode = "123456"
        model.isResending = true
        XCTAssertFalse(model.canVerify)
        let overlappingVerification = await model.verify()
        XCTAssertNil(overlappingVerification)
        XCTAssertEqual(repository.verifyCalls, 0)
        model.isResending = false
        model.isVerifying = true
        XCTAssertFalse(model.canResend)
        await model.resend()
        XCTAssertEqual(repository.resendCalls, 0)
        model.isVerifying = false
        await model.resend()
        XCTAssertEqual(repository.resendCalls, 1)
        XCTAssertEqual(model.resendCooldown, 60)
        await model.resend()
        XCTAssertEqual(repository.resendCalls, 1)
    }

    func testResetDiscoveryClearsEveryFilter() async {
        let previous = DiscoverSportFilterStorage.load()
        defer {
            if let previous { DiscoverSportFilterStorage.save(previous) }
            else { UserDefaults.standard.removeObject(forKey: "discoverSportFilterMode") }
        }
        let model = DiscoverViewModel(repository: UXSessionRepository())
        model.searchText = "unmatched query"
        model.filterMode = .single(.tennis)
        model.selectedSkillLevel = .advanced
        model.selectedTimeWindow = .today
        model.selectedVenueId = UUID()
        XCTAssertTrue(model.hasActiveFilters)
        model.resetFilters(currentUserId: nil)
        XCTAssertFalse(model.hasActiveFilters)
        await model.fetchSessions(currentUserId: nil)
        XCTAssertTrue(model.sessions.value?.isEmpty == true)
    }

    func testCreateFormReusesTheRequestIDAfterAmbiguousFailureAndEdits() async {
        let repository = UXSessionRepository()
        let model = CreateSessionViewModel(repository: repository)
        model.venuePickerOptionId = UUID().uuidString
        _ = await model.create()
        _ = await model.create()
        model.notes = "Updated after an uncertain attempt"
        _ = await model.create()
        XCTAssertEqual(repository.createRequests.count, 3)
        XCTAssertEqual(Set(repository.createRequests.map(\.requestId)).count, 1,
                       "The server must reconcile an earlier attempt before accepting changed input")
    }

    func testCardOpenAndParticipationAreIndependentAccessibleActions() async throws {
        let session = PickupSession(id: UUID(), hostId: UUID(), sport: .basketball,
                                    customLocation: "Synthetic court", startsAt: .now.addingTimeInterval(7200),
                                    endsAt: .now.addingTimeInterval(10800), capacity: 10, playerCount: 4,
                                    skillLevel: .any, status: .open)
        var opens = 0
        var joins = 0
        let host = UIHostingController(rootView: ScrollView {
            SessionCard(session: session, onJoin: { joins += 1 }, onOpen: { opens += 1 }).padding()
        })
        let window = try makeWindow(host)
        defer { window.isHidden = true; window.rootViewController = nil }
        try await settle(host)
        try activate("session-action-\(session.id.uuidString)", in: host)
        XCTAssertEqual(joins, 1)
        XCTAssertEqual(opens, 0)
        try activate("session-open-\(session.id.uuidString)", in: host)
        XCTAssertEqual(opens, 1)
        XCTAssertEqual(joins, 1)
        for id in ["session-action-", "session-open-"] {
            let control = try XCTUnwrap(element(in: host.view, id: id + session.id.uuidString))
            XCTAssertGreaterThanOrEqual(control.accessibilityFrame.height, 44)
        }
        let image = UIGraphicsImageRenderer(bounds: host.view.bounds).image { _ in
            host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = "Separate game actions"
        attachment.lifetime = .keepAlways
        add(attachment)
        host.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
        try await settle(host)
        let largeImage = UIGraphicsImageRenderer(bounds: host.view.bounds).image { _ in
            host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
        }
        let largeAttachment = XCTAttachment(image: largeImage)
        largeAttachment.name = "Separate game actions at Accessibility XXXL"
        largeAttachment.lifetime = .keepAlways
        add(largeAttachment)
    }

    private func makeWindow(_ host: UIViewController) throws -> UIWindow {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = scene.coordinateSpace.bounds
        window.rootViewController = host
        window.makeKeyAndVisible()
        return window
    }

    private func settle(_ host: UIViewController) async throws {
        host.view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(400))
        host.view.layoutIfNeeded()
    }

    private func activate(_ id: String, in host: UIViewController) throws {
        let control = try XCTUnwrap(element(in: host.view, id: id), "Missing action: \(id)")
        XCTAssertTrue(control.accessibilityActivate(), "Action must be accessible: \(id)")
    }

    private func element(in object: NSObject, id: String) -> NSObject? {
        if object.responds(to: NSSelectorFromString("accessibilityIdentifier")),
           object.value(forKey: "accessibilityIdentifier") as? String == id { return object }
        let count = object.accessibilityElementCount()
        if count > 0, count < 1000 {
            for index in 0..<count {
                if let child = object.accessibilityElement(at: index) as? NSObject, child !== object,
                   let match = element(in: child, id: id) { return match }
            }
        }
        if let view = object as? UIView {
            for child in view.subviews { if let match = element(in: child, id: id) { return match } }
        }
        return nil
    }

    private func navigationControllers(in controller: UIViewController) -> [UINavigationController] {
        ((controller as? UINavigationController).map { [$0] } ?? []) + controller.children.flatMap { navigationControllers(in: $0) }
    }
}

private final class UXSessionRepository: SessionRepositoryProtocol {
    var venueError: Error?
    var createRequests: [CreateSessionInput] = []
    func fetchUpcoming(sport: SportType?, timeWindow: DiscoverTimeWindow, skillLevel: SkillLevel?, venueId: UUID?) async throws -> [PickupSession] { [] }
    func fetchMySessions(userId: UUID) async throws -> [PickupSession] { [] }
    func fetchMyPastSessions(limit: Int, offset: Int) async throws -> [PickupSession] { [] }
    func fetchSession(id: UUID) async throws -> PickupSession { throw URLError(.badServerResponse) }
    func fetchVenues() async throws -> [Venue] { if let venueError { throw venueError }; return [] }
    func fetchParticipantStatus(sessionId: UUID, userId: UUID) async throws -> ParticipantStatus? { nil }
    func fetchParticipantStatuses(userId: UUID, sessionIds: [UUID]) async throws -> [UUID: ParticipantStatus] { [:] }
    func createSession(_ input: CreateSessionInput) async throws -> PickupSession { createRequests.append(input); throw URLError(.networkConnectionLost) }
    func updateSession(id: UUID, input: UpdateSessionInput) async throws -> PickupSession { throw URLError(.badServerResponse) }
    func cancelSession(id: UUID) async throws {}
    func joinSession(id: UUID) async throws -> ParticipantStatus { .joined }
    func leaveSession(id: UUID) async throws {}
    func fetchRoster(sessionId: UUID) async throws -> SessionRoster { SessionRoster(joined: [], waitlistCount: 0, viewerWaitlistPosition: nil) }
}

private final class UXAuthRepository: AuthRepositoryProtocol {
    var verifyCalls = 0
    var resendCalls = 0
    func signUp(email: String, password: String, displayName: String) async throws {}
    func signIn(email: String, password: String) async throws -> AppSession { throw URLError(.badServerResponse) }
    func signOut() async throws {}
    func resendVerificationEmail(email: String) async throws {}
    func resendVerificationOTP(email: String) async throws { resendCalls += 1 }
    func verifyEmailOTP(email: String, token: String) async throws -> AppSession {
        verifyCalls += 1
        return AppSession(userId: UUID(), email: email, isEmailConfirmed: true)
    }
    func requestPasswordReset(email: String) async throws {}
    func updatePassword(_ newPassword: String) async throws {}
    func changePassword(email: String, currentPassword: String, newPassword: String) async throws {}
    func handleAuthDeepLink(url: URL) async throws {}
    func currentSession() async -> AppSession? { nil }
}
