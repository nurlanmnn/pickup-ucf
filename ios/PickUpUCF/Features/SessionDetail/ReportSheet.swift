import SwiftUI

struct ReportSheet: View {
    let target: ReportTarget

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var category: ReportCategory = .harassment
    @State private var context = ""
    @State private var isSubmitting = false
    @State private var submitError: String?
    @FocusState private var reasonFocused: Bool

    private let repository = ReportRepository()

    private var trimmedContext: String {
        context.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmit: Bool {
        (trimmedContext.isEmpty || trimmedContext.count >= 10)
            && trimmedContext.count <= 500
            && !isSubmitting
    }

    private var navigationTitle: String {
        switch target.type {
        case .session: "Report session"
        case .message: "Report message"
        case .user: "Report user"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.m) {
                    FormFieldHint(text: "Reports are private. Choose the closest reason and add only the context needed for review.")

                    Picker("Reason", selection: $category) {
                        ForEach(ReportCategory.allCases) { category in
                            Text(category.label).tag(category)
                        }
                    }
                    .pickerStyle(.menu)

                    TextField(
                        "Extra context (optional)",
                        text: $context,
                        axis: .vertical
                    )
                    .lineLimit(4...8)
                    .textFieldStyle(.roundedBorder)
                    .focused($reasonFocused)
                    .disabled(isSubmitting)

                    FormFieldHint(
                        text: "\(trimmedContext.count)/500 characters · if provided, minimum 10"
                    )

                    NavigationLink("Read the community rules") {
                        CommunityRulesView()
                    }
                    .font(AppFont.caption(.semibold))

                    if let submitError {
                        ErrorBanner(message: submitError)
                    }
                }
                .padding(Spacing.m)
            }

            submitBar
        }
        .background(AppColor.background(colorScheme))
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .dismissKeyboardOnBackgroundTap()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .disabled(isSubmitting)
            }
        }
        .formKeyboardAccessory(
            isPresented: reasonFocused,
            onDone: { reasonFocused = false }
        )
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
            try await repository.submitReport(
                target: target,
                category: category,
                context: context
            )
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            dismiss()
        } catch {
            submitError = AppErrorMapper.message(for: error)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}
