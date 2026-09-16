import SwiftUI

@Observable
final class ModerationQueueViewModel {
    var reports = Loadable<[ModerationQueueItem]>.idle
    var actionError: String?
    var isSubmitting = false

    private let repository: ModerationRepositoryProtocol

    init(repository: ModerationRepositoryProtocol = ModerationRepository()) {
        self.repository = repository
    }

    @MainActor
    func load() async {
        reports = .loading
        do {
            reports = .loaded(try await repository.fetchQueue(limit: 50))
        } catch {
            reports = .failed(AppErrorMapper.message(for: error))
        }
    }

    @MainActor
    func act(
        on item: ModerationQueueItem,
        action: ModerationActionType,
        reason: String,
        suspensionHours: Int?
    ) async -> Bool {
        actionError = nil
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await repository.act(
                on: item.id,
                action: action,
                reason: reason,
                suspensionHours: suspensionHours
            )
            await load()
            return true
        } catch {
            actionError = AppErrorMapper.message(for: error)
            return false
        }
    }
}

struct ModerationQueueView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel = ModerationQueueViewModel()

    var body: some View {
        Group {
            switch viewModel.reports {
            case .idle, .loading:
                ProgressView("Loading reports…")
            case .failed(let message):
                VStack(spacing: Spacing.m) {
                    ErrorBanner(message: message)
                    PrimaryButton(title: "Try again") { Task { await viewModel.load() } }
                }
                .padding(Spacing.m)
            case .loaded(let reports):
                if reports.isEmpty {
                    EmptyStateView(
                        symbol: "checkmark.shield",
                        title: "Queue clear",
                        message: "There are no open reports."
                    )
                } else {
                    List(reports) { item in
                        NavigationLink {
                            ModerationReportView(item: item, viewModel: viewModel)
                        } label: {
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                Text(item.category.label)
                                    .font(AppFont.body(.semibold))
                                Text("\(item.targetType.rawValue.capitalized) · \(item.targetSummary)")
                                    .font(AppFont.caption())
                                    .foregroundStyle(AppColor.textSecondary(colorScheme))
                                    .lineLimit(2)
                            }
                            .padding(.vertical, Spacing.xs)
                        }
                    }
                    .listStyle(.plain)
                }
            }
        }
        .appScreenBackground()
        .navigationTitle("Moderation")
        .navigationBarTitleDisplayMode(.large)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }
}

private struct ModerationReportView: View {
    let item: ModerationQueueItem
    let viewModel: ModerationQueueViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var action: ModerationActionType = .resolve
    @State private var reason = ""
    @State private var suspensionHours = 24

    var body: some View {
        Form {
            Section("Report") {
                LabeledContent("Category", value: item.category.label)
                LabeledContent("Target", value: item.targetType.rawValue.capitalized)
                Text(item.targetSummary)
                if let context = item.context { Text(context) }
            }

            Section("Decision") {
                Picker("Action", selection: $action) {
                    ForEach(ModerationActionType.allCases) { action in
                        Text(action.label).tag(action)
                    }
                }
                if action == .suspendUser {
                    Stepper("Suspend for \(suspensionHours) hours", value: $suspensionHours, in: 1 ... 2_160)
                }
                TextField("Reason (minimum 10 characters)", text: $reason, axis: .vertical)
                    .lineLimit(3 ... 6)
            }

            if let error = viewModel.actionError {
                Section { ErrorBanner(message: error) }
            }

            Section {
                PrimaryButton(
                    title: "Record action",
                    isLoading: viewModel.isSubmitting,
                    isEnabled: reason.trimmingCharacters(in: .whitespacesAndNewlines).count >= 10
                ) {
                    Task {
                        if await viewModel.act(
                            on: item,
                            action: action,
                            reason: reason,
                            suspensionHours: suspensionHours
                        ) {
                            dismiss()
                        }
                    }
                }
            }
        }
        .navigationTitle("Review report")
        .navigationBarTitleDisplayMode(.inline)
    }
}
