import SwiftUI

struct AttendanceSheet: View {
    @Bindable var viewModel: SessionDetailViewModel

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var attendedUserIds: Set<UUID> = []
    @State private var didSeedToggles = false
    @State private var submitError: String?

    var body: some View {
        VStack(spacing: 0) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if case .loaded = viewModel.attendanceParticipants {
                submitBar
            }
        }
        .background(AppColor.background(colorScheme))
        .navigationTitle("Mark attendance")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
        .task {
            await viewModel.loadAttendanceParticipants()
            seedTogglesIfNeeded()
        }
        .onChange(of: participantIdsKey) { _, _ in
            seedTogglesIfNeeded()
        }
    }

    private var participantIdsKey: String {
        viewModel.attendanceParticipants.value?
            .map(\.userId.uuidString)
            .sorted()
            .joined(separator: ",") ?? ""
    }

    private func seedTogglesIfNeeded() {
        guard !didSeedToggles, let items = viewModel.attendanceParticipants.value else { return }
        attendedUserIds = Set(items.map(\.userId))
        didSeedToggles = true
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.attendanceParticipants {
        case .idle, .loading:
            ProgressView("Loading players…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            VStack(spacing: Spacing.m) {
                ErrorBanner(message: message)
                PrimaryButton(title: "Try again") {
                    didSeedToggles = false
                    Task {
                        await viewModel.loadAttendanceParticipants()
                        seedTogglesIfNeeded()
                    }
                }
                .padding(.horizontal, Spacing.m)
            }
            .padding(Spacing.m)
        case .loaded(let participants):
            if participants.isEmpty {
                EmptyStateView(
                    symbol: "person.2.slash",
                    title: "No players to mark",
                    message: "Nobody has joined this session yet."
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.m) {
                        FormFieldHint(
                            text: "Turn off anyone who did not show up. Everyone is marked present by default."
                        )

                        if let submitError {
                            ErrorBanner(message: submitError)
                        }

                        VStack(spacing: 0) {
                            ForEach(participants) { participant in
                                attendanceRow(participant)
                                if participant.id != participants.last?.id {
                                    Divider()
                                }
                            }
                        }
                        .background(AppColor.surface(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .padding(Spacing.m)
                }
            }
        }
    }

    private func attendanceRow(_ participant: SessionParticipant) -> some View {
        Toggle(isOn: attendanceBinding(for: participant.userId)) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(participant.displayName)
                    .font(AppFont.headline(.semibold))
                    .foregroundStyle(AppColor.textPrimary(colorScheme))
                if participant.username != nil {
                    Text(participant.handle)
                        .font(AppFont.caption())
                        .foregroundStyle(AppColor.textSecondary(colorScheme))
                }
            }
        }
        .tint(AppColor.gold)
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.s)
    }

    private func attendanceBinding(for userId: UUID) -> Binding<Bool> {
        Binding(
            get: { attendedUserIds.contains(userId) },
            set: { isPresent in
                if isPresent {
                    attendedUserIds.insert(userId)
                } else {
                    attendedUserIds.remove(userId)
                }
            }
        )
    }

    private var submitBar: some View {
        VStack(spacing: Spacing.s) {
            PrimaryButton(
                title: "Submit attendance",
                isLoading: viewModel.isSubmitting,
                isEnabled: !viewModel.isSubmitting
            ) {
                Task {
                    submitError = nil
                    if await viewModel.submitAttendance(attendedUserIds: Array(attendedUserIds)) {
                        dismiss()
                    } else {
                        submitError = viewModel.actionError
                    }
                }
            }
        }
        .padding(Spacing.m)
        .frame(maxWidth: .infinity)
        .background(AppColor.background(colorScheme))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppColor.textSecondary(colorScheme).opacity(0.2))
                .frame(height: 1)
        }
    }
}
