import SwiftUI

struct ReportSheet: View {
    let sessionId: UUID

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var reason = ""
    @State private var isSubmitting = false
    @State private var submitError: String?
    @FocusState private var reasonFocused: Bool

    private let repository = ReportRepository()

    private var trimmedReason: String {
        reason.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmit: Bool {
        trimmedReason.count >= 10 && trimmedReason.count <= 500 && !isSubmitting
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.m) {
                    FormFieldHint(
                        text: "Tell us what happened. Reports are reviewed manually and are not shared with the host."
                    )

                    TextField(
                        "Describe the issue",
                        text: $reason,
                        axis: .vertical
                    )
                    .lineLimit(4...8)
                    .textFieldStyle(.roundedBorder)
                    .focused($reasonFocused)
                    .disabled(isSubmitting)

                    FormFieldHint(
                        text: "\(trimmedReason.count)/500 characters · minimum 10"
                    )

                    if let submitError {
                        ErrorBanner(message: submitError)
                    }
                }
                .padding(Spacing.m)
            }

            submitBar
        }
        .background(AppColor.background(colorScheme))
        .navigationTitle("Report session")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .dismissKeyboardOnBackgroundTap()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .disabled(isSubmitting)
            }
            FormKeyboardToolbar(onDone: { reasonFocused = false })
        }
    }

    private var submitBar: some View {
        VStack(spacing: Spacing.s) {
            PrimaryButton(
                title: "Submit report",
                isLoading: isSubmitting,
                isEnabled: canSubmit
            ) {
                Task { await submit() }
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

    @MainActor
    private func submit() async {
        submitError = nil
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await repository.submitReport(sessionId: sessionId, reason: reason)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            dismiss()
        } catch {
            submitError = AppErrorMapper.message(for: error)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}
