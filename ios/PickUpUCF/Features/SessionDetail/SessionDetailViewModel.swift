import Foundation
import Supabase
import UIKit

@Observable
final class SessionDetailViewModel {
    let sessionId: UUID
    var session = Loadable<PickupSession>.idle
    var participantStatus: ParticipantStatus?
    var isSubmitting = false
    var actionError: String?

    private let repository: SessionRepositoryProtocol
    private let attendanceRepository: AttendanceRepository
    private let client: SupabaseClient
    private let userId: UUID?

    var attendanceParticipants = Loadable<[SessionParticipant]>.idle

    private var realtimeChannel: RealtimeChannelV2?
    private var realtimeTask: Task<Void, Never>?

    init(
        sessionId: UUID,
        userId: UUID?,
        repository: SessionRepositoryProtocol = SessionRepository(),
        attendanceRepository: AttendanceRepository = AttendanceRepository(),
        client: SupabaseClient = SupabaseManager.shared
    ) {
        self.sessionId = sessionId
        self.userId = userId
        self.repository = repository
        self.attendanceRepository = attendanceRepository
        self.client = client
    }

    var isHost: Bool {
        guard let uid = userId, let s = session.value else { return false }
        return s.hostId == uid
    }

    /// Host can change details before the scheduled start.
    var canHostEditSession: Bool {
        guard isHost, let s = session.value else { return false }
        return s.startsAt > Date() && (s.status == .open || s.status == .full)
    }

    /// Host can cancel while the session window is still active.
    var canHostCancelSession: Bool {
        guard isHost, let s = session.value else { return false }
        return (s.status == .open || s.status == .full) && s.endsAt > Date()
    }

    /// Host can mark attendance from session start through 24h after it ends.
    var canSubmitAttendance: Bool {
        guard isHost, let s = session.value else { return false }
        let now = Date()
        return s.status != .cancelled
            && s.startsAt <= now
            && now <= s.endsAt.addingTimeInterval(86400)
    }

    @MainActor
    func load() async {
        session = .loading
        do {
            let item = try await repository.fetchSession(id: sessionId)
            session = .loaded(item)
            if let userId {
                participantStatus = try await repository.fetchParticipantStatus(
                    sessionId: sessionId,
                    userId: userId
                )
            }
        } catch {
            session = .failed(AppErrorMapper.message(for: error))
        }
    }

    @MainActor
    func joinOrLeave() async {
        guard !isHost else { return }
        guard let current = session.value else { return }
        actionError = nil
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            if participantStatus == .joined || participantStatus == .waitlist {
                try await repository.leaveSession(id: current.id)
                participantStatus = .left
            } else {
                participantStatus = try await repository.joinSession(id: current.id)
            }
            await load()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } catch {
            actionError = AppErrorMapper.message(for: error)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    @MainActor
    func loadAttendanceParticipants() async {
        attendanceParticipants = .loading
        do {
            let participants = try await attendanceRepository.fetchJoinedParticipants(
                sessionId: sessionId
            )
            attendanceParticipants = .loaded(participants)
        } catch {
            attendanceParticipants = .failed(AppErrorMapper.message(for: error))
        }
    }

    @MainActor
    func submitAttendance(attendedUserIds: [UUID]) async -> Bool {
        actionError = nil
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await attendanceRepository.submitAttendance(
                sessionId: sessionId,
                attendedUserIds: attendedUserIds
            )
            await load()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            return true
        } catch {
            actionError = AppErrorMapper.message(for: error)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return false
        }
    }

    @MainActor
    func cancelHostedSession() async -> Bool {
        guard isHost, let current = session.value else { return false }
        actionError = nil
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await repository.cancelSession(id: current.id)
            await load()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            return true
        } catch {
            actionError = AppErrorMapper.message(for: error)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return false
        }
    }

    /// Subscribes to `sessions` row updates for live `player_count` / `status` (Realtime publication).
    @MainActor
    func startSessionRealtime() async {
        await stopSessionRealtime()
        guard case .loaded = session else { return }

        let channel = client.channel("session-live-\(sessionId.uuidString)")
        realtimeChannel = channel

        let updates = channel.postgresChange(
            UpdateAction.self,
            schema: "public",
            table: "sessions",
            filter: .eq("id", value: sessionId)
        )

        do {
            try await channel.subscribeWithError()
        } catch {
            return
        }

        realtimeTask = Task { @MainActor in
            for await action in updates {
                guard !Task.isCancelled else { break }
                applySessionsTableUpdate(action)
            }
        }
    }

    @MainActor
    func stopSessionRealtime() async {
        realtimeTask?.cancel()
        realtimeTask = nil

        if let channel = realtimeChannel {
            await channel.unsubscribe()
            await client.removeChannel(channel)
            realtimeChannel = nil
        }
    }

    private func applySessionsTableUpdate(_ action: UpdateAction) {
        guard case let .loaded(current) = session else { return }
        var updated = current
        if let json = action.record["player_count"], let n = intFromAnyJSON(json) {
            updated.playerCount = n
        }
        if let raw = action.record["status"]?.stringValue,
           let next = SessionStatus(rawValue: raw) {
            updated.status = next
        }
        session = .loaded(updated)
    }

    private func intFromAnyJSON(_ json: AnyJSON) -> Int? {
        switch json {
        case let .integer(i): return i
        case let .double(d): return Int(d)
        default: return nil
        }
    }

    var primaryActionTitle: String {
        switch participantStatus {
        case .joined: return "Leave"
        case .waitlist: return "Leave waitlist"
        case .left, .none: return session.value?.isFull == true ? "Join waitlist" : "Join"
        }
    }

    var isLeaveAction: Bool {
        participantStatus == .joined || participantStatus == .waitlist
    }

    var canAccessChat: Bool {
        if isHost { return true }
        switch participantStatus {
        case .joined, .waitlist:
            return true
        case .left, .none:
            return false
        }
    }
}
