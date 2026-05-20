import SwiftUI

struct SessionCard: View {
    let session: PickupSession
    var isJoining: Bool = false
    /// When set, replaces the default "Join" / "Waitlist" label (e.g. **Leave** on My Games).
    var actionTitle: String?
    var isDestructiveAction: Bool = false
    var onJoin: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme
    @State private var isPressed = false

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.m) {
            sportIcon

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(session.sportDisplayName)
                    .font(AppFont.headline(.semibold))
                    .foregroundStyle(AppColor.textPrimary(colorScheme))
                Text(session.locationName)
                    .font(AppFont.body())
                    .foregroundStyle(AppColor.textSecondary(colorScheme))
                Text(SessionDateFormatter.cardLabel(for: session.startsAt))
                    .font(AppFont.caption())
                    .foregroundStyle(AppColor.textSecondary(colorScheme))
                HStack(spacing: Spacing.s) {
                    Text("\(session.playerCount)/\(session.capacity) joined")
                        .font(AppFont.caption(.semibold))
                        .foregroundStyle(AppColor.textPrimary(colorScheme))
                    SkillPill(skill: session.skillLevel)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let onJoin {
                Button(action: onJoin) {
                    Group {
                        if isJoining {
                            ProgressView()
                                .tint(isDestructiveAction ? .red : .black)
                        } else {
                            Text(buttonLabel)
                                .font(AppFont.caption(.semibold))
                        }
                    }
                    .frame(minWidth: 72, minHeight: 36)
                    .foregroundStyle(isDestructiveAction ? AppColor.destructive : .black)
                    .background(buttonBackground)
                    .overlay {
                        if session.isFull && actionTitle == nil {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(AppColor.gold, lineWidth: 1.5)
                        } else if isDestructiveAction {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(AppColor.destructive.opacity(0.6), lineWidth: 1.5)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isJoining)
                .accessibilityLabel(accessibilityActionLabel)
            }
        }
        .padding(Spacing.m)
        .background(AppColor.surface(colorScheme))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppColor.textSecondary(colorScheme).opacity(0.15), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .scaleEffect(isPressed ? 0.98 : 1)
        .animation(.spring(duration: 0.2), value: isPressed)
        .accessibilityElement(children: .combine)
        .accessibilityHint(onJoin == nil ? "" : "Opens session details; use the action button for quick join or leave")
    }

    private var buttonLabel: String {
        if let actionTitle { return actionTitle }
        return session.isFull ? "Waitlist" : "Join"
    }

    private var buttonBackground: Color {
        if isDestructiveAction { return AppColor.surface(colorScheme) }
        return session.isFull && actionTitle == nil ? AppColor.surface(colorScheme) : AppColor.gold
    }

    private var accessibilityActionLabel: String {
        if let actionTitle { return actionTitle }
        return session.isFull ? "Join waitlist" : "Join game"
    }

    private var sportIcon: some View {
        Image(systemName: session.sport.systemImage)
            .font(.title2)
            .foregroundStyle(AppColor.sportAccent(session.sport))
            .frame(width: 44, height: 44)
            .background(AppColor.sportAccent(session.sport).opacity(0.15))
            .clipShape(Circle())
    }
}
