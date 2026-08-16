import SwiftUI

struct CreateFlowProgressBar: View {
    @Environment(\.colorScheme) private var colorScheme

    let currentStep: CreateSessionStep

    var body: some View {
        HStack(spacing: Spacing.s) {
            ForEach(CreateSessionStep.allCases) { step in
                Capsule()
                    .fill(fillColor(for: step))
                    .frame(height: 4)
                    .accessibilityLabel(step.accessibilityLabel(isCurrent: step == currentStep))
            }
        }
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.s)
    }

    private func fillColor(for step: CreateSessionStep) -> Color {
        if step.rawValue <= currentStep.rawValue {
            return AppColor.gold
        }
        return AppColor.textSecondary(colorScheme).opacity(0.25)
    }
}
